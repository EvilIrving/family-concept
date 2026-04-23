-- 厨房付费权益表：绑定 kitchen 与 Apple 一次性买断商品
CREATE TABLE kitchen_entitlements (
  id                       TEXT PRIMARY KEY,
  kitchen_id               TEXT NOT NULL REFERENCES kitchens(id) ON DELETE CASCADE,
  plan_code                TEXT NOT NULL CHECK (plan_code IN ('free','dishes_fifty','dishes_unlimited')),
  dish_limit               INTEGER,
  store_product_id         TEXT,
  original_transaction_id  TEXT,
  app_account_token_hash   TEXT,
  source                   TEXT NOT NULL DEFAULT 'app_store' CHECK (source IN ('app_store','offer_code','admin')),
  activated_at             TEXT NOT NULL DEFAULT (datetime('now')),
  revoked_at               TEXT,
  created_at               TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at               TEXT NOT NULL DEFAULT (datetime('now'))
);

-- 同一 original_transaction_id 只能绑定一个 kitchen（未撤销状态下）
CREATE UNIQUE INDEX idx_entitlement_txn_active
  ON kitchen_entitlements(original_transaction_id)
  WHERE original_transaction_id IS NOT NULL AND revoked_at IS NULL;

-- 单个厨房只保留一条活跃 entitlement，业务层写入时负责覆盖低档
CREATE INDEX idx_entitlement_kitchen_active
  ON kitchen_entitlements(kitchen_id)
  WHERE revoked_at IS NULL;
