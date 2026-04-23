import type { EntitlementRow, EntitlementStatus, PlanCode } from '../types';
import {
  findActiveByKitchen,
  findByTxnId,
  findLatestByKitchen,
  insertEntitlement,
  replaceActiveEntitlement,
  setEntitlementRevoked,
  updateEntitlementMetadata,
} from '../db/entitlements';
import {
  SignedTransactionVerificationError,
  verifySignedTransaction,
  type VerifiedSignedTransaction,
} from './apple-jws';

export const FREE_DISH_LIMIT = 10;
export const UNLIMITED_DISH_SENTINEL = 1_000_000;

const PRODUCT_PLAN: Record<string, { plan: PlanCode; limit: number | null }> = {
  'kitchen.dishes.fifty': { plan: 'dishes_fifty', limit: 50 },
  'kitchen.dishes.unlimited': { plan: 'dishes_unlimited', limit: null },
};

const PLAN_RANK: Record<PlanCode, number> = {
  free: 0,
  dishes_fifty: 1,
  dishes_unlimited: 2,
};

export interface EntitlementView {
  status: EntitlementStatus;
  planCode: PlanCode;
  dishLimit: number;
  isUnlimited: boolean;
  storeProductId: string | null;
  originalTransactionId: string | null;
  activatedAt: string | null;
  revokedAt: string | null;
  revocationReason: string | null;
  lastVerifiedAt: string | null;
}

export function defaultView(status: EntitlementStatus = 'not_found'): EntitlementView {
  return {
    status,
    planCode: 'free',
    dishLimit: FREE_DISH_LIMIT,
    isUnlimited: false,
    storeProductId: null,
    originalTransactionId: null,
    activatedAt: null,
    revokedAt: null,
    revocationReason: null,
    lastVerifiedAt: null,
  };
}

export async function getEntitlementView(
  db: D1Database,
  kitchenId: string
): Promise<EntitlementView> {
  const active = await findActiveByKitchen(db, kitchenId);
  if (active) return toView(active, 'active');

  const latest = await findLatestByKitchen(db, kitchenId);
  if (latest?.revoked_at) {
    return toView(latest, 'revoked');
  }

  return defaultView('not_found');
}

function toView(row: EntitlementRow, status: EntitlementStatus): EntitlementView {
  const isUnlimited = row.dish_limit === null && row.plan_code !== 'free';
  return {
    status,
    planCode: row.plan_code,
    dishLimit: isUnlimited ? UNLIMITED_DISH_SENTINEL : row.dish_limit ?? FREE_DISH_LIMIT,
    isUnlimited,
    storeProductId: row.store_product_id,
    originalTransactionId: row.original_transaction_id,
    activatedAt: row.activated_at,
    revokedAt: row.revoked_at,
    revocationReason: row.revocation_reason,
    lastVerifiedAt: row.last_verified_at,
  };
}

export class EntitlementError extends Error {
  constructor(public code: string, message: string) {
    super(message);
  }
}

export interface SyncInput {
  kitchenId: string;
  accountId: string;
  signedTransaction: string;
  source?: 'app_store' | 'offer_code';
}

export interface SyncResult {
  view: EntitlementView;
}

export async function syncSignedTransaction(
  db: D1Database,
  input: SyncInput
): Promise<SyncResult> {
  const current = await getEntitlementView(db, input.kitchenId);

  try {
    const verified = await verifySignedTransaction(input.signedTransaction);
    const expectedToken = await buildAppAccountToken(input.accountId, input.kitchenId);
    if (verified.appAccountToken !== expectedToken) {
      throw new EntitlementError('app_account_token_mismatch', '交易账户绑定不匹配');
    }

    const view = await persistVerifiedTransaction(db, input, verified);
    return { view };
  } catch (error) {
    if (error instanceof EntitlementError) {
      throw error;
    }
    if (error instanceof SignedTransactionVerificationError) {
      return {
        view: {
          ...current,
          status: 'pending_verification_failed',
        },
      };
    }
    throw error;
  }
}

async function persistVerifiedTransaction(
  db: D1Database,
  input: SyncInput,
  verified: VerifiedSignedTransaction
): Promise<EntitlementView> {
  const plan = PRODUCT_PLAN[verified.productId];
  if (!plan) throw new EntitlementError('unknown_product', '未知的商品 ID');

  const existing = await findByTxnId(db, verified.originalTransactionId);
  if (existing && existing.kitchen_id !== input.kitchenId) {
    throw new EntitlementError('txn_bound_elsewhere', '该交易已被其他厨房绑定');
  }

  if (existing) {
    if (
      existing.app_account_token_hash &&
      existing.app_account_token_hash !== (await hashToken(verified.appAccountToken ?? ''))
    ) {
      throw new EntitlementError('app_account_token_mismatch', '交易账户绑定不匹配');
    }

    await updateEntitlementMetadata(db, existing.id, verified.signedTransaction);
    if (verified.revokedAt) {
      await setEntitlementRevoked(
        db,
        existing.id,
        verified.revokedAt,
        verified.revocationReason,
        verified.signedTransaction
      );
      const revoked = await findByTxnId(db, verified.originalTransactionId);
      return toView(revoked as EntitlementRow, 'revoked');
    }

    const fresh = await findByTxnId(db, verified.originalTransactionId);
    return toView(
      fresh as EntitlementRow,
      fresh?.revoked_at ? 'revoked' : 'active'
    );
  }

  const currentActive = await findActiveByKitchen(db, input.kitchenId);
  if (currentActive && PLAN_RANK[currentActive.plan_code] >= PLAN_RANK[plan.plan]) {
    return toView(currentActive, 'active');
  }

  const id = crypto.randomUUID();
  const appAccountTokenHash = await hashToken(verified.appAccountToken ?? '');
  if (currentActive) {
    await replaceActiveEntitlement(db, {
      newId: id,
      kitchenId: input.kitchenId,
      planCode: plan.plan,
      dishLimit: plan.limit,
      storeProductId: verified.productId,
      originalTransactionId: verified.originalTransactionId,
      appAccountTokenHash,
      source: input.source ?? 'app_store',
      verificationEnvironment: verified.environment,
      signedTransaction: verified.signedTransaction,
      revokedAt: verified.revokedAt,
      revocationReason: verified.revocationReason,
      previousActiveId: currentActive.id,
    });
    const inserted = await findByTxnId(db, verified.originalTransactionId);
    return toView(inserted as EntitlementRow, verified.revokedAt ? 'revoked' : 'active');
  }

  const row = await insertEntitlement(
    db,
    id,
    input.kitchenId,
    plan.plan,
    plan.limit,
    verified.productId,
    verified.originalTransactionId,
    appAccountTokenHash,
    input.source ?? 'app_store',
    verified.environment,
    verified.signedTransaction,
    verified.revokedAt,
    verified.revocationReason
  );

  return toView(row, verified.revokedAt ? 'revoked' : 'active');
}

export async function buildAppAccountToken(accountId: string, kitchenId: string): Promise<string> {
  const seed = new TextEncoder().encode(`kitchen-iap:${accountId}:${kitchenId}`);
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', seed));
  const bytes = Array.from(digest.slice(0, 16));
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.map(value => value.toString(16).padStart(2, '0')).join('');
  return [
    hex.slice(0, 8),
    hex.slice(8, 12),
    hex.slice(12, 16),
    hex.slice(16, 20),
    hex.slice(20, 32),
  ].join('-');
}

async function hashToken(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest))
    .map(byte => byte.toString(16).padStart(2, '0'))
    .join('');
}
