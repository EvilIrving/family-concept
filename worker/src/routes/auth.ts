import type { Route } from '../types';
import { json, badRequest } from '../router';
import { findByDisplayName } from '../db/devices';

export const authRoutes: Route[] = [
  {
    method: 'POST',
    pattern: /^\/api\/v1\/auth\/login$/,
    handler: async (req, env) => {
      const body = await req.json<{ display_name?: string }>();
      const displayName = body?.display_name?.trim();
      if (!displayName) return badRequest('display_name 为必填项');

      const device = await findByDisplayName(env.DB, displayName);
      if (!device) return json({ found: false });

      // Find active membership with display_name
      const member = await env.DB
        .prepare(
          `SELECT m.*, d.display_name
           FROM members m
           JOIN devices d ON d.id = m.device_ref_id
           WHERE m.device_ref_id = ? AND m.status = 'active'
           LIMIT 1`
        )
        .bind(device.id)
        .first();

      if (!member) return json({ found: false });

      const kitchen = await env.DB
        .prepare('SELECT * FROM kitchens WHERE id = ?')
        .bind(member.kitchen_id)
        .first();

      if (!kitchen) return json({ found: false });

      return json({ found: true, device, kitchen, member });
    },
  },
];
