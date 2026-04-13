import type { Route } from '../types';
import { json, badRequest } from '../router';
import { onboardingComplete } from '../services/onboarding-service';

export const onboardingRoutes: Route[] = [
  {
    method: 'POST',
    pattern: /^\/api\/v1\/onboarding\/complete$/,
    handler: async (req, env) => {
      const body = await req.json<{
        mode?: string;
        device_id?: string;
        display_name?: string;
        kitchen_name?: string;
        invite_code?: string;
      }>();

      const { mode, device_id, display_name, kitchen_name, invite_code } = body ?? {};

      if (!device_id || !display_name) return badRequest('device_id 和 display_name 为必填项');
      if (mode !== 'create' && mode !== 'join') return badRequest('mode 必须为 create 或 join');

      try {
        const result = await onboardingComplete(env.DB, {
          mode,
          device_id,
          display_name,
          kitchen_name,
          invite_code,
        });
        return json(result, { status: 201 });
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : '入驻失败';
        return badRequest(msg);
      }
    },
  },
];
