import type { OrderRow } from '../types';

export async function insertOrder(
  db: D1Database,
  id: string,
  kitchenId: string,
  createdByAccountId: string
): Promise<OrderRow> {
  await db
    .prepare('INSERT INTO orders (id, kitchen_id, created_by_account_id) VALUES (?, ?, ?)')
    .bind(id, kitchenId, createdByAccountId)
    .run();
  return findById(db, id) as Promise<OrderRow>;
}

export async function findOpenByKitchen(
  db: D1Database,
  kitchenId: string
): Promise<OrderRow | null> {
  return db
    .prepare("SELECT * FROM orders WHERE kitchen_id = ? AND status = 'open'")
    .bind(kitchenId)
    .first<OrderRow>();
}

export async function findById(db: D1Database, id: string): Promise<OrderRow | null> {
  return db.prepare('SELECT * FROM orders WHERE id = ?').bind(id).first<OrderRow>();
}

export interface OrderHistoryRow extends OrderRow {
  item_count: number;
  total_quantity: number;
}

export async function listFinishedByKitchen(
  db: D1Database,
  kitchenId: string
): Promise<OrderHistoryRow[]> {
  const result = await db
    .prepare(`
      SELECT
        o.*,
        COUNT(oi.id) AS item_count,
        COALESCE(SUM(oi.quantity), 0) AS total_quantity
      FROM orders o
      LEFT JOIN order_items oi ON oi.order_id = o.id
      WHERE o.kitchen_id = ?
        AND o.status = 'finished'
        AND o.finished_at IS NOT NULL
      GROUP BY o.id
      ORDER BY o.finished_at DESC
    `)
    .bind(kitchenId)
    .all<OrderHistoryRow>();
  return result.results;
}

export async function finishOrder(db: D1Database, id: string): Promise<void> {
  await db
    .prepare("UPDATE orders SET status = 'finished', finished_at = datetime('now') WHERE id = ?")
    .bind(id)
    .run();
}
