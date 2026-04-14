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

export async function finishOrder(db: D1Database, id: string): Promise<void> {
  await db
    .prepare("UPDATE orders SET status = 'finished', finished_at = datetime('now') WHERE id = ?")
    .bind(id)
    .run();
}
