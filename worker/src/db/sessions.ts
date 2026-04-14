import type { AccountRow, SessionRow } from '../types';

export interface SessionWithAccount {
  id: string;
  account_id: string;
  token_hash: string;
  expires_at: string;
  created_at: string;
  user_name: string;
  password_hash: string;
  nick_name: string;
  account_created_at: string;
}

export async function insertSession(
  db: D1Database,
  id: string,
  accountId: string,
  tokenHash: string,
  expiresAt: string
): Promise<SessionRow> {
  await db
    .prepare(
      'INSERT INTO sessions (id, account_id, token_hash, expires_at) VALUES (?, ?, ?, ?)'
    )
    .bind(id, accountId, tokenHash, expiresAt)
    .run();
  return findById(db, id) as Promise<SessionRow>;
}

export async function findById(
  db: D1Database,
  id: string
): Promise<SessionRow | null> {
  return db.prepare('SELECT * FROM sessions WHERE id = ?').bind(id).first<SessionRow>();
}

export async function findSessionWithAccountByTokenHash(
  db: D1Database,
  tokenHash: string
): Promise<{ session: SessionRow; account: AccountRow } | null> {
  const row = await db
    .prepare(
      `SELECT
         s.id,
         s.account_id,
         s.token_hash,
         s.expires_at,
         s.created_at,
         a.user_name,
         a.password_hash,
         a.nick_name,
         a.created_at AS account_created_at
       FROM sessions s
       JOIN accounts a ON a.id = s.account_id
       WHERE s.token_hash = ?
         AND s.expires_at > datetime('now')
       LIMIT 1`
    )
    .bind(tokenHash)
    .first<SessionWithAccount>();

  if (!row) return null;

  return {
    session: {
      id: row.id,
      account_id: row.account_id,
      token_hash: row.token_hash,
      expires_at: row.expires_at,
      created_at: row.created_at,
    },
    account: {
      id: row.account_id,
      user_name: row.user_name,
      password_hash: row.password_hash,
      nick_name: row.nick_name,
      created_at: row.account_created_at,
    },
  };
}

export async function deleteByTokenHash(
  db: D1Database,
  tokenHash: string
): Promise<void> {
  await db.prepare('DELETE FROM sessions WHERE token_hash = ?').bind(tokenHash).run();
}
