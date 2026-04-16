import type { OrderRow, OrderItemRow } from '../types';
import { insertOrder, findOpenByKitchen, finishOrder } from '../db/orders';
import { insertItem, markActiveItemsDoneByOrder } from '../db/order-items';
import { findById as findDish } from '../db/dishes';

export async function createOrder(
  db: D1Database,
  kitchenId: string,
  createdByAccountId: string
): Promise<OrderRow> {
  const existing = await findOpenByKitchen(db, kitchenId);
  if (existing) throw new Error('该 kitchen 已有进行中的订单');

  return insertOrder(db, crypto.randomUUID(), kitchenId, createdByAccountId);
}

export async function addItemToOrder(
  db: D1Database,
  order: OrderRow,
  dishId: string,
  addedByAccountId: string,
  quantity: number
): Promise<OrderItemRow> {
  if (order.status !== 'open') throw new Error('订单已结束');

  const dish = await findDish(db, dishId);
  if (!dish || dish.kitchen_id !== order.kitchen_id || dish.archived_at !== null) {
    throw new Error('菜品不存在或不属于该 kitchen');
  }

  return insertItem(db, crypto.randomUUID(), order.id, dishId, addedByAccountId, quantity);
}

export async function closeOrder(db: D1Database, orderId: string): Promise<void> {
  await markActiveItemsDoneByOrder(db, orderId);
  await finishOrder(db, orderId);
}
