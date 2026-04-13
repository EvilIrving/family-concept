import type { Env, RouteParams, AuthedHandler, RouteHandler } from '../types';
import { findByDeviceId } from '../db/devices';
import { unauthorized } from '../router';

export function withDevice(handler: AuthedHandler): RouteHandler {
  return async (req: Request, env: Env, params: RouteParams) => {
    const deviceId = req.headers.get('X-Device-Id');
    if (!deviceId) return unauthorized('缺少 X-Device-Id header');

    const device = await findByDeviceId(env.DB, deviceId);
    if (!device) return unauthorized('设备未注册');

    return handler(req, env, { device }, params);
  };
}
