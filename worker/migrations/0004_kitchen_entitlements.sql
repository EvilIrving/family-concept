-- 厨房付费权益表：绑定 kitchen 与 Apple 一次性买断商品
CREATE TABLE kitchen_entitlements (
  id                       TEXT PRIMARY KEY,
  kitchen_id               TEXT NOT NULL REFERENCES kitchens(id) ON DELETE CASCADE,
  plan_code                TEXT NOT NULL CHECK (plan_code IN ('free','dishes_fifty','dishes_unlimited')),
  dish_limit               INTEGER,
  store_product_id         TEXT,
  original_transaction_id  TEXT,
  app_account_token_hash   TEXT,
  verification_environment TEXT,
  source                   TEXT NOT NULL DEFAULT 'app_store' CHECK (source IN ('app_store','offer_code','admin')),
  activated_at             TEXT NOT NULL DEFAULT (datetime('now')),
  revoked_at               TEXT,
  revocation_reason        TEXT,
  last_verified_at         TEXT,
  last_seen_at             TEXT,
  status_version           INTEGER NOT NULL DEFAULT 1,
  signed_transaction       TEXT,
  created_at               TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at               TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE UNIQUE INDEX idx_entitlement_txn
  ON kitchen_entitlements(original_transaction_id)
  WHERE original_transaction_id IS NOT NULL;

CREATE INDEX idx_entitlement_kitchen_active
  ON kitchen_entitlements(kitchen_id)
  WHERE revoked_at IS NULL;

CREATE INDEX idx_entitlement_kitchen_recent
  ON kitchen_entitlements(kitchen_id, updated_at DESC);
