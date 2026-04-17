PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS accounts (
  id            TEXT PRIMARY KEY,
  user_name     TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  nick_name     TEXT NOT NULL,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS sessions (
  id         TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS kitchens (
  id                     TEXT PRIMARY KEY,
  name                   TEXT NOT NULL,
  owner_account_id       TEXT NOT NULL REFERENCES accounts(id),
  invite_code            TEXT NOT NULL UNIQUE,
  invite_code_rotated_at TEXT NOT NULL DEFAULT (datetime('now')),
  created_at             TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS members (
  id         TEXT PRIMARY KEY,
  kitchen_id TEXT NOT NULL REFERENCES kitchens(id) ON DELETE CASCADE,
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  role       TEXT NOT NULL CHECK (role IN ('owner','admin','member')),
  status     TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','removed')),
  joined_at  TEXT NOT NULL DEFAULT (datetime('now')),
  removed_at TEXT,
  UNIQUE (kitchen_id, account_id)
);

CREATE TABLE IF NOT EXISTS dishes (
  id                    TEXT PRIMARY KEY,
  kitchen_id            TEXT NOT NULL REFERENCES kitchens(id) ON DELETE CASCADE,
  name                  TEXT NOT NULL,
  category              TEXT NOT NULL,
  image_key             TEXT,
  ingredients_json      TEXT NOT NULL DEFAULT '[]',
  created_by_account_id TEXT NOT NULL REFERENCES accounts(id),
  created_at            TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at            TEXT NOT NULL DEFAULT (datetime('now')),
  archived_at           TEXT,
  UNIQUE (kitchen_id, name)
);

CREATE TABLE IF NOT EXISTS orders (
  id                    TEXT PRIMARY KEY,
  kitchen_id            TEXT NOT NULL REFERENCES kitchens(id) ON DELETE RESTRICT,
  status                TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','finished')),
  created_by_account_id TEXT NOT NULL REFERENCES accounts(id),
  created_at            TEXT NOT NULL DEFAULT (datetime('now')),
  finished_at           TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_one_open
ON orders(kitchen_id)
WHERE status = 'open';

CREATE TABLE IF NOT EXISTS order_items (
  id                  TEXT PRIMARY KEY,
  order_id            TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  dish_id             TEXT NOT NULL REFERENCES dishes(id),
  added_by_account_id TEXT NOT NULL REFERENCES accounts(id),
  quantity            INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  status              TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting','cooking','done','cancelled')),
  created_at          TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at          TEXT NOT NULL DEFAULT (datetime('now'))
);
