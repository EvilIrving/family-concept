import type { DishRow } from '../types';
import {
  insertDishIfUnderLimit,
  findById,
  updateDish as dbUpdateDish,
  archiveDish as dbArchiveDish,
  listByKitchen,
} from '../db/dishes';
import { getEntitlementView } from './entitlement-service';

export class DishLimitExceededError extends Error {
  constructor(public limit: number, public planCode: string) {
    super('已达菜品上限');
  }
}

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

  const entitlement = await getEntitlementView(db, kitchenId);

  const inserted = await insertDishIfUnderLimit(
    db,
    id,
    kitchenId,
    name,
    category,
    createdByAccountId,
    ingredientsJson,
    options?.imageKey ?? null,
    entitlement.dishLimit
  );

  if (!inserted) {
    throw new DishLimitExceededError(entitlement.dishLimit, entitlement.planCode);
  }

  return (await findById(db, id)) as DishRow;
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
