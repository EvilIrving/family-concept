import type { DishRow } from '../types';
import { insertDish, findById, updateDish as dbUpdateDish, archiveDish as dbArchiveDish, listByKitchen } from '../db/dishes';

export async function createDish(
  db: D1Database,
  kitchenId: string,
  createdByDeviceId: string,
  name: string,
  category: string,
  ingredients?: unknown[]
): Promise<DishRow> {
  const id = crypto.randomUUID();
  const ingredientsJson = JSON.stringify(ingredients ?? []);
  return insertDish(db, id, kitchenId, name, category, createdByDeviceId, ingredientsJson);
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
