import type { Route } from '../types';
import { json, badRequest } from '../router';
import { withAuth } from '../middleware/auth';
import { withRole } from '../middleware/role';
import {
  getEntitlementView,
  syncSignedTransaction,
  EntitlementError,
} from '../services/entitlement-service';
import { countActiveByKitchen } from '../db/dishes';

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
          status: view.status,
          plan_code: view.planCode,
          dish_limit: view.isUnlimited ? null : view.dishLimit,
          is_unlimited: view.isUnlimited,
          active_dish_count: activeDishCount,
          store_product_id: view.storeProductId,
          activated_at: view.activatedAt,
          original_transaction_id: view.originalTransactionId,
          revoked_at: view.revokedAt,
          revocation_reason: view.revocationReason,
          last_verified_at: view.lastVerifiedAt,
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
          signed_transaction?: string;
          source?: 'app_store' | 'offer_code';
        }>();

        if (!body?.signed_transaction) {
          return badRequest('signed_transaction 必填');
        }

        try {
          const result = await syncSignedTransaction(env.DB, {
            kitchenId: ctx.kitchen!.id,
            accountId: ctx.account.id,
            signedTransaction: body.signed_transaction,
            source: body.source,
          });
          const activeDishCount = await countActiveByKitchen(env.DB, ctx.kitchen!.id);
          return json({
            status: result.view.status,
            plan_code: result.view.planCode,
            dish_limit: result.view.isUnlimited ? null : result.view.dishLimit,
            is_unlimited: result.view.isUnlimited,
            active_dish_count: activeDishCount,
            store_product_id: result.view.storeProductId,
            activated_at: result.view.activatedAt,
            original_transaction_id: result.view.originalTransactionId,
            revoked_at: result.view.revokedAt,
            revocation_reason: result.view.revocationReason,
            last_verified_at: result.view.lastVerifiedAt,
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
