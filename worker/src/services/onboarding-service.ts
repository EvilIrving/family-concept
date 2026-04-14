import type { AccountRow, KitchenRow, MemberRow } from '../types';
import { findById as findAccountById, updateNickName } from '../db/accounts';
import { createKitchen, joinByInviteCode } from './kitchen-service';

export async function onboardingComplete(
  db: D1Database,
  params: {
    account_id: string;
    mode: 'create' | 'join';
    nick_name?: string;
    kitchen_name?: string;
    invite_code?: string;
  }
): Promise<{ account: AccountRow; kitchen: KitchenRow; member: MemberRow }> {
  const { account_id, mode, nick_name, kitchen_name, invite_code } = params;

  const account = await findAccountById(db, account_id);
  if (!account) throw new Error('账号不存在');

  let nextAccount = account;
  if (nick_name && nick_name !== account.nick_name) {
    await updateNickName(db, account.id, nick_name);
    nextAccount = { ...account, nick_name };
  }

  if (mode === 'create') {
    if (!kitchen_name) throw new Error('创建模式需要提供 kitchen_name');
    const { kitchen, member } = await createKitchen(db, nextAccount.id, kitchen_name);
    return { account: nextAccount, kitchen, member };
  } else {
    if (!invite_code) throw new Error('加入模式需要提供 invite_code');
    const { kitchen, member } = await joinByInviteCode(db, nextAccount.id, invite_code);
    return { account: nextAccount, kitchen, member };
  }
}
