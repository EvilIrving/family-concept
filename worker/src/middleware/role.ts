import type { Env, RouteParams, AuthedHandler, Role, RequestContext } from '../types';
import { findByKitchenAndDevice } from '../db/members';
import { findById as findKitchenById } from '../db/kitchens';
import { forbidden, json } from '../router';

/**
 * withRole wraps an authed handler (already has ctx.device) and additionally
 * resolves the member record for the given kitchen, enforcing role requirements.
 *
 * Usage: withDevice(withRole(['owner', 'admin'], 'id')(handler))
 * The kitchenIdParam is the name of the URL param holding the kitchen id (default 'id').
 */
export function withRole(
  allowedRoles: Role[],
  kitchenIdParam = 'id'
): (handler: AuthedHandler) => AuthedHandler {
  return (handler: AuthedHandler) => {
    return async (
      req: Request,
      env: Env,
      ctx: RequestContext,
      params: RouteParams
    ): Promise<Response> => {
      const kitchenId = params[kitchenIdParam];
      if (!kitchenId) return json({ message: '缺少 kitchen id' }, { status: 400 });

      const kitchen = await findKitchenById(env.DB, kitchenId);
      if (!kitchen) return json({ message: 'Kitchen 不存在' }, { status: 404 });

      const member = await findByKitchenAndDevice(env.DB, kitchenId, ctx.device.id);
      if (!member) return forbidden('你不是该 kitchen 的成员');

      if (!allowedRoles.includes(member.role)) return forbidden('权限不足');

      return handler(req, env, { ...ctx, member, kitchen }, params);
    };
  };
}
