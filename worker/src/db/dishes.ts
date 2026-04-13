import type { DishRow } from '../types';

export async function insertDish(
  db: D1Database,
  id: string,
  kitchenId: string,
  name: string,
  category: string,
  createdByDeviceId: string,
  ingredientsJson = '[]'
): Promise<DishRow> {
  await db
    .prepare(
      'INSERT INTO dishes (id, kitchen_id, name, category, created_by_device_id, ingredients_json) VALUES (?, ?, ?, ?, ?, ?)'
    )
    .bind(id, kitchenId, name, category, createdByDeviceId, ingredientsJson)
    .run();
  return findById(db, id) as Promise<DishRow>;
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
