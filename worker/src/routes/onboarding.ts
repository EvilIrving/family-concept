import type { Route } from '../types';
import { json, badRequest } from '../router';
import { onboardingComplete } from '../services/onboarding-service';
import { withAuth } from '../middleware/auth';

function sanitizeAccount(account: { id: string; user_name: string; nick_name: string; created_at: string }) {
  return {
    id: account.id,
    user_name: account.user_name,
    nick_name: account.nick_name,
    created_at: account.created_at,
  };
}

export const onboardingRoutes: Route[] = [
  {
    method: 'POST',
    pattern: /^\/api\/v1\/onboarding\/complete$/,
    handler: withAuth(async (req, env, ctx) => {
      const body = await req.json<{
        mode?: string;
        nick_name?: string;
        kitchen_name?: string;
        invite_code?: string;
      }>();

      const { mode, nick_name, kitchen_name, invite_code } = body ?? {};

      if (mode !== 'create' && mode !== 'join') return badRequest('mode 必须为 create 或 join');

      try {
        const result = await onboardingComplete(env.DB, {
          account_id: ctx.account.id,
          mode,
          nick_name: nick_name?.trim(),
          kitchen_name,
          invite_code,
        });
        return json({ ...result, account: sanitizeAccount(result.account) }, { status: 201 });
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : '入驻失败';
        return badRequest(msg);
      }
    }),
  },
];
