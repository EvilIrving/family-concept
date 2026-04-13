import type { MemberRow, Role } from '../types';

export async function insertMember(
  db: D1Database,
  id: string,
  kitchenId: string,
  deviceRefId: string,
  role: Role
): Promise<MemberRow> {
  await db
    .prepare(
      'INSERT INTO members (id, kitchen_id, device_ref_id, role) VALUES (?, ?, ?, ?)'
    )
    .bind(id, kitchenId, deviceRefId, role)
    .run();
  return findByKitchenAndDevice(db, kitchenId, deviceRefId) as Promise<MemberRow>;
}

export async function findByKitchenAndDevice(
  db: D1Database,
  kitchenId: string,
  deviceRefId: string
): Promise<MemberRow | null> {
  return db
    .prepare(
      "SELECT * FROM members WHERE kitchen_id = ? AND device_ref_id = ? AND status = 'active'"
    )
    .bind(kitchenId, deviceRefId)
    .first<MemberRow>();
}

export async function listByKitchen(
  db: D1Database,
  kitchenId: string
): Promise<MemberWithDevice[]> {
  const result = await db
    .prepare(`
      SELECT m.*, d.display_name
      FROM members m
      JOIN devices d ON d.id = m.device_ref_id
      WHERE m.kitchen_id = ? AND m.status = 'active'
      ORDER BY m.joined_at ASC
    `)
    .bind(kitchenId)
    .all<MemberWithDevice>();
  return result.results;
}

export interface MemberWithDevice extends MemberRow {
  display_name: string;
}

export async function removeMember(
  db: D1Database,
  kitchenId: string,
  deviceRefId: string
): Promise<void> {
  await db
    .prepare(
      "UPDATE members SET status = 'removed', removed_at = datetime('now') WHERE kitchen_id = ? AND device_ref_id = ? AND status = 'active'"
    )
    .bind(kitchenId, deviceRefId)
    .run();
}

export async function updateRole(
  db: D1Database,
  kitchenId: string,
  deviceRefId: string,
  role: Role
): Promise<void> {
  await db
    .prepare(
      "UPDATE members SET role = ? WHERE kitchen_id = ? AND device_ref_id = ? AND status = 'active'"
    )
    .bind(role, kitchenId, deviceRefId)
    .run();
}
