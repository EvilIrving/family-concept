import type { Route } from '../types';
import { json, badRequest, forbidden } from '../router';
import { withAuth } from '../middleware/auth';
import { withRole } from '../middleware/role';
import { findById, updateName, rotateInviteCode } from '../db/kitchens';
import { createKitchen, joinByInviteCode } from '../services/kitchen-service';

export const kitchenRoutes: Route[] = [
  // POST /kitchens — 创建 kitchen（成为 owner）
  {
    method: 'POST',
    pattern: /^\/api\/v1\/kitchens$/,
    handler: withAuth(async (req, env, ctx) => {
      const body = await req.json<{ name?: string }>();
      if (!body?.name) return badRequest('name 为必填项');

      const { kitchen } = await createKitchen(env.DB, ctx.account.id, body.name);
      return json(kitchen, { status: 201 });
    }),
  },

  // GET /kitchens/:id
  {
    method: 'GET',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)$/,
    handler: withAuth(
      withRole(['owner', 'admin', 'member'])(async (_req, _env, ctx) => {
        return json(ctx.kitchen);
      })
    ),
  },

  // PATCH /kitchens/:id — 改名（owner 限定）
  {
    method: 'PATCH',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)$/,
    handler: withAuth(
      withRole(['owner'])(async (req, env, ctx) => {
        const body = await req.json<{ name?: string }>();
        if (!body?.name) return badRequest('name 为必填项');
        await updateName(env.DB, ctx.kitchen!.id, body.name);
        const updated = await findById(env.DB, ctx.kitchen!.id);
        return json(updated);
      })
    ),
  },

  // POST /kitchens/:id/rotate_invite — 刷新邀请码（owner/admin）
  {
    method: 'POST',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)\/rotate_invite$/,
    handler: withAuth(
      withRole(['owner', 'admin'])(async (_req, env, ctx) => {
        const newCode = crypto.randomUUID().replace(/-/g, '').slice(0, 6).toUpperCase();
        await rotateInviteCode(env.DB, ctx.kitchen!.id, newCode);
        return json({ invite_code: newCode });
      })
    ),
  },

  // POST /kitchens/join — 加入 kitchen
  {
    method: 'POST',
    pattern: /^\/api\/v1\/kitchens\/join$/,
    handler: withAuth(async (req, env, ctx) => {
      const body = await req.json<{ invite_code?: string }>();
      if (!body?.invite_code) return badRequest('invite_code 为必填项');

      try {
        const { kitchen, member } = await joinByInviteCode(env.DB, ctx.account.id, body.invite_code);
        return json({ kitchen, member }, { status: 201 });
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : '加入失败';
        return badRequest(msg);
      }
    }),
  },
];
