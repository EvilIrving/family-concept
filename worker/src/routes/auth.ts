import type { Route } from '../types';
import { conflict, json, badRequest, unauthorized } from '../router';
import { hashPassword, verifyPassword, generateSessionToken, hashSessionToken, sessionExpiresAt } from '../auth';
import { findByUserName, insertAccount } from '../db/accounts';
import { insertSession, deleteByTokenHash } from '../db/sessions';
import { findActiveKitchenByAccount } from '../db/members';
import { withAuth } from '../middleware/auth';

function sanitizeAccount(account: { id: string; user_name: string; nick_name: string; created_at: string }) {
  return {
    id: account.id,
    user_name: account.user_name,
    nick_name: account.nick_name,
    created_at: account.created_at,
  };
}

export const authRoutes: Route[] = [
  {
    method: 'POST',
    pattern: /^\/api\/v1\/auth\/register$/,
    handler: async (req, env) => {
      const body = await req.json<{ user_name?: string; password?: string; nick_name?: string }>();
      const userName = body?.user_name?.trim();
      const password = body?.password;
      const nickName = body?.nick_name?.trim();

      if (!userName || !password || !nickName) {
        return badRequest('user_name、password、nick_name 为必填项');
      }
      if (password.length < 8) return badRequest('password 至少 8 位');

      const existing = await findByUserName(env.DB, userName);
      if (existing) return conflict('user_name 已存在');

      const passwordHash = await hashPassword(password);
      const account = await insertAccount(env.DB, crypto.randomUUID(), userName, passwordHash, nickName);

      const token = generateSessionToken();
      await insertSession(
        env.DB,
        crypto.randomUUID(),
        account.id,
        await hashSessionToken(token),
        sessionExpiresAt()
      );

      return json({ token, account: sanitizeAccount(account), kitchen: null }, { status: 201 });
    },
  },
  {
    method: 'POST',
    pattern: /^\/api\/v1\/auth\/login$/,
    handler: async (req, env) => {
      const body = await req.json<{ user_name?: string; password?: string }>();
      const userName = body?.user_name?.trim();
      const password = body?.password;

      if (!userName || !password) return badRequest('user_name 和 password 为必填项');

      const account = await findByUserName(env.DB, userName);
      if (!account) return unauthorized('用户名或密码错误');

      const passwordMatches = await verifyPassword(password, account.password_hash);
      if (!passwordMatches) return unauthorized('用户名或密码错误');

      const token = generateSessionToken();
      await insertSession(
        env.DB,
        crypto.randomUUID(),
        account.id,
        await hashSessionToken(token),
        sessionExpiresAt()
      );

      const kitchen = await findActiveKitchenByAccount(env.DB, account.id);
      return json({ token, account: sanitizeAccount(account), kitchen });
    },
  },
  {
    method: 'POST',
    pattern: /^\/api\/v1\/auth\/logout$/,
    handler: withAuth(async (_req, env, ctx) => {
      await deleteByTokenHash(env.DB, ctx.session.token_hash);
      return json({ ok: true });
    }),
  },
  {
    method: 'GET',
    pattern: /^\/api\/v1\/auth\/me$/,
    handler: withAuth(async (_req, env, ctx) => {
      const kitchen = await findActiveKitchenByAccount(env.DB, ctx.account.id);
      return json({ account: sanitizeAccount(ctx.account), kitchen });
    }),
  },
];
