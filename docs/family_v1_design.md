# Family v1 设计稿

## 1. 文档目标

这份文档用于把当前多家庭方案收敛成可执行规格，作为 Phase 0-2 的单一事实源。

适用范围：

- 数据模型与租户边界
- 角色与权限模型
- 注册后 onboarding 流程
- 访客加入订单与生命周期
- RLS 设计原则与矩阵
- Phase 0-2 实施清单
- README 改写提纲

本文优先保证 v1 可落地，不追求一次性覆盖未来全部扩展。

## 2. v1 收敛决策

### 2.1 已冻结决策

- 新用户必须先归属一个家庭后才能进入主应用。
- 业务权限采用家庭级角色，不再使用全局管理员承载业务授权。
- `profiles.is_admin` 如保留，仅表示平台运维角色，不参与家庭业务权限判断。
- 菜品管理权限仅授予 `family_owner` 和 `family_admin`。
- 访客是订单级临时参与者，不自动成为家庭成员。
- 访客在订单结束后默认失去该订单访问入口，不保留历史访问能力。
- 家庭邀请码支持刷新，刷新后旧码失效。
- 用户退出家庭或被移出家庭后，历史记录保留，但失去该家庭后续访问权限。
- 家庭自助解散不纳入 v1，只允许平台侧人工处理。

### 2.2 核心抽象

从：

`User -> Order -> Dish`

改为：

`User -> Family -> Order -> OrderItem -> Dish`

### 2.3 三条基础原则

- `Family` 是租户边界，菜单、订单、成员都从属于家庭。
- 业务权限属于家庭成员关系，不属于全局用户。
- 访客不是家庭成员，只是订单级临时参与者。

## 3. 领域模型

### 3.1 枚举定义

- `family_role`: `owner | admin | member`
- `family_member_status`: `active | removed`
- `order_status`: `ordering | placed | finished`
- `item_status`: `waiting | cooking | done`
- `order_member_type`: `family_member | guest`

### 3.2 表结构

#### `profiles`

用途：用户基础档案，跨家庭共享，但不承载业务权限。

字段：

- `id uuid primary key references auth.users(id) on delete cascade`
- `username text not null unique`
- `avatar_url text null`
- `is_admin boolean not null default false`
- `created_at timestamptz not null default now()`

约束与规则：

- `username` 全局唯一。
- `is_admin` 仅用于平台运维，不用于 UI 菜品管理、订单管理、成员管理授权。

#### `families`

用途：租户根实体。

字段：

- `id uuid primary key default gen_random_uuid()`
- `name text not null`
- `created_by uuid not null references profiles(id)`
- `join_code text not null unique`
- `join_code_rotated_at timestamptz not null default now()`
- `created_at timestamptz not null default now()`
- `archived_at timestamptz null`

约束与规则：

- `join_code` 用于已登录用户加入家庭。
- `archived_at` 仅供平台侧保留扩展，不在 v1 暴露自助归档入口。

#### `family_members`

用途：家庭成员与业务角色映射。

字段：

- `id uuid primary key default gen_random_uuid()`
- `family_id uuid not null references families(id) on delete cascade`
- `user_id uuid not null references profiles(id) on delete cascade`
- `role family_role not null`
- `status family_member_status not null default 'active'`
- `joined_at timestamptz not null default now()`
- `removed_at timestamptz null`
- `invited_by uuid null references profiles(id)`

约束与规则：

- `unique (family_id, user_id)`
- v1 默认一个用户可加入多个家庭，但首次进入主应用时必须至少归属一个家庭。
- 只有 `status = 'active'` 的成员拥有家庭访问权。

#### `dishes`

用途：家庭级菜单。

字段：

- `id uuid primary key default gen_random_uuid()`
- `family_id uuid not null references families(id) on delete cascade`
- `name text not null`
- `category text not null`
- `image_url text null`
- `ingredients jsonb not null default '[]'`
- `created_by uuid not null references profiles(id)`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`
- `archived_at timestamptz null`

约束与规则：

- `unique (family_id, name)`
- 分类仍然由 `category` 动态聚合，不单独建分类表。
- 删除优先考虑软删除或归档，避免影响历史订单展示。

#### `orders`

用途：家庭内协作订单。

字段：

- `id uuid primary key default gen_random_uuid()`
- `family_id uuid not null references families(id) on delete restrict`
- `status order_status not null default 'ordering'`
- `share_token text not null unique`
- `created_by uuid not null references profiles(id)`
- `current_round int not null default 1`
- `created_at timestamptz not null default now()`
- `placed_at timestamptz null`
- `finished_at timestamptz null`

约束与规则：

- 创建订单者必须是该家庭的活跃成员。
- `share_token` 用于加入订单，不等同于 `join_code`。
- v1 保留“同一用户同一时间只能在一个活跃订单中”的全局约束。

#### `order_members`

用途：订单参与者列表，兼容家庭成员与访客。

字段：

- `id uuid primary key default gen_random_uuid()`
- `order_id uuid not null references orders(id) on delete cascade`
- `user_id uuid null references profiles(id)`
- `member_type order_member_type not null`
- `display_name text null`
- `joined_at timestamptz not null default now()`

约束与规则：

- 家庭成员加入订单时：`member_type = 'family_member'`，`user_id` 必填。
- 访客加入订单时：`member_type = 'guest'`，`display_name` 必填，`user_id` 可空。
- 建议增加检查约束：
  - `family_member` 必须满足 `user_id is not null`
  - `guest` 必须满足 `display_name is not null`
- 唯一性建议：
  - `unique (order_id, user_id)` where `user_id is not null`
- 访客不进入 `profiles` / `family_members`。

#### `order_items`

用途：订单中的菜品项。

字段：

- `id uuid primary key default gen_random_uuid()`
- `order_id uuid not null references orders(id) on delete cascade`
- `dish_id uuid not null references dishes(id)`
- `added_by_member_id uuid null references order_members(id)`
- `quantity int not null default 1 check (quantity > 0)`
- `status item_status not null default 'waiting'`
- `order_round int not null default 1`
- `created_at timestamptz not null default now()`

约束与规则：

- 不直接存 `family_id`，通过 `orders.family_id` 归属家庭。
- `dish_id` 必须属于该订单所在家庭。
- `added_by_member_id` 指向 `order_members`，这样可同时支持家庭成员和访客加菜。

## 4. 关键业务规则

### 4.1 注册与入家

- 用户注册成功后，必须先完成以下二选一：
  - 创建家庭
  - 输入邀请码加入家庭
- 未归属任何家庭的登录用户，不进入主应用壳层。
- 首次完成 onboarding 后，设置默认当前家庭。

### 4.2 家庭权限

- `owner`
  - 管理家庭成员
  - 提升或降级 `admin`
  - 刷新家庭邀请码
  - 管理菜品
  - 创建和管理订单
- `admin`
  - 管理普通成员
  - 刷新家庭邀请码
  - 管理菜品
  - 创建和管理订单
- `member`
  - 读取家庭菜单与订单
  - 参与下单
  - 查看家庭内自己有权限查看的信息

### 4.3 访客模型

- 访客通过订单分享链接加入，不通过家庭邀请码加入。
- v1 允许访客不注册直接加入订单。
- 访客只存在于 `order_members`，不进入 `profiles` 和 `family_members`。
- 订单结束后，访客默认失去访问入口。
- 家庭成员可查看历史订单；访客不可查看历史订单。

### 4.4 活跃订单约束

- 同一已登录用户同一时间只能参与一个 `status != 'finished'` 的订单。
- 该规则对 `order_members.user_id is not null` 生效。
- 该约束必须通过 trigger 或 RPC 保证，不应在不可执行 partial index 中表达。

## 5. 建议的数据库函数 / RPC

以下能力不建议完全依赖裸表写入，应通过 RPC 统一承载校验与原子性。

### 5.1 `create_family_with_owner(name text)`

职责：

- 创建 `families`
- 生成 `join_code`
- 为当前用户创建 `family_members(role = 'owner')`
- 返回新家庭与成员关系

### 5.2 `join_family_by_code(code text)`

职责：

- 校验邀请码有效性
- 校验当前用户未在该家庭中处于 `active`
- 写入或恢复 `family_members`
- 返回加入结果

### 5.3 `rotate_family_join_code(family_id uuid)`

职责：

- 校验当前用户为该家庭 `owner/admin`
- 生成并替换新 `join_code`
- 更新 `join_code_rotated_at`

### 5.4 `create_order_for_family(family_id uuid)`

职责：

- 校验当前用户为该家庭活跃成员
- 校验当前用户没有其他活跃订单
- 创建 `orders`
- 自动把当前用户加入 `order_members`

### 5.5 `join_order_by_share_token(token text, display_name text default null)`

职责：

- 校验订单存在且未结束
- 对登录用户：
  - 校验其没有其他活跃订单
  - 若属于订单家庭，则以 `family_member` 加入
  - 若不属于订单家庭，则拒绝或按产品策略决定是否允许外部账号访客身份加入
- 对未登录访客：
  - 创建 `guest` 类型 `order_members`
  - 要求 `display_name`

v1 建议收敛为：

- 家庭成员使用登录身份加入订单
- 非家庭用户以匿名访客加入订单
- 不支持“外部账号用户以长期账号身份跨家庭挂靠订单”

## 6. RLS 设计原则

### 6.1 总原则

- 不再允许 `read all` 这类全局读策略。
- 所有业务表默认按家庭边界或订单参与关系授权。
- 访客加入订单优先走 RPC，不开放宽松裸表 `insert policy`。
- “能否读” 与 “能否写” 分开设计，避免因为方便 UI 展示而扩大写权限。

### 6.2 访问辅助判断

建议在 SQL 层提供可复用 helper function，例如：

- `is_platform_admin()`
- `is_active_family_member(family_id uuid)`
- `family_role_of(family_id uuid)`
- `is_family_admin(family_id uuid)`
- `is_order_participant(order_id uuid)`
- `is_active_order_member(order_id uuid, order_member_id uuid)`

## 7. RLS 策略矩阵

| 表 | SELECT | INSERT | UPDATE | DELETE | 备注 |
|---|---|---|---|---|---|
| `profiles` | 自己；同家庭活跃成员的基础信息 | 注册/初始化档案时由本人或受控流程创建 | 仅本人可更新基础字段；`is_admin` 仅平台侧 | 不开放 | 禁止全局读取全部用户 |
| `families` | 仅活跃成员可读 | 通过 `create_family_with_owner()` | 不开放裸表更新，名称编辑与邀请码刷新走 RPC | 不开放 | v1 不支持自助解散 |
| `family_members` | 同家庭活跃成员可读 | 通过 `create_family_with_owner()` / `join_family_by_code()` | `owner/admin` 可改成员角色与状态；本人可主动退出家庭 | 不开放硬删 | 历史优先保留，使用 `status/removed_at` |
| `dishes` | 仅家庭活跃成员可读 | 仅 `owner/admin` | 仅 `owner/admin` | 仅 `owner/admin` | 建议优先归档，不直接硬删 |
| `orders` | 家庭活跃成员可读；访客仅可通过受控流程读取自己参与的活跃订单上下文 | 仅家庭活跃成员，通过 `create_order_for_family()` | 仅家庭 `owner/admin` 可更新状态；部分字段走 RPC | 不开放 | 订单历史对家庭成员保留 |
| `order_members` | 家庭活跃成员可读本家庭订单成员；访客仅可读取自身必要上下文 | 通过 `create_order_for_family()` / `join_order_by_share_token()` | 不开放裸表更新；访客名修改如需要走 RPC | 不开放 | 不做开放式 insert policy |
| `order_items` | 家庭活跃成员可读；访客可读自己参与订单中的菜品列表 | 家庭成员和访客均通过受控规则添加 | 家庭 `owner/admin` 可改 `status`；发起人可在 `ordering` 删除/调整自己菜品 | 发起人仅在 `ordering` 可删自己条目；管理员可按策略处理 | 写入前需校验 `dish` 属于同一家族 |

### 7.1 v1 的务实实现建议

如果匿名访客 RLS 成本过高，v1 可以进一步收敛：

- 访客加入订单接口走 Edge Function 或 RPC
- 访客端只消费最小化订单视图
- Flutter v1 先优先完成“家庭成员 + 受控匿名访客”闭环，不追求复杂访客编辑权限

## 8. Onboarding 流程

### 8.1 注册后流程

1. 用户注册
2. 创建 `profiles`
3. 查询当前用户活跃家庭数
4. 若为 0，进入 onboarding
5. 用户二选一：
   - 创建家庭
   - 输入邀请码加入家庭
6. 写入家庭关系
7. 设置默认当前家庭
8. 进入主应用

### 8.2 登录后流程

- 有默认家庭：直接进入主应用
- 无默认家庭但有家庭关系：进入家庭选择页
- 无家庭关系：进入 onboarding

## 9. Phase 0-2 实施清单

## Phase 0 - Tenant Foundation

目标：冻结多租户规则，产出可执行后端设计。

交付物：

- 本文档
- Family 版 ER 图
- `docs/rls_matrix.md` 或本文附录化矩阵
- 可执行 `database.sql` 草案

任务清单：

- 确认家庭级角色模型与字段命名
- 确认访客生命周期与订单结束后的可见性
- 确认家庭邀请码与订单分享链接是两套机制
- 确认活跃订单唯一约束的触发器实现
- 移除不可执行 partial index
- 定义 RPC 列表与职责边界

验收标准：

- 数据模型、权限、访客规则没有未决 open item
- SQL 草案不包含已知不可执行 DDL
- RLS 策略能映射到每张表

## Phase 1 - Backend Foundation

目标：在 Supabase 建立可执行的多家庭数据底座。

任务清单：

- 创建枚举：`family_role`、`family_member_status`、`order_status`、`item_status`、`order_member_type`
- 创建表：`profiles`、`families`、`family_members`、`dishes`、`orders`、`order_members`、`order_items`
- 建立关键约束与索引
- 实现活跃订单唯一约束 trigger
- 实现 helper functions
- 实现核心 RPC
- 启用并验证 RLS
- 配置 Storage bucket
- 开启需要的 Realtime 表

验收标准：

- `database.sql` 可直接执行成功
- 家庭成员只能访问本家庭数据
- 非家庭成员无法读取他人家庭菜单与订单
- 关键 RPC 能覆盖建家、入家、建单、入单路径

## Phase 2 - Auth & Onboarding

目标：完成“注册/登录/入家”闭环，而不是只完成账号登录。

任务清单：

- 注册页：`username + password`
- 登录页
- 注册后创建 `profiles`
- `auth_provider` 持久化登录状态
- onboarding 页：
  - 创建家庭
  - 输入邀请码加入家庭
- 当前家庭上下文 provider
- 首次入家成功后进入主应用壳层

验收标准：

- 可注册、登录、登出
- 未入家的用户不会进入主应用
- 可创建家庭并成为 `owner`
- 可通过邀请码加入家庭
- 家庭上下文可被后续菜单页与订单页复用

## 10. README 改写提纲

README 不再直接承担完整设计稿，建议改为产品说明 + 开发入口，并把 Family 方案链接到独立文档。

### 10.1 需要重写的章节

#### `二、核心抽象`

改为：

- `User -> Family -> Order -> OrderItem -> Dish`
- 明确 `Family` 是租户边界

#### `三、用户与角色`

改为两层角色：

- 平台角色：`profiles.is_admin`，仅平台运维使用
- 家庭角色：`family_members.role = owner | admin | member`

同时删除或改写：

- “管理员是全局角色，不限定于某个订单”
- “管理员可管理所有用户、菜品、订单”

#### `四、页面结构`

新增或改写：

- onboarding / create family / join family 页面
- setting 页中的成员管理改为“家庭成员管理”

#### `五、订单机制`

补充：

- 订单从属于家庭
- 分享链接用于加入订单，不用于加入家庭
- 家庭邀请码用于加入家庭，不用于加入订单

#### `八、菜品管理`

补充：

- 菜品是家庭级资源
- 仅家庭 `owner/admin` 可管理

#### `开发顺序`

重排为：

- `Phase 0 — Tenant Foundation`
- `Phase 1 — Backend Foundation`
- `Phase 2 — Auth & Onboarding`

#### `Phase 1-2 详细操作指南`

必须改写：

- 不再要求直接执行旧版 `database.sql`
- 改为执行 Family 版可执行 SQL
- 明确验收需要验证家庭隔离与 onboarding

### 10.2 建议新增的 README 链接

- `docs/family_v1_design.md`
- `docs/rls_matrix.md`
- `docs/onboarding_flow.md`

## 11. 对现有仓库文件的直接影响

### `database.sql`

必须重写，不应在当前文件基础上小修。

原因：

- 表结构缺少 `families` / `family_members`
- 现有 RLS 以全局读写为主
- 包含不可执行 partial index
- 无法承载访客订单模型

### `datamodel.dart`

必须重写为 Family 版数据契约，至少补齐：

- `Family`
- `FamilyMember`
- `family_role`
- `family_member_status`
- `order_member_type`
- `OrderMember.display_name`
- `OrderItem.added_by_member_id`

### `README.md`

必须从单租户 PRD 改成多家庭 v1 PRD，并把细节设计下沉到 `docs/`。

## 12. v1 范围外事项

以下能力明确不纳入本轮：

- 家庭自助解散
- 跨家庭聚合视图
- 复杂邀请审批流
- 多角色审计日志
- 访客订单结束后历史回看
- 外部账号用户跨家庭长期挂靠订单

## 13. 下一步建议

按顺序执行：

1. 以本文为准，先重写 `datamodel.dart`
2. 基于本文重写可执行 `database.sql`
3. 补 `docs/rls_matrix.md`
4. 再改 `README.md`
5. 然后进入 Flutter Phase 1-2 实现
