import type { KitchenRow, MemberRow } from '../types';
import { findByInviteCode } from '../db/kitchens';
import { insertMember, findByKitchenAndAccount, findMemberRecord, reactivateMember } from '../db/members';

function generateInviteCode(): string {
  return crypto.randomUUID().replace(/-/g, '').slice(0, 6).toUpperCase();
}

export async function createKitchen(
  db: D1Database,
  ownerAccountId: string,
  name: string
): Promise<{ kitchen: KitchenRow; member: MemberRow }> {
  const kitchenId = crypto.randomUUID();
  const memberId = crypto.randomUUID();
  const inviteCode = generateInviteCode();

  // Atomic insert of kitchen + owner member
  await db.batch([
    db
      .prepare('INSERT INTO kitchens (id, name, owner_account_id, invite_code) VALUES (?, ?, ?, ?)')
      .bind(kitchenId, name, ownerAccountId, inviteCode),
    db
      .prepare('INSERT INTO members (id, kitchen_id, account_id, role) VALUES (?, ?, ?, ?)')
      .bind(memberId, kitchenId, ownerAccountId, 'owner'),
  ]);

  const [k, m] = await Promise.all([
    db.prepare('SELECT * FROM kitchens WHERE id = ?').bind(kitchenId).first<KitchenRow>(),
    db.prepare('SELECT * FROM members WHERE id = ?').bind(memberId).first<MemberRow>(),
  ]);

  return { kitchen: k!, member: m! };
}

export async function joinByInviteCode(
  db: D1Database,
  accountId: string,
  inviteCode: string
): Promise<{ kitchen: KitchenRow; member: MemberRow }> {
  const kitchen = await findByInviteCode(db, inviteCode);
  if (!kitchen) throw new Error('邀请码无效');

  const existing = await findByKitchenAndAccount(db, kitchen.id, accountId);
  if (existing) {
    return { kitchen, member: existing };
  }

  const existingRecord = await findMemberRecord(db, kitchen.id, accountId);
  if (existingRecord) {
    const member = await reactivateMember(db, kitchen.id, accountId, 'member');
    if (!member) {
      throw new Error('重新加入私厨失败');
    }
    return { kitchen, member };
  }

  const member = await insertMember(db, crypto.randomUUID(), kitchen.id, accountId, 'member');
  return { kitchen, member };
}
