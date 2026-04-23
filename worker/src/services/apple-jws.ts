import type { VerificationEnvironment } from '../types';

export interface VerifiedSignedTransaction {
  productId: string;
  originalTransactionId: string;
  appAccountToken: string | null;
  environment: VerificationEnvironment;
  revokedAt: string | null;
  revocationReason: string | null;
  signedTransaction: string;
}

interface CachedCertificate {
  fingerprint: string;
  der: Uint8Array;
  publicKey: CryptoKey;
  subject: string;
  issuer: string;
  notBefore: Date;
  notAfter: Date;
  isCA: boolean;
}

const certificateCache = new Map<string, CachedCertificate>();

interface JWSHeader {
  alg?: string;
  x5c?: string[];
}

interface SignedTransactionPayload {
  productId?: string;
  originalTransactionId?: string;
  appAccountToken?: string;
  environment?: string;
  revocationDate?: number;
  revocationReason?: number | string;
}

export class SignedTransactionVerificationError extends Error {
  constructor(message: string) {
    super(message);
  }
}

export async function verifySignedTransaction(
  signedTransaction: string
): Promise<VerifiedSignedTransaction> {
  const parts = signedTransaction.split('.');
  if (parts.length !== 3) {
    throw new SignedTransactionVerificationError('signedTransaction 格式错误');
  }

  const [protectedHeaderSegment, payloadSegment, signatureSegment] = parts;
  const header = parseJSON<JWSHeader>(protectedHeaderSegment);
  const payload = parseJSON<SignedTransactionPayload>(payloadSegment);
  if (header.alg !== 'ES256') {
    throw new SignedTransactionVerificationError('signedTransaction 算法错误');
  }

  const certificates = await loadCertificates(header.x5c ?? []);
  await verifyCertificateChain(certificates);

  const signingInput = new TextEncoder().encode(`${protectedHeaderSegment}.${payloadSegment}`);
  const signature = base64URLDecode(signatureSegment);
  const verified = await crypto.subtle.verify(
    { name: 'ECDSA', hash: 'SHA-256' },
    certificates[0].publicKey,
    toArrayBuffer(signature),
    toArrayBuffer(signingInput)
  );
  if (!verified) {
    throw new SignedTransactionVerificationError('signedTransaction 验签失败');
  }

  const productId = payload.productId?.trim();
  const originalTransactionId = payload.originalTransactionId?.trim();
  if (!productId || !originalTransactionId) {
    throw new SignedTransactionVerificationError('signedTransaction 缺少交易字段');
  }

  return {
    productId,
    originalTransactionId,
    appAccountToken: payload.appAccountToken?.trim() || null,
    environment: normalizeEnvironment(payload.environment),
    revokedAt: toISOString(payload.revocationDate),
    revocationReason: normalizeRevocationReason(payload.revocationReason),
    signedTransaction,
  };
}

async function loadCertificates(chain: string[]): Promise<CachedCertificate[]> {
  if (chain.length === 0) {
    throw new SignedTransactionVerificationError('signedTransaction 缺少证书链');
  }

  const certificates: CachedCertificate[] = [];
  for (const item of chain) {
    const der = base64StandardDecode(item);
    const fingerprint = await sha256Hex(der);
    const cached = certificateCache.get(fingerprint);
    if (cached) {
      certificates.push(cached);
      continue;
    }

    const parsed = await parseCertificate(der, fingerprint);
    certificateCache.set(fingerprint, parsed);
    certificates.push(parsed);
  }
  return certificates;
}

async function verifyCertificateChain(certificates: CachedCertificate[]): Promise<void> {
  const now = new Date();
  for (let index = 0; index < certificates.length; index += 1) {
    const current = certificates[index];
    if (now < current.notBefore || now > current.notAfter) {
      throw new SignedTransactionVerificationError('证书已过期或尚未生效');
    }

    if (index === 0 && current.isCA) {
      throw new SignedTransactionVerificationError('叶子证书 CA 约束错误');
    }

    const issuer = certificates[index + 1];
    if (!issuer) continue;

    if (!issuer.isCA) {
      throw new SignedTransactionVerificationError('中间证书 CA 约束错误');
    }
    if (current.issuer !== issuer.subject) {
      throw new SignedTransactionVerificationError('证书链 issuer/subject 不匹配');
    }

    const tbs = extractTBSCertificate(current.der);
    const signature = extractCertificateSignature(current.der);
    const chainVerified = await crypto.subtle.verify(
      { name: 'ECDSA', hash: 'SHA-256' },
      issuer.publicKey,
      toArrayBuffer(signature),
      toArrayBuffer(tbs)
    );
    if (!chainVerified) {
      throw new SignedTransactionVerificationError('证书链签名验证失败');
    }
  }
}

async function parseCertificate(
  der: Uint8Array,
  fingerprint: string
): Promise<CachedCertificate> {
  const certificate = readTLV(der, 0);
  const children = readSequenceChildren(der, certificate);
  const tbs = children[0];
  const tbsChildren = readSequenceChildren(der, tbs);
  const hasVersionField = tbsChildren[0]?.tag === 0xa0;

  const issuer = readName(der, tbsChildren[hasVersionField ? 3 : 2]);
  const validity = readSequenceChildren(der, tbsChildren[hasVersionField ? 4 : 3]);
  const subject = readName(der, tbsChildren[hasVersionField ? 5 : 4]);
  const subjectPublicKeyInfo = tbsChildren[hasVersionField ? 6 : 5];
  const extensionsNode = tbsChildren.find(node => node.tag === 0xa3);

  const publicKey = await crypto.subtle.importKey(
    'spki',
    der.slice(subjectPublicKeyInfo.start, subjectPublicKeyInfo.end).buffer,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['verify']
  );

  return {
    fingerprint,
    der,
    publicKey,
    issuer,
    subject,
    notBefore: readASN1Date(der, validity[0]),
    notAfter: readASN1Date(der, validity[1]),
    isCA: readBasicConstraintsCA(der, extensionsNode),
  };
}

function extractTBSCertificate(der: Uint8Array): Uint8Array {
  const certificate = readTLV(der, 0);
  const children = readSequenceChildren(der, certificate);
  const tbs = children[0];
  return der.slice(tbs.start, tbs.end);
}

function extractCertificateSignature(der: Uint8Array): Uint8Array {
  const certificate = readTLV(der, 0);
  const children = readSequenceChildren(der, certificate);
  const signatureBitString = children[2];
  const unusedBits = der[signatureBitString.valueStart];
  if (unusedBits !== 0) {
    throw new SignedTransactionVerificationError('证书签名格式错误');
  }
  return der.slice(signatureBitString.valueStart + 1, signatureBitString.end);
}

function parseJSON<T>(segment: string): T {
  try {
    const raw = new TextDecoder().decode(base64URLDecode(segment));
    return JSON.parse(raw) as T;
  } catch {
    throw new SignedTransactionVerificationError('signedTransaction 解析失败');
  }
}

function normalizeEnvironment(value?: string): VerificationEnvironment {
  return value === 'Sandbox' ? 'sandbox' : 'production';
}

function normalizeRevocationReason(value?: number | string): string | null {
  if (value === undefined || value === null) return null;
  return String(value);
}

function toISOString(value?: number): string | null {
  if (!value) return null;
  return new Date(value).toISOString();
}

function base64URLDecode(input: string): Uint8Array {
  const normalized = input.replace(/-/g, '+').replace(/_/g, '/');
  return base64StandardDecode(normalized);
}

function base64StandardDecode(input: string): Uint8Array {
  const padded = input.padEnd(Math.ceil(input.length / 4) * 4, '=');
  const binary = atob(padded);
  return Uint8Array.from(binary, char => char.charCodeAt(0));
}

async function sha256Hex(bytes: Uint8Array): Promise<string> {
  const hash = await crypto.subtle.digest('SHA-256', toArrayBuffer(bytes));
  return Array.from(new Uint8Array(hash))
    .map(value => value.toString(16).padStart(2, '0'))
    .join('');
}

function toArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  return bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) as ArrayBuffer;
}

interface TLV {
  tag: number;
  start: number;
  headerEnd: number;
  valueStart: number;
  end: number;
}

function readTLV(bytes: Uint8Array, start: number): TLV {
  const tag = bytes[start];
  const firstLength = bytes[start + 1];
  let headerEnd = start + 2;
  let length = 0;

  if ((firstLength & 0x80) === 0) {
    length = firstLength;
  } else {
    const count = firstLength & 0x7f;
    for (let index = 0; index < count; index += 1) {
      length = (length << 8) | bytes[headerEnd + index];
    }
    headerEnd += count;
  }

  return {
    tag,
    start,
    headerEnd,
    valueStart: headerEnd,
    end: headerEnd + length,
  };
}

function readSequenceChildren(bytes: Uint8Array, node: TLV): TLV[] {
  const children: TLV[] = [];
  let offset = node.valueStart;
  while (offset < node.end) {
    const child = readTLV(bytes, offset);
    children.push(child);
    offset = child.end;
  }
  return children;
}

function readName(bytes: Uint8Array, node: TLV | undefined): string {
  if (!node) throw new SignedTransactionVerificationError('证书名称字段缺失');
  return new TextDecoder().decode(bytes.slice(node.valueStart, node.end));
}

function readASN1Date(bytes: Uint8Array, node: TLV | undefined): Date {
  if (!node) throw new SignedTransactionVerificationError('证书日期字段缺失');
  const text = new TextDecoder().decode(bytes.slice(node.valueStart, node.end));
  if (node.tag === 0x17) {
    const year = Number(text.slice(0, 2));
    const fullYear = year >= 50 ? 1900 + year : 2000 + year;
    return new Date(Date.UTC(
      fullYear,
      Number(text.slice(2, 4)) - 1,
      Number(text.slice(4, 6)),
      Number(text.slice(6, 8)),
      Number(text.slice(8, 10)),
      Number(text.slice(10, 12))
    ));
  }
  if (node.tag === 0x18) {
    return new Date(Date.UTC(
      Number(text.slice(0, 4)),
      Number(text.slice(4, 6)) - 1,
      Number(text.slice(6, 8)),
      Number(text.slice(8, 10)),
      Number(text.slice(10, 12)),
      Number(text.slice(12, 14))
    ));
  }
  throw new SignedTransactionVerificationError('证书日期格式错误');
}

function readBasicConstraintsCA(bytes: Uint8Array, extensionsNode?: TLV): boolean {
  if (!extensionsNode) return false;
  const wrappedSequence = readTLV(bytes, extensionsNode.valueStart);
  const extensions = readSequenceChildren(bytes, wrappedSequence);
  for (const extension of extensions) {
    const fields = readSequenceChildren(bytes, extension);
    const oid = decodeOID(bytes.slice(fields[0].valueStart, fields[0].end));
    if (oid !== '2.5.29.19') continue;

    const octetString = fields[fields.length - 1];
    const inner = readTLV(bytes, octetString.valueStart);
    const constraints = readSequenceChildren(bytes, inner);
    if (constraints.length === 0) return false;
    const first = constraints[0];
    return first.tag === 0x01 && bytes[first.valueStart] !== 0x00;
  }
  return false;
}

function decodeOID(bytes: Uint8Array): string {
  if (bytes.length === 0) return '';
  const values = [Math.floor(bytes[0] / 40), bytes[0] % 40];
  let current = 0;
  for (let index = 1; index < bytes.length; index += 1) {
    current = (current << 7) | (bytes[index] & 0x7f);
    if ((bytes[index] & 0x80) === 0) {
      values.push(current);
      current = 0;
    }
  }
  return values.join('.');
}
