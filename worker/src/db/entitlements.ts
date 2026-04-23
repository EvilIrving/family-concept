import type { EntitlementRow, PlanCode } from '../types';

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

export async function findActiveByTxnId(
  db: D1Database,
  originalTransactionId: string
): Promise<EntitlementRow | null> {
  return db
    .prepare(
      'SELECT * FROM kitchen_entitlements WHERE original_transaction_id = ? AND revoked_at IS NULL LIMIT 1'
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
  source: 'app_store' | 'offer_code' | 'admin'
): Promise<EntitlementRow> {
  await db
    .prepare(
      `INSERT INTO kitchen_entitlements
         (id, kitchen_id, plan_code, dish_limit, store_product_id, original_transaction_id, app_account_token_hash, source)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    )
    .bind(
      id,
      kitchenId,
      planCode,
      dishLimit,
      storeProductId,
      originalTransactionId,
      appAccountTokenHash,
      source
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
      "UPDATE kitchen_entitlements SET revoked_at = datetime('now'), updated_at = datetime('now') WHERE id = ? AND revoked_at IS NULL"
    )
    .bind(id)
    .run();
}
