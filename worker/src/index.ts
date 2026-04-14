import type { Env, Route } from './types';
import { matchRoute, json, notFound } from './router';
import { deviceRoutes } from './routes/devices';
import { kitchenRoutes } from './routes/kitchens';
import { memberRoutes } from './routes/members';
import { onboardingRoutes } from './routes/onboarding';
import { dishRoutes } from './routes/dishes';
import { orderRoutes } from './routes/orders';
import { authRoutes } from './routes/auth';
import { withDevice } from './middleware/auth';
import { findByKitchenAndDevice } from './db/members';

export { KitchenLive } from './durable-objects/kitchen-live';

const routes: Route[] = [
  ...authRoutes,
  ...deviceRoutes,
  ...kitchenRoutes,
  ...memberRoutes,
  ...onboardingRoutes,
  ...dishRoutes,
  ...orderRoutes,
  {
    method: 'GET',
    pattern: /^\/api\/v1\/health$/,
    handler: async (_req, env) => {
      const assetList = await env.ASSETS.list({ limit: 1 });
      return json({
        ok: true,
        env: env.APP_ENV,
        timestamp: new Date().toISOString(),
        r2Reachable: true,
        assetSampleCount: assetList.objects.length,
      });
    },
  },
  {
    method: 'GET',
    pattern: /^\/api\/v1\/bootstrap$/,
    handler: async (_req, env) => {
      const result = await env.DB.prepare("select 'ok' as status").first<{ status: string }>();
      return json({
        apiVersion: 'v1',
        database: result?.status ?? 'unknown',
        storage: 'ready',
      });
    },
  },
  // WS /kitchens/:id/live — Durable Object 实时推送
  {
    method: 'GET',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)\/live$/,
    handler: withDevice(async (req, env, ctx, params) => {
      const member = await findByKitchenAndDevice(env.DB, params.id, ctx.device.id);
      if (!member) return json({ message: '你不是该 kitchen 的成员' }, { status: 403 });

      const doId = env.KITCHEN_LIVE.idFromName(params.id);
      const stub = env.KITCHEN_LIVE.get(doId);
      return stub.fetch(req);
    }),
  },
];

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const matched = matchRoute(routes, request.method, url.pathname);
    if (!matched) return notFound();
    return matched.handler(request, env, matched.params);
  },
};
