import type { EntitlementRow, PlanCode } from '../types';
import {
  findActiveByKitchen,
  findActiveByTxnId,
  insertEntitlement,
} from '../db/entitlements';

// 未购买默认免费档：10 道菜
export const FREE_DISH_LIMIT = 10;
// 业务层对“无限”的统一表示：一个足够大的数，简化 SQL 条件判断
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
  planCode: PlanCode;
  dishLimit: number;          // 业务层永远拿到一个数值，无限档用 UNLIMITED_DISH_SENTINEL
  isUnlimited: boolean;
  storeProductId: string | null;
  originalTransactionId: string | null;
  activatedAt: string | null;
}

export function defaultView(): EntitlementView {
  return {
    planCode: 'free',
    dishLimit: FREE_DISH_LIMIT,
    isUnlimited: false,
    storeProductId: null,
    originalTransactionId: null,
    activatedAt: null,
  };
}

export async function getEntitlementView(
  db: D1Database,
  kitchenId: string
): Promise<EntitlementView> {
  const row = await findActiveByKitchen(db, kitchenId);
  if (!row) return defaultView();
  return toView(row);
}

function toView(row: EntitlementRow): EntitlementView {
  const isUnlimited = row.dish_limit === null && row.plan_code !== 'free';
  return {
    planCode: row.plan_code,
    dishLimit: isUnlimited
      ? UNLIMITED_DISH_SENTINEL
      : row.dish_limit ?? FREE_DISH_LIMIT,
    isUnlimited,
    storeProductId: row.store_product_id,
    originalTransactionId: row.original_transaction_id,
    activatedAt: row.activated_at,
  };
}

export class EntitlementError extends Error {
  constructor(public code: string, message: string) {
    super(message);
  }
}

export interface SyncInput {
  kitchenId: string;
  productId: string;
  originalTransactionId: string;
  appAccountTokenHash?: string | null;
  source?: 'app_store' | 'offer_code';
}

/**
 * 绑定一笔 Apple 交易到 kitchen。
 *
 * 注意：当前未做 Apple signedTransaction JWS 本地校验，服务端信任调用方传入
 * 的 transaction 数据。TODO(iap): 接入 App Store Server API /verifyReceipt
 * 等价方案（App Store Server Notifications v2 + inAppPurchaseKey JWT 验签），
 * 并把 signedTransaction 原文作为证据归档。
 */
export async function bindTransaction(
  db: D1Database,
  input: SyncInput
): Promise<EntitlementView> {
  const plan = PRODUCT_PLAN[input.productId];
  if (!plan) throw new EntitlementError('unknown_product', '未知的商品 ID');

  // 同一交易只能绑定单一 kitchen
  const existing = await findActiveByTxnId(db, input.originalTransactionId);
  if (existing && existing.kitchen_id !== input.kitchenId) {
    throw new EntitlementError(
      'txn_bound_elsewhere',
      '该交易已被其他厨房绑定'
    );
  }
  if (existing && existing.kitchen_id === input.kitchenId) {
    return toView(existing);
  }

  // 对比现有活跃 entitlement 档位，不降级
  const current = await findActiveByKitchen(db, input.kitchenId);
  if (current && PLAN_RANK[current.plan_code] >= PLAN_RANK[plan.plan]) {
    return toView(current);
  }

  const id = crypto.randomUUID();
  const row = await insertEntitlement(
    db,
    id,
    input.kitchenId,
    plan.plan,
    plan.limit,
    input.productId,
    input.originalTransactionId,
    input.appAccountTokenHash ?? null,
    input.source ?? 'app_store'
  );

  // 若存在旧档（比如从 50 升到 unlimited），撤销旧行避免歧义
  if (current) {
    await db
      .prepare(
        "UPDATE kitchen_entitlements SET revoked_at = datetime('now'), updated_at = datetime('now') WHERE id = ? AND revoked_at IS NULL"
      )
      .bind(current.id)
      .run();
  }

  return toView(row);
}
