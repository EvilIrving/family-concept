import type { DishRow } from '../types';
import { insertDish, findById, updateDish as dbUpdateDish, archiveDish as dbArchiveDish, listByKitchen } from '../db/dishes';

export async function createDish(
  db: D1Database,
  kitchenId: string,
  createdByAccountId: string,
  name: string,
  category: string,
  ingredients?: unknown[],
  options?: { id?: string; imageKey?: string | null }
): Promise<DishRow> {
  const id = options?.id ?? crypto.randomUUID();
  const ingredientsJson = JSON.stringify(ingredients ?? []);
  return insertDish(
    db,
    id,
    kitchenId,
    name,
    category,
    createdByAccountId,
    ingredientsJson,
    options?.imageKey ?? null
  );
}

export async function getDishForKitchen(
  db: D1Database,
  dishId: string,
  kitchenId: string
): Promise<DishRow | null> {
  const dish = await findById(db, dishId);
  if (!dish || dish.kitchen_id !== kitchenId || dish.archived_at !== null) return null;
  return dish;
}

export { listByKitchen, dbUpdateDish as updateDish, dbArchiveDish as archiveDish, findById };
