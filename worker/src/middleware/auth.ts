import type { Env, RouteParams, AuthedHandler, RouteHandler } from '../types';
import { hashSessionToken } from '../auth';
import { findSessionWithAccountByTokenHash } from '../db/sessions';
import { unauthorized } from '../router';

export function withAuth(handler: AuthedHandler): RouteHandler {
  return async (req: Request, env: Env, params: RouteParams) => {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return unauthorized('缺少 Authorization Bearer token');
    }

    const token = authHeader.slice('Bearer '.length).trim();
    if (!token) return unauthorized('token 无效');

    const tokenHash = await hashSessionToken(token);
    const result = await findSessionWithAccountByTokenHash(env.DB, tokenHash);
    if (!result) return unauthorized('登录态无效或已过期');

    return handler(req, env, result, params);
  };
}
