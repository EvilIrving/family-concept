import type { OrderItemRow, OrderItemStatus } from '../types';

export async function insertItem(
  db: D1Database,
  id: string,
  orderId: string,
  dishId: string,
  addedByDeviceId: string,
  quantity: number
): Promise<OrderItemRow> {
  await db
    .prepare(
      'INSERT INTO order_items (id, order_id, dish_id, added_by_device_id, quantity) VALUES (?, ?, ?, ?, ?)'
    )
    .bind(id, orderId, dishId, addedByDeviceId, quantity)
    .run();
  return findItemById(db, id) as Promise<OrderItemRow>;
}

export async function findItemById(db: D1Database, id: string): Promise<OrderItemRow | null> {
  return db.prepare('SELECT * FROM order_items WHERE id = ?').bind(id).first<OrderItemRow>();
}

export async function updateItem(
  db: D1Database,
  id: string,
  fields: { status?: OrderItemStatus; quantity?: number }
): Promise<void> {
  const sets: string[] = ["updated_at = datetime('now')"];
  const bindings: unknown[] = [];

  if (fields.status !== undefined) { sets.push('status = ?'); bindings.push(fields.status); }
  if (fields.quantity !== undefined) { sets.push('quantity = ?'); bindings.push(fields.quantity); }

  bindings.push(id);
  await db
    .prepare(`UPDATE order_items SET ${sets.join(', ')} WHERE id = ?`)
    .bind(...bindings)
    .run();
}

export async function listByOrder(db: D1Database, orderId: string): Promise<OrderItemRow[]> {
  const result = await db
    .prepare('SELECT * FROM order_items WHERE order_id = ? ORDER BY created_at ASC')
    .bind(orderId)
    .all<OrderItemRow>();
  return result.results;
}

export interface ShoppingListItem {
  dish_id: string;
  dish_name: string;
  category: string;
  total_quantity: number;
}

export async function aggregateShoppingList(
  db: D1Database,
  orderId: string
): Promise<ShoppingListItem[]> {
  const result = await db
    .prepare(`
      SELECT
        d.id AS dish_id,
        d.name AS dish_name,
        d.category,
        SUM(oi.quantity) AS total_quantity
      FROM order_items oi
      JOIN dishes d ON oi.dish_id = d.id
      WHERE oi.order_id = ? AND oi.status != 'cancelled'
      GROUP BY d.id
      ORDER BY d.category, d.name
    `)
    .bind(orderId)
    .all<ShoppingListItem>();
  return result.results;
}
