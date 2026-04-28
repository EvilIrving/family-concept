import type { MemberRow, Role } from '../types';
import type { KitchenRow } from '../types';

export async function insertMember(
  db: D1Database,
  id: string,
  kitchenId: string,
  accountId: string,
  role: Role
): Promise<MemberRow> {
  try {
    await db
      .prepare(
        'INSERT INTO members (id, kitchen_id, account_id, role) VALUES (?, ?, ?, ?)'
      )
      .bind(id, kitchenId, accountId, role)
      .run();
  } catch (e: unknown) {
    const message = e instanceof Error ? e.message : '';
    if (!message.includes('UNIQUE constraint failed: members.kitchen_id, members.account_id')) {
      throw e;
    }
  }

  const member = await findByKitchenAndAccount(db, kitchenId, accountId);
  if (member) return member;

  return reactivateMember(db, kitchenId, accountId, role) as Promise<MemberRow>;
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

export async function findMemberRecord(
  db: D1Database,
  kitchenId: string,
  accountId: string
): Promise<MemberRow | null> {
  return db
    .prepare('SELECT * FROM members WHERE kitchen_id = ? AND account_id = ?')
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

export async function findActiveKitchenByAccount(
  db: D1Database,
  accountId: string
): Promise<KitchenRow | null> {
  return db
    .prepare(`
      SELECT k.*
      FROM members m
      JOIN kitchens k ON k.id = m.kitchen_id
      WHERE m.account_id = ? AND m.status = 'active'
      ORDER BY m.joined_at DESC
      LIMIT 1
    `)
    .bind(accountId)
    .first<KitchenRow>();
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

export async function reactivateMember(
  db: D1Database,
  kitchenId: string,
  accountId: string,
  role: Role = 'member'
): Promise<MemberRow | null> {
  await db
    .prepare(
      "UPDATE members SET role = ?, status = 'active', joined_at = datetime('now'), removed_at = NULL WHERE kitchen_id = ? AND account_id = ?"
    )
    .bind(role, kitchenId, accountId)
    .run();

  return findByKitchenAndAccount(db, kitchenId, accountId);
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
