import type { Route } from '../types';
import { json, badRequest } from '../router';
import { withAuth } from '../middleware/auth';
import { withRole } from '../middleware/role';
import {
  getEntitlementView,
  bindTransaction,
  EntitlementError,
} from '../services/entitlement-service';
import { countActiveByKitchen } from '../db/dishes';

async function hashToken(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

export const iapRoutes: Route[] = [
  // GET /kitchens/:id/entitlement — 当前厨房权益 + 使用量
  {
    method: 'GET',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)\/entitlement$/,
    handler: withAuth(
      withRole(['owner', 'admin', 'member'])(async (_req, env, ctx) => {
        const view = await getEntitlementView(env.DB, ctx.kitchen!.id);
        const activeDishCount = await countActiveByKitchen(env.DB, ctx.kitchen!.id);
        return json({
          plan_code: view.planCode,
          dish_limit: view.isUnlimited ? null : view.dishLimit,
          is_unlimited: view.isUnlimited,
          active_dish_count: activeDishCount,
          store_product_id: view.storeProductId,
          activated_at: view.activatedAt,
        });
      })
    ),
  },

  // POST /kitchens/:id/iap/sync — 客户端上报 StoreKit 交易
  // 仅 owner/admin 可绑定付费权益
  {
    method: 'POST',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)\/iap\/sync$/,
    handler: withAuth(
      withRole(['owner', 'admin'])(async (req, env, ctx) => {
        const body = await req.json<{
          product_id?: string;
          original_transaction_id?: string;
          app_account_token?: string;
          source?: 'app_store' | 'offer_code';
        }>();

        if (!body?.product_id || !body?.original_transaction_id) {
          return badRequest('product_id 和 original_transaction_id 必填');
        }

        const appAccountTokenHash = body.app_account_token
          ? await hashToken(body.app_account_token)
          : null;

        try {
          const view = await bindTransaction(env.DB, {
            kitchenId: ctx.kitchen!.id,
            productId: body.product_id,
            originalTransactionId: body.original_transaction_id,
            appAccountTokenHash,
            source: body.source,
          });
          return json({
            plan_code: view.planCode,
            dish_limit: view.isUnlimited ? null : view.dishLimit,
            is_unlimited: view.isUnlimited,
            store_product_id: view.storeProductId,
            activated_at: view.activatedAt,
          });
        } catch (err) {
          if (err instanceof EntitlementError) {
            return json({ code: err.code, message: err.message }, { status: 409 });
          }
          throw err;
        }
      })
    ),
  },
];
