import type { DishRow } from '../types';

export async function insertDish(
  db: D1Database,
  id: string,
  kitchenId: string,
  name: string,
  category: string,
  createdByAccountId: string,
  ingredientsJson = '[]',
  imageKey: string | null = null
): Promise<DishRow> {
  await db
    .prepare(
      'INSERT INTO dishes (id, kitchen_id, name, category, image_key, created_by_account_id, ingredients_json) VALUES (?, ?, ?, ?, ?, ?, ?)'
    )
    .bind(id, kitchenId, name, category, imageKey, createdByAccountId, ingredientsJson)
    .run();
  return findById(db, id) as Promise<DishRow>;
}

/**
 * 原子 INSERT：仅当 kitchen 未归档菜品数 < dishLimit 时写入成功。
 * 返回值 true 表示成功，false 表示被额度拦截。
 * 条件 SELECT 与 INSERT 合并为一条语句，规避并发下的 TOCTOU。
 */
export async function insertDishIfUnderLimit(
  db: D1Database,
  id: string,
  kitchenId: string,
  name: string,
  category: string,
  createdByAccountId: string,
  ingredientsJson: string,
  imageKey: string | null,
  dishLimit: number
): Promise<boolean> {
  const result = await db
    .prepare(
      `INSERT INTO dishes (id, kitchen_id, name, category, image_key, created_by_account_id, ingredients_json)
       SELECT ?, ?, ?, ?, ?, ?, ?
       WHERE (SELECT COUNT(*) FROM dishes WHERE kitchen_id = ? AND archived_at IS NULL) < ?`
    )
    .bind(
      id,
      kitchenId,
      name,
      category,
      imageKey,
      createdByAccountId,
      ingredientsJson,
      kitchenId,
      dishLimit
    )
    .run();
  return (result.meta?.changes ?? 0) > 0;
}

export async function countActiveByKitchen(
  db: D1Database,
  kitchenId: string
): Promise<number> {
  const row = await db
    .prepare('SELECT COUNT(*) as c FROM dishes WHERE kitchen_id = ? AND archived_at IS NULL')
    .bind(kitchenId)
    .first<{ c: number }>();
  return row?.c ?? 0;
}

export async function findById(db: D1Database, id: string): Promise<DishRow | null> {
  return db.prepare('SELECT * FROM dishes WHERE id = ?').bind(id).first<DishRow>();
}

export async function listByKitchen(db: D1Database, kitchenId: string): Promise<DishRow[]> {
  const result = await db
    .prepare('SELECT * FROM dishes WHERE kitchen_id = ? AND archived_at IS NULL ORDER BY created_at ASC')
    .bind(kitchenId)
    .all<DishRow>();
  return result.results;
}

export async function updateDish(
  db: D1Database,
  id: string,
  fields: Partial<Pick<DishRow, 'name' | 'category' | 'ingredients_json' | 'image_key'>>
): Promise<void> {
  const sets: string[] = ["updated_at = datetime('now')"];
  const bindings: unknown[] = [];

  if (fields.name !== undefined) { sets.push('name = ?'); bindings.push(fields.name); }
  if (fields.category !== undefined) { sets.push('category = ?'); bindings.push(fields.category); }
  if (fields.ingredients_json !== undefined) { sets.push('ingredients_json = ?'); bindings.push(fields.ingredients_json); }
  if (fields.image_key !== undefined) { sets.push('image_key = ?'); bindings.push(fields.image_key); }

  bindings.push(id);
  await db
    .prepare(`UPDATE dishes SET ${sets.join(', ')} WHERE id = ?`)
    .bind(...bindings)
    .run();
}

export async function archiveDish(db: D1Database, id: string): Promise<void> {
  await db
    .prepare("UPDATE dishes SET archived_at = datetime('now') WHERE id = ?")
    .bind(id)
    .run();
}
