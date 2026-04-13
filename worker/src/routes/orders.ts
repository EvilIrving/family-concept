import type { Route } from '../types';
import { json, badRequest, forbidden } from '../router';
import { withDevice } from '../middleware/auth';
import { withRole } from '../middleware/role';
import { findOpenByKitchen, findById as findOrder } from '../db/orders';
import { findItemById, updateItem, listByOrder, aggregateShoppingList } from '../db/order-items';
import { createOrder, addItemToOrder, closeOrder } from '../services/order-service';
import { findByKitchenAndDevice } from '../db/members';

export const orderRoutes: Route[] = [
  // GET /kitchens/:id/orders/open
  {
    method: 'GET',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)\/orders\/open$/,
    handler: withDevice(
      withRole(['owner', 'admin', 'member'])(async (_req, env, ctx) => {
        const order = await findOpenByKitchen(env.DB, ctx.kitchen!.id);
        if (!order) return json(null);
        const items = await listByOrder(env.DB, order.id);
        return json({ ...order, items });
      })
    ),
  },

  // POST /kitchens/:id/orders — 创建新订单
  {
    method: 'POST',
    pattern: /^\/api\/v1\/kitchens\/(?<id>[^/]+)\/orders$/,
    handler: withDevice(
      withRole(['owner', 'admin', 'member'])(async (_req, env, ctx) => {
        try {
          const order = await createOrder(env.DB, ctx.kitchen!.id, ctx.device.id);
          return json(order, { status: 201 });
        } catch (e: unknown) {
          return badRequest(e instanceof Error ? e.message : '创建订单失败');
        }
      })
    ),
  },

  // POST /orders/:order_id/items — 追加菜品
  {
    method: 'POST',
    pattern: /^\/api\/v1\/orders\/(?<order_id>[^/]+)\/items$/,
    handler: withDevice(async (req, env, ctx, params) => {
      const order = await findOrder(env.DB, params.order_id);
      if (!order) return json({ message: '订单不存在' }, { status: 404 });

      const member = await findByKitchenAndDevice(env.DB, order.kitchen_id, ctx.device.id);
      if (!member) return forbidden('你不是该 kitchen 的成员');

      const body = await req.json<{ dish_id?: string; quantity?: number }>();
      if (!body?.dish_id) return badRequest('dish_id 为必填项');
      const quantity = body.quantity ?? 1;
      if (quantity < 1) return badRequest('quantity 必须大于 0');

      try {
        const item = await addItemToOrder(env.DB, order, body.dish_id, ctx.device.id, quantity);
        return json(item, { status: 201 });
      } catch (e: unknown) {
        return badRequest(e instanceof Error ? e.message : '添加失败');
      }
    }),
  },

  // PATCH /order_items/:item_id — 改状态或数量
  {
    method: 'PATCH',
    pattern: /^\/api\/v1\/order_items\/(?<item_id>[^/]+)$/,
    handler: withDevice(async (req, env, ctx, params) => {
      const item = await findItemById(env.DB, params.item_id);
      if (!item) return json({ message: '订单项不存在' }, { status: 404 });

      const order = await findOrder(env.DB, item.order_id);
      if (!order) return json({ message: '订单不存在' }, { status: 404 });

      const member = await findByKitchenAndDevice(env.DB, order.kitchen_id, ctx.device.id);
      if (!member) return forbidden('你不是该 kitchen 的成员');
      if (member.role === 'member') return forbidden('member 不可修改订单项状态');

      const body = await req.json<{ status?: string; quantity?: number }>();
      const validStatuses = ['waiting', 'cooking', 'done', 'cancelled'];
      if (body.status && !validStatuses.includes(body.status)) {
        return badRequest('status 值无效');
      }

      await updateItem(env.DB, item.id, {
        status: body.status as any,
        quantity: body.quantity,
      });

      const updated = await findItemById(env.DB, item.id);
      return json(updated);
    }),
  },

  // POST /orders/:order_id/finish — 结束订单
  {
    method: 'POST',
    pattern: /^\/api\/v1\/orders\/(?<order_id>[^/]+)\/finish$/,
    handler: withDevice(async (_req, env, ctx, params) => {
      const order = await findOrder(env.DB, params.order_id);
      if (!order) return json({ message: '订单不存在' }, { status: 404 });
      if (order.status !== 'open') return badRequest('订单已结束');

      const member = await findByKitchenAndDevice(env.DB, order.kitchen_id, ctx.device.id);
      if (!member) return forbidden('你不是该 kitchen 的成员');
      if (member.role === 'member') return forbidden('member 不可结束订单');

      await closeOrder(env.DB, order.id);
      const updated = await findOrder(env.DB, order.id);
      return json(updated);
    }),
  },

  // GET /orders/:order_id/shopping_list — 采购清单
  {
    method: 'GET',
    pattern: /^\/api\/v1\/orders\/(?<order_id>[^/]+)\/shopping_list$/,
    handler: withDevice(async (_req, env, ctx, params) => {
      const order = await findOrder(env.DB, params.order_id);
      if (!order) return json({ message: '订单不存在' }, { status: 404 });

      const member = await findByKitchenAndDevice(env.DB, order.kitchen_id, ctx.device.id);
      if (!member) return forbidden('你不是该 kitchen 的成员');

      const list = await aggregateShoppingList(env.DB, order.id);
      return json(list);
    }),
  },
];
