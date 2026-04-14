import type { Route } from '../types';
import { json, badRequest, conflict } from '../router';
import { insertDevice, findByDeviceId, findByDisplayName } from '../db/devices';

export const deviceRoutes: Route[] = [
  {
    method: 'POST',
    pattern: /^\/api\/v1\/devices\/register$/,
    handler: async (req, env) => {
      const body = await req.json<{ device_id?: string; display_name?: string }>();
      const { device_id, display_name } = body ?? {};
      if (!device_id || !display_name) {
        return badRequest('device_id 和 display_name 为必填项');
      }

      const existing = await findByDeviceId(env.DB, device_id);
      if (existing) return conflict('设备已注册');

      const nameTaken = await findByDisplayName(env.DB, display_name);
      if (nameTaken) return conflict('该名字已被使用');

      const id = crypto.randomUUID();
      const device = await insertDevice(env.DB, id, device_id, display_name);
      return json(device, { status: 201 });
    },
  },
  {
    method: 'GET',
    pattern: /^\/api\/v1\/devices\/by-device\/(?<device_id>[^/]+)$/,
    handler: async (_req, env, params) => {
      const device = await findByDeviceId(env.DB, params.device_id);
      if (!device) return json({ message: '设备不存在' }, { status: 404 });
      return json(device);
    },
  },
];
