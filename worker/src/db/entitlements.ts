import type { EntitlementRow, PlanCode, VerificationEnvironment } from '../types';

export async function findActiveByKitchen(
  db: D1Database,
  kitchenId: string
): Promise<EntitlementRow | null> {
  return db
    .prepare(
        'SELECT * FROM kitchen_entitlements WHERE kitchen_id = ? AND revoked_at IS NULL ORDER BY activated_at DESC LIMIT 1'
    )
    .bind(kitchenId)
    .first<EntitlementRow>();
}

export async function findLatestByKitchen(
  db: D1Database,
  kitchenId: string
): Promise<EntitlementRow | null> {
  return db
    .prepare(
      'SELECT * FROM kitchen_entitlements WHERE kitchen_id = ? ORDER BY updated_at DESC, activated_at DESC LIMIT 1'
    )
    .bind(kitchenId)
    .first<EntitlementRow>();
}

export async function findByTxnId(
  db: D1Database,
  originalTransactionId: string
): Promise<EntitlementRow | null> {
  return db
    .prepare(
      'SELECT * FROM kitchen_entitlements WHERE original_transaction_id = ? LIMIT 1'
    )
    .bind(originalTransactionId)
    .first<EntitlementRow>();
}

export async function insertEntitlement(
  db: D1Database,
  id: string,
  kitchenId: string,
  planCode: PlanCode,
  dishLimit: number | null,
  storeProductId: string | null,
  originalTransactionId: string | null,
  appAccountTokenHash: string | null,
  source: 'app_store' | 'offer_code' | 'admin',
  verificationEnvironment: VerificationEnvironment | null,
  signedTransaction: string | null,
  revokedAt: string | null,
  revocationReason: string | null
): Promise<EntitlementRow> {
  await db
    .prepare(
      `INSERT INTO kitchen_entitlements
         (
           id, kitchen_id, plan_code, dish_limit, store_product_id, original_transaction_id,
           app_account_token_hash, source, verification_environment, activated_at, revoked_at,
           revocation_reason, last_verified_at, last_seen_at, signed_transaction
         )
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), ?, ?, datetime('now'), datetime('now'), ?)`
    )
    .bind(
      id,
      kitchenId,
      planCode,
      dishLimit,
      storeProductId,
      originalTransactionId,
      appAccountTokenHash,
      source,
      verificationEnvironment,
      revokedAt,
      revocationReason,
      signedTransaction
    )
    .run();
  return (await db
    .prepare('SELECT * FROM kitchen_entitlements WHERE id = ?')
    .bind(id)
    .first<EntitlementRow>()) as EntitlementRow;
}

export async function revokeEntitlement(
  db: D1Database,
  id: string,
  reason?: string
): Promise<void> {
  await db
    .prepare(
      "UPDATE kitchen_entitlements SET revoked_at = datetime('now'), revocation_reason = COALESCE(?, revocation_reason), updated_at = datetime('now'), status_version = status_version + 1 WHERE id = ? AND revoked_at IS NULL"
    )
    .bind(reason ?? null, id)
    .run();
}

export async function touchEntitlementTransaction(
  db: D1Database,
  id: string
): Promise<void> {
  await db
    .prepare(
      "UPDATE kitchen_entitlements SET last_seen_at = datetime('now'), updated_at = datetime('now'), status_version = status_version + 1 WHERE id = ?"
    )
    .bind(id)
    .run();
}

export async function setEntitlementRevoked(
  db: D1Database,
  id: string,
  revokedAt: string,
  revocationReason: string | null,
  signedTransaction: string | null
): Promise<void> {
  await db
    .prepare(
      `UPDATE kitchen_entitlements
       SET revoked_at = ?, revocation_reason = ?, last_seen_at = datetime('now'),
           updated_at = datetime('now'), status_version = status_version + 1,
           signed_transaction = COALESCE(?, signed_transaction)
       WHERE id = ?`
    )
    .bind(revokedAt, revocationReason, signedTransaction, id)
    .run();
}

export async function updateEntitlementMetadata(
  db: D1Database,
  id: string,
  signedTransaction: string | null
): Promise<void> {
  await db
    .prepare(
      `UPDATE kitchen_entitlements
       SET last_seen_at = datetime('now'),
           updated_at = datetime('now'),
           status_version = status_version + 1,
           signed_transaction = COALESCE(?, signed_transaction)
       WHERE id = ?`
    )
    .bind(signedTransaction, id)
    .run();
}

export async function replaceActiveEntitlement(
  db: D1Database,
  params: {
    newId: string;
    kitchenId: string;
    planCode: PlanCode;
    dishLimit: number | null;
    storeProductId: string;
    originalTransactionId: string;
    appAccountTokenHash: string;
    source: 'app_store' | 'offer_code' | 'admin';
    verificationEnvironment: VerificationEnvironment;
    signedTransaction: string;
    revokedAt: string | null;
    revocationReason: string | null;
    previousActiveId?: string | null;
  }
): Promise<void> {
  const statements = [
    db.prepare('BEGIN IMMEDIATE'),
    db.prepare(
      `INSERT INTO kitchen_entitlements
         (
           id, kitchen_id, plan_code, dish_limit, store_product_id, original_transaction_id,
           app_account_token_hash, source, verification_environment, activated_at, revoked_at,
           revocation_reason, last_verified_at, last_seen_at, signed_transaction
         )
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), ?, ?, datetime('now'), datetime('now'), ?)`
    ).bind(
      params.newId,
      params.kitchenId,
      params.planCode,
      params.dishLimit,
      params.storeProductId,
      params.originalTransactionId,
      params.appAccountTokenHash,
      params.source,
      params.verificationEnvironment,
      params.revokedAt,
      params.revocationReason,
      params.signedTransaction
    ),
  ];

  if (params.previousActiveId) {
    statements.push(
      db.prepare(
        "UPDATE kitchen_entitlements SET revoked_at = datetime('now'), revocation_reason = ?, updated_at = datetime('now'), status_version = status_version + 1 WHERE id = ? AND revoked_at IS NULL"
      ).bind('superseded_by_higher_tier', params.previousActiveId)
    );
  }

  statements.push(db.prepare('COMMIT'));

  try {
    await db.batch(statements);
  } catch (error) {
    await db.batch([db.prepare('ROLLBACK')]).catch(() => undefined);
    throw error;
  }
}
