import type { Route } from '../types';
import { json, badRequest, forbidden } from '../router';
import { withAuth } from '../middleware/auth';
import { withRole } from '../middleware/role';
import { listByKitchen, removeMember, findByKitchenAndAccount, updateRole } from '../db/members';

export const memberRoutes: Route[] = [
  // GET /kitchens/:id/members
  {
    method: 'GET',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)\/members$/,
    handler: withAuth(
      withRole(['owner', 'admin', 'member'])(async (_req, env, ctx) => {
        const members = await listByKitchen(env.DB, ctx.kitchen!.id);
        return json(members);
      })
    ),
  },

  // DELETE /kitchens/:id/members/:account_id — 踢人
  {
    method: 'DELETE',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)\/members\/(?<account_id>[^/]+)$/,
    handler: withAuth(
      withRole(['owner', 'admin'])(async (_req, env, ctx, params) => {
        const targetId = params.account_id;
        const target = await findByKitchenAndAccount(env.DB, ctx.kitchen!.id, targetId);
        if (!target) return json({ message: '成员不存在' }, { status: 404 });

        // owner 可踢任何人；admin 只能踢 member
        if (ctx.member!.role === 'admin' && target.role !== 'member') {
          return forbidden('admin 只能踢出 member');
        }
        // 不能踢自己（owner 不能退出，用 leave 接口）
        if (target.account_id === ctx.account.id) {
          return badRequest('不能踢出自己');
        }

        await removeMember(env.DB, ctx.kitchen!.id, targetId);
        return json({ ok: true });
      })
    ),
  },

  // PATCH /kitchens/:id/members/:account_id — 变更角色
  {
    method: 'PATCH',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)\/members\/(?<account_id>[^/]+)$/,
    handler: withAuth(
      withRole(['owner'])(async (req, env, ctx, params) => {
        const targetId = params.account_id;
        const body = await req.json<{ role?: 'admin' | 'member' }>().catch(() => null);
        const nextRole = body?.role;

        if (nextRole !== 'admin' && nextRole !== 'member') {
          return badRequest('role 仅支持 admin 或 member');
        }

        const target = await findByKitchenAndAccount(env.DB, ctx.kitchen!.id, targetId);
        if (!target) return json({ message: '成员不存在' }, { status: 404 });
        if (target.account_id === ctx.account.id) return badRequest('不能修改自己的角色');
        if (target.role === 'owner') return badRequest('不能修改 owner 的角色');
        if (target.role === nextRole) return json(target);

        await updateRole(env.DB, ctx.kitchen!.id, targetId, nextRole);
        const updated = await findByKitchenAndAccount(env.DB, ctx.kitchen!.id, targetId);
        return json(updated);
      })
    ),
  },

  // POST /kitchens/:id/leave — 主动退出
  {
    method: 'POST',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)\/leave$/,
    handler: withAuth(
      withRole(['admin', 'member'])(async (_req, env, ctx) => {
        await removeMember(env.DB, ctx.kitchen!.id, ctx.account.id);
        return json({ ok: true });
      })
    ),
  },
];
