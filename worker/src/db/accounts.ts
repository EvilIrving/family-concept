import type { AccountRow } from '../types';

export async function insertAccount(
  db: D1Database,
  id: string,
  userName: string,
  passwordHash: string,
  nickName: string
): Promise<AccountRow> {
  await db
    .prepare(
      'INSERT INTO accounts (id, user_name, password_hash, nick_name) VALUES (?, ?, ?, ?)'
    )
    .bind(id, userName, passwordHash, nickName)
    .run();
  return findById(db, id) as Promise<AccountRow>;
}

export async function findById(
  db: D1Database,
  id: string
): Promise<AccountRow | null> {
  return db.prepare('SELECT * FROM accounts WHERE id = ?').bind(id).first<AccountRow>();
}

export async function findByUserName(
  db: D1Database,
  userName: string
): Promise<AccountRow | null> {
  return db
    .prepare('SELECT * FROM accounts WHERE user_name = ?')
    .bind(userName)
    .first<AccountRow>();
}

export async function updateNickName(
  db: D1Database,
  id: string,
  nickName: string
): Promise<void> {
  await db
    .prepare('UPDATE accounts SET nick_name = ? WHERE id = ?')
    .bind(nickName, id)
    .run();
}
