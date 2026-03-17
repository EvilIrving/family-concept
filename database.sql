-- ===== Database Design (Supabase / PostgreSQL) =====

-- 枚举类型
CREATE TYPE order_status AS ENUM ('ordering', 'placed', 'finished');
CREATE TYPE item_status AS ENUM ('waiting', 'cooking', 'done');


-- 用户档案
CREATE TABLE profiles (
  id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username    TEXT NOT NULL UNIQUE,
  avatar_url  TEXT,
  is_admin    BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- 菜品
CREATE TABLE dishes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name         TEXT NOT NULL,
  category     TEXT NOT NULL,
  image_url    TEXT,
  ingredients  JSONB NOT NULL DEFAULT '[]',
  -- 示例结构: [{"name":"番茄","amount":2,"unit":"个"}, ...]
  created_by   UUID NOT NULL REFERENCES profiles(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- 订单
CREATE TABLE orders (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  status        order_status NOT NULL DEFAULT 'ordering',
  share_token   TEXT NOT NULL UNIQUE DEFAULT encode(gen_random_bytes(24), 'base64url'),
  created_by    UUID NOT NULL REFERENCES profiles(id),
  current_round INT NOT NULL DEFAULT 1,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  finished_at   TIMESTAMPTZ
);


-- 订单成员
CREATE TABLE order_members (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id   UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES profiles(id),
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 核心约束：同一用户只能存在于一个活跃订单
CREATE UNIQUE INDEX one_active_order_per_user
  ON order_members (user_id)
  WHERE (
    SELECT status FROM orders WHERE id = order_id
  ) != 'finished';
-- 注：Supabase 不支持在 partial index 中使用子查询，
-- 实际应通过 DB Function 或 trigger 在插入前校验：
-- 若用户已存在于任意 status != 'finished' 的订单中则 RAISE EXCEPTION


-- 替代约束方案（推荐）：使用 trigger
CREATE OR REPLACE FUNCTION check_one_active_order()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM order_members om
    JOIN orders o ON o.id = om.order_id
    WHERE om.user_id = NEW.user_id
      AND o.status != 'finished'
  ) THEN
    RAISE EXCEPTION 'User already in an active order';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_one_active_order
  BEFORE INSERT ON order_members
  FOR EACH ROW EXECUTE FUNCTION check_one_active_order();


-- 订单菜品项
CREATE TABLE order_items (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id     UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  dish_id      UUID NOT NULL REFERENCES dishes(id),
  added_by     UUID NOT NULL REFERENCES profiles(id),
  quantity     INT NOT NULL DEFAULT 1 CHECK (quantity > 0),
  status       item_status NOT NULL DEFAULT 'waiting',
  order_round  INT NOT NULL DEFAULT 1,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ===== Row Level Security =====

ALTER TABLE profiles    ENABLE ROW LEVEL SECURITY;
ALTER TABLE dishes      ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders      ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;


-- profiles
-- 任何已登录用户可读所有 profile（显示点菜人名称需要）
CREATE POLICY "profiles: read all"
  ON profiles FOR SELECT
  TO authenticated USING (TRUE);

-- 用户只能更新自己的非 is_admin 字段
CREATE POLICY "profiles: update own"
  ON profiles FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (
    id = auth.uid()
    AND is_admin = (SELECT is_admin FROM profiles WHERE id = auth.uid())
    -- 禁止普通用户自行修改 is_admin
  );

-- 只有管理员可以修改任意用户的 is_admin
CREATE POLICY "profiles: admin update is_admin"
  ON profiles FOR UPDATE
  TO authenticated
  USING ((SELECT is_admin FROM profiles WHERE id = auth.uid()) = TRUE);


-- dishes
CREATE POLICY "dishes: read all"
  ON dishes FOR SELECT
  TO authenticated USING (TRUE);

CREATE POLICY "dishes: admin write"
  ON dishes FOR ALL
  TO authenticated
  USING ((SELECT is_admin FROM profiles WHERE id = auth.uid()) = TRUE)
  WITH CHECK ((SELECT is_admin FROM profiles WHERE id = auth.uid()) = TRUE);


-- orders
-- 成员可读自己所在的订单
CREATE POLICY "orders: member read"
  ON orders FOR SELECT
  TO authenticated
  USING (
    id IN (SELECT order_id FROM order_members WHERE user_id = auth.uid())
  );

-- 任何登录用户可创建订单
CREATE POLICY "orders: create"
  ON orders FOR INSERT
  TO authenticated
  WITH CHECK (created_by = auth.uid());

-- 只有管理员可更新订单状态
CREATE POLICY "orders: admin update"
  ON orders FOR UPDATE
  TO authenticated
  USING ((SELECT is_admin FROM profiles WHERE id = auth.uid()) = TRUE);


-- order_members
CREATE POLICY "order_members: read own order"
  ON order_members FOR SELECT
  TO authenticated
  USING (
    order_id IN (SELECT order_id FROM order_members WHERE user_id = auth.uid())
  );

CREATE POLICY "order_members: join"
  ON order_members FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());


-- order_items
-- 订单成员可读订单内所有菜品
CREATE POLICY "order_items: member read"
  ON order_items FOR SELECT
  TO authenticated
  USING (
    order_id IN (SELECT order_id FROM order_members WHERE user_id = auth.uid())
  );

-- 订单成员可在 ordering / placed 状态下加菜
CREATE POLICY "order_items: member insert"
  ON order_items FOR INSERT
  TO authenticated
  WITH CHECK (
    added_by = auth.uid()
    AND (SELECT status FROM orders WHERE id = order_id) != 'finished'
    AND order_id IN (SELECT order_id FROM order_members WHERE user_id = auth.uid())
  );

-- 用户可删除自己在 ordering 状态下加的菜
CREATE POLICY "order_items: delete own before placed"
  ON order_items FOR DELETE
  TO authenticated
  USING (
    added_by = auth.uid()
    AND (SELECT status FROM orders WHERE id = order_id) = 'ordering'
  );

-- 管理员可更新任意菜品状态
CREATE POLICY "order_items: admin update status"
  ON order_items FOR UPDATE
  TO authenticated
  USING ((SELECT is_admin FROM profiles WHERE id = auth.uid()) = TRUE);