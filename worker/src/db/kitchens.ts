import type { KitchenRow } from '../types';

export async function insertKitchen(
  db: D1Database,
  id: string,
  name: string,
  ownerAccountId: string,
  inviteCode: string
): Promise<KitchenRow> {
  await db
    .prepare(
      'INSERT INTO kitchens (id, name, owner_account_id, invite_code) VALUES (?, ?, ?, ?)'
    )
    .bind(id, name, ownerAccountId, inviteCode)
    .run();
  return findById(db, id) as Promise<KitchenRow>;
}

export async function findById(
  db: D1Database,
  id: string
): Promise<KitchenRow | null> {
  return db.prepare('SELECT * FROM kitchens WHERE id = ?').bind(id).first<KitchenRow>();
}

export async function findByInviteCode(
  db: D1Database,
  inviteCode: string
): Promise<KitchenRow | null> {
  return db
    .prepare('SELECT * FROM kitchens WHERE invite_code = ?')
    .bind(inviteCode)
    .first<KitchenRow>();
}

export async function updateName(
  db: D1Database,
  id: string,
  name: string
): Promise<void> {
  await db
    .prepare('UPDATE kitchens SET name = ? WHERE id = ?')
    .bind(name, id)
    .run();
}

export async function rotateInviteCode(
  db: D1Database,
  id: string,
  newCode: string
): Promise<string> {
  await db
    .prepare(
      "UPDATE kitchens SET invite_code = ?, invite_code_rotated_at = datetime('now') WHERE id = ?"
    )
    .bind(newCode, id)
    .run();
  return newCode;
}
