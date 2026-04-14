export interface Env {
  DB: D1Database;
  ASSETS: R2Bucket;
  APP_ENV: string;
  KITCHEN_LIVE: DurableObjectNamespace;
}

// ─── DB Row Types ────────────────────────────────────────────────────────────

export interface AccountRow {
  id: string;
  user_name: string;
  password_hash: string;
  nick_name: string;
  created_at: string;
}

export interface SessionRow {
  id: string;
  account_id: string;
  token_hash: string;
  expires_at: string;
  created_at: string;
}

export interface KitchenRow {
  id: string;
  name: string;
  owner_account_id: string;
  invite_code: string;
  invite_code_rotated_at: string;
  created_at: string;
}

export interface MemberRow {
  id: string;
  kitchen_id: string;
  account_id: string;
  role: Role;
  status: MemberStatus;
  joined_at: string;
  removed_at: string | null;
}

export interface DishRow {
  id: string;
  kitchen_id: string;
  name: string;
  category: string;
  image_key: string | null;
  ingredients_json: string;
  created_by_account_id: string;
  created_at: string;
  updated_at: string;
  archived_at: string | null;
}

export interface OrderRow {
  id: string;
  kitchen_id: string;
  status: OrderStatus;
  created_by_account_id: string;
  created_at: string;
  finished_at: string | null;
}

export interface OrderItemRow {
  id: string;
  order_id: string;
  dish_id: string;
  added_by_account_id: string;
  quantity: number;
  status: OrderItemStatus;
  created_at: string;
  updated_at: string;
}

// ─── Enum-like Types ─────────────────────────────────────────────────────────

export type Role = 'owner' | 'admin' | 'member';
export type MemberStatus = 'active' | 'removed';
export type OrderStatus = 'open' | 'finished';
export type OrderItemStatus = 'waiting' | 'cooking' | 'done' | 'cancelled';

// ─── Request Context ─────────────────────────────────────────────────────────

export interface RequestContext {
  account: AccountRow;
  session: SessionRow;
  member?: MemberRow;
  kitchen?: KitchenRow;
}

// ─── Router Types ─────────────────────────────────────────────────────────────

export type RouteParams = Record<string, string>;

export type RouteHandler = (
  req: Request,
  env: Env,
  params: RouteParams
) => Promise<Response>;

export type AuthedHandler = (
  req: Request,
  env: Env,
  ctx: RequestContext,
  params: RouteParams
) => Promise<Response>;

export interface Route {
  method: string;
  pattern: RegExp;
  handler: RouteHandler;
}
