import type { MemberRow, Role } from '../types';

export async function insertMember(
  db: D1Database,
  id: string,
  kitchenId: string,
  accountId: string,
  role: Role
): Promise<MemberRow> {
  await db
    .prepare(
      'INSERT INTO members (id, kitchen_id, account_id, role) VALUES (?, ?, ?, ?)'
    )
    .bind(id, kitchenId, accountId, role)
    .run();
  return findByKitchenAndAccount(db, kitchenId, accountId) as Promise<MemberRow>;
}

export async function findByKitchenAndAccount(
  db: D1Database,
  kitchenId: string,
  accountId: string
): Promise<MemberRow | null> {
  return db
    .prepare(
      "SELECT * FROM members WHERE kitchen_id = ? AND account_id = ? AND status = 'active'"
    )
    .bind(kitchenId, accountId)
    .first<MemberRow>();
}

export async function listByKitchen(
  db: D1Database,
  kitchenId: string
): Promise<MemberWithDevice[]> {
  const result = await db
    .prepare(`
      SELECT m.*, a.nick_name
      FROM members m
      JOIN accounts a ON a.id = m.account_id
      WHERE m.kitchen_id = ? AND m.status = 'active'
      ORDER BY m.joined_at ASC
    `)
    .bind(kitchenId)
    .all<MemberWithDevice>();
  return result.results;
}

export interface MemberWithDevice extends MemberRow {
  nick_name: string;
}

export async function removeMember(
  db: D1Database,
  kitchenId: string,
  accountId: string
): Promise<void> {
  await db
    .prepare(
      "UPDATE members SET status = 'removed', removed_at = datetime('now') WHERE kitchen_id = ? AND account_id = ? AND status = 'active'"
    )
    .bind(kitchenId, accountId)
    .run();
}

export async function updateRole(
  db: D1Database,
  kitchenId: string,
  accountId: string,
  role: Role
): Promise<void> {
  await db
    .prepare(
      "UPDATE members SET role = ? WHERE kitchen_id = ? AND account_id = ? AND status = 'active'"
    )
    .bind(role, kitchenId, accountId)
    .run();
}
