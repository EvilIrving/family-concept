import type { KitchenRow, MemberRow } from '../types';
import { findByInviteCode } from '../db/kitchens';
import { insertMember, findByKitchenAndDevice } from '../db/members';

function generateInviteCode(): string {
  return crypto.randomUUID().replace(/-/g, '').slice(0, 6).toUpperCase();
}

export async function createKitchen(
  db: D1Database,
  ownerDeviceId: string,
  name: string
): Promise<{ kitchen: KitchenRow; member: MemberRow }> {
  const kitchenId = crypto.randomUUID();
  const memberId = crypto.randomUUID();
  const inviteCode = generateInviteCode();

  // Atomic insert of kitchen + owner member
  await db.batch([
    db
      .prepare('INSERT INTO kitchens (id, name, owner_device_id, invite_code) VALUES (?, ?, ?, ?)')
      .bind(kitchenId, name, ownerDeviceId, inviteCode),
    db
      .prepare('INSERT INTO members (id, kitchen_id, device_ref_id, role) VALUES (?, ?, ?, ?)')
      .bind(memberId, kitchenId, ownerDeviceId, 'owner'),
  ]);

  const [k, m] = await Promise.all([
    db.prepare('SELECT * FROM kitchens WHERE id = ?').bind(kitchenId).first<KitchenRow>(),
    db.prepare('SELECT * FROM members WHERE id = ?').bind(memberId).first<MemberRow>(),
  ]);

  return { kitchen: k!, member: m! };
}

export async function joinByInviteCode(
  db: D1Database,
  deviceRefId: string,
  inviteCode: string
): Promise<{ kitchen: KitchenRow; member: MemberRow }> {
  const kitchen = await findByInviteCode(db, inviteCode);
  if (!kitchen) throw new Error('邀请码无效');

  const existing = await findByKitchenAndDevice(db, kitchen.id, deviceRefId);
  if (existing) throw new Error('已经是该 kitchen 的成员');

  const member = await insertMember(db, crypto.randomUUID(), kitchen.id, deviceRefId, 'member');
  return { kitchen, member };
}
