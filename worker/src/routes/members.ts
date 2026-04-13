import type { Route } from '../types';
import { json, badRequest, forbidden } from '../router';
import { withDevice } from '../middleware/auth';
import { withRole } from '../middleware/role';
import { listByKitchen, removeMember, findByKitchenAndDevice } from '../db/members';

export const memberRoutes: Route[] = [
  // GET /kitchens/:id/members
  {
    method: 'GET',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)\/members$/,
    handler: withDevice(
      withRole(['owner', 'admin', 'member'])(async (_req, env, ctx) => {
        const members = await listByKitchen(env.DB, ctx.kitchen!.id);
        return json(members);
      })
    ),
  },

  // DELETE /kitchens/:id/members/:device_ref_id — 踢人
  {
    method: 'DELETE',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)\/members\/(?<device_ref_id>[^/]+)$/,
    handler: withDevice(
      withRole(['owner', 'admin'])(async (_req, env, ctx, params) => {
        const targetId = params.device_ref_id;
        const target = await findByKitchenAndDevice(env.DB, ctx.kitchen!.id, targetId);
        if (!target) return json({ message: '成员不存在' }, { status: 404 });

        // owner 可踢任何人；admin 只能踢 member
        if (ctx.member!.role === 'admin' && target.role !== 'member') {
          return forbidden('admin 只能踢出 member');
        }
        // 不能踢自己（owner 不能退出，用 leave 接口）
        if (target.device_ref_id === ctx.device.id) {
          return badRequest('不能踢出自己');
        }

        await removeMember(env.DB, ctx.kitchen!.id, targetId);
        return json({ ok: true });
      })
    ),
  },

  // POST /kitchens/:id/leave — 主动退出
  {
    method: 'POST',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)\/leave$/,
    handler: withDevice(
      withRole(['admin', 'member'])(async (_req, env, ctx) => {
        await removeMember(env.DB, ctx.kitchen!.id, ctx.device.id);
        return json({ ok: true });
      })
    ),
  },
];
