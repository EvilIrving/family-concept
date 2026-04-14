PRAGMA foreign_keys = OFF;

CREATE TABLE accounts (
  id            TEXT PRIMARY KEY,
  user_name     TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  nick_name     TEXT NOT NULL,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT INTO accounts (id, user_name, password_hash, nick_name, created_at)
SELECT
  id,
  display_name,
  'migrated$pending_password_reset',
  display_name,
  created_at
FROM devices;

CREATE TABLE sessions (
  id         TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE kitchens_new (
  id                     TEXT PRIMARY KEY,
  name                   TEXT NOT NULL,
  owner_account_id       TEXT NOT NULL REFERENCES accounts(id),
  invite_code            TEXT NOT NULL UNIQUE,
  invite_code_rotated_at TEXT NOT NULL DEFAULT (datetime('now')),
  created_at             TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT INTO kitchens_new (
  id,
  name,
  owner_account_id,
  invite_code,
  invite_code_rotated_at,
  created_at
)
SELECT
  id,
  name,
  owner_device_id,
  invite_code,
  invite_code_rotated_at,
  created_at
FROM kitchens;

CREATE TABLE members_new (
  id         TEXT PRIMARY KEY,
  kitchen_id TEXT NOT NULL REFERENCES kitchens_new(id) ON DELETE CASCADE,
  account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
  role       TEXT NOT NULL CHECK (role IN ('owner','admin','member')),
  status     TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','removed')),
  joined_at  TEXT NOT NULL DEFAULT (datetime('now')),
  removed_at TEXT,
  UNIQUE (kitchen_id, account_id)
);

INSERT INTO members_new (
  id,
  kitchen_id,
  account_id,
  role,
  status,
  joined_at,
  removed_at
)
SELECT
  id,
  kitchen_id,
  device_ref_id,
  role,
  status,
  joined_at,
  removed_at
FROM members;

CREATE TABLE dishes_new (
  id                    TEXT PRIMARY KEY,
  kitchen_id            TEXT NOT NULL REFERENCES kitchens_new(id) ON DELETE CASCADE,
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

INSERT INTO dishes_new (
  id,
  kitchen_id,
  name,
  category,
  image_key,
  ingredients_json,
  created_by_account_id,
  created_at,
  updated_at,
  archived_at
)
SELECT
  id,
  kitchen_id,
  name,
  category,
  image_key,
  ingredients_json,
  created_by_device_id,
  created_at,
  updated_at,
  archived_at
FROM dishes;

CREATE TABLE orders_new (
  id                    TEXT PRIMARY KEY,
  kitchen_id            TEXT NOT NULL REFERENCES kitchens_new(id) ON DELETE RESTRICT,
  status                TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','finished')),
  created_by_account_id TEXT NOT NULL REFERENCES accounts(id),
  created_at            TEXT NOT NULL DEFAULT (datetime('now')),
  finished_at           TEXT
);

INSERT INTO orders_new (
  id,
  kitchen_id,
  status,
  created_by_account_id,
  created_at,
  finished_at
)
SELECT
  id,
  kitchen_id,
  status,
  created_by_device_id,
  created_at,
  finished_at
FROM orders;

CREATE TABLE order_items_new (
  id                  TEXT PRIMARY KEY,
  order_id            TEXT NOT NULL REFERENCES orders_new(id) ON DELETE CASCADE,
  dish_id             TEXT NOT NULL REFERENCES dishes_new(id),
  added_by_account_id TEXT NOT NULL REFERENCES accounts(id),
  quantity            INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
  status              TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting','cooking','done','cancelled')),
  created_at          TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at          TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT INTO order_items_new (
  id,
  order_id,
  dish_id,
  added_by_account_id,
  quantity,
  status,
  created_at,
  updated_at
)
SELECT
  id,
  order_id,
  dish_id,
  added_by_device_id,
  quantity,
  status,
  created_at,
  updated_at
FROM order_items;

DROP INDEX IF EXISTS idx_orders_one_open;

DROP TABLE order_items;
DROP TABLE orders;
DROP TABLE dishes;
DROP TABLE members;
DROP TABLE kitchens;
DROP TABLE devices;

ALTER TABLE kitchens_new RENAME TO kitchens;
ALTER TABLE members_new RENAME TO members;
ALTER TABLE dishes_new RENAME TO dishes;
ALTER TABLE orders_new RENAME TO orders;
ALTER TABLE order_items_new RENAME TO order_items;

CREATE UNIQUE INDEX idx_orders_one_open ON orders(kitchen_id) WHERE status = 'open';

PRAGMA foreign_keys = ON;
