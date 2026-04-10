# 私厨 v1 设计稿

## 1. 文档目标

这份文档是私厨 App v1 的单一事实源。适用范围：

- 数据模型与边界定义
- 设备与最小身份体系
- 角色与权限模型
- 核心业务流程
- 后端 API 边界
- Phase 0–2 实施清单

## 2. v1 产品收敛

产品定位是「私人厨房管理工具」，不是外卖平台，不是公开点餐系统。

核心约束：

- 一个 owner 拥有一个私厨
- 外人无法自行注册进入，必须通过邀请码加入
- 菜品由 owner / admin 维护，量级约 50 道，支持归档
- 订单是一个可持续追加的活跃单据，不做批次/轮次管理
- 食材只做标签级，用于生成采购清单，不做克数计算

## 3. 技术栈

- 客户端：iOS only，SwiftUI 原生实现
- 身份：App 首次启动本地生成 `device_id`，作为稳定身份主键
- 后端：Cloudflare Workers（API 层）+ D1（关系数据）+ R2（菜品图片）+ Durable Objects（订单实时广播）
- 图片处理：iOS 客户端本地完成主体提取、去背景、主体检查与格式转换，只上传最终成品图
- 图片路径：R2 bucket 名 `dishes`，key 格式 `{kitchen_id}/{dish_id}.jpg`
- 权限判断：基于请求携带的 `device_id` 查成员角色，D1 无 RLS 能力
- 不做账号密码、邮箱验证码、Apple 登录、匿名访客、局域网模式

## 4. 设备与最小身份体系

- App 首次启动时本地生成 UUID 作为 `device_id`
- 客户端启动后用 `device_id` 和 `display_name` 请求后端，查找或创建设备记录
- v1 不做登录态，不签发 session，不做多设备合并
- 设备表只存最小字段，不做找回、绑定其他登录方式、设备迁移

## 5. 领域模型

### 5.1 枚举定义

- `kitchen_role`: `owner | admin | member`
  - `owner`：唯一，全权控制私厨
  - `admin`：厨房侧协作角色，可以是分工的厨手（例如专做咖啡），可管理菜品和订单状态
  - `member`：点菜方，只能追加菜品和查看
- `member_status`: `active | removed`
- `order_status`: `open | finished`
- `item_status`: `waiting | cooking | done | cancelled`

### 5.2 表结构（D1 SQLite 方言）

#### `devices`

用途：设备身份存储，跨 kitchen 共享。

字段：

- `id TEXT PRIMARY KEY` — UUID
- `device_id TEXT NOT NULL UNIQUE` — App 首次启动生成的 UUID
- `display_name TEXT NOT NULL`
- `created_at TEXT NOT NULL DEFAULT (datetime('now'))`

#### `kitchens`

用途：私厨根实体，每个 owner 拥有一个。

字段：

- `id TEXT PRIMARY KEY`
- `name TEXT NOT NULL`
- `owner_device_id TEXT NOT NULL REFERENCES devices(id)`
- `invite_code TEXT NOT NULL UNIQUE`
- `invite_code_rotated_at TEXT NOT NULL DEFAULT (datetime('now'))`
- `created_at TEXT NOT NULL DEFAULT (datetime('now'))`

#### `members`

用途：成员归属与角色映射。

字段：

- `id TEXT PRIMARY KEY`
- `kitchen_id TEXT NOT NULL REFERENCES kitchens(id) ON DELETE CASCADE`
- `device_ref_id TEXT NOT NULL REFERENCES devices(id) ON DELETE CASCADE`
- `role TEXT NOT NULL CHECK (role IN ('owner','admin','member'))`
- `status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','removed'))`
- `joined_at TEXT NOT NULL DEFAULT (datetime('now'))`
- `removed_at TEXT`
- `UNIQUE (kitchen_id, device_ref_id)`

#### `dishes`

用途：厨房菜单，由 owner/admin 维护。

字段：

- `id TEXT PRIMARY KEY`
- `kitchen_id TEXT NOT NULL REFERENCES kitchens(id) ON DELETE CASCADE`
- `name TEXT NOT NULL`
- `category TEXT NOT NULL`
- `image_key TEXT` — R2 key，格式 `{kitchen_id}/{dish_id}.jpg`
- `ingredients_json TEXT NOT NULL DEFAULT '[]'` — 字符串数组 JSON，如 `["青椒","姜","蒜"]`
- `created_by_device_id TEXT NOT NULL REFERENCES devices(id)`
- `created_at TEXT NOT NULL DEFAULT (datetime('now'))`
- `updated_at TEXT NOT NULL DEFAULT (datetime('now'))`
- `archived_at TEXT` — 软删除，不影响历史订单展示
- `UNIQUE (kitchen_id, name)`

#### `orders`

用途：厨房内活跃订单单据。

字段：

- `id TEXT PRIMARY KEY`
- `kitchen_id TEXT NOT NULL REFERENCES kitchens(id) ON DELETE RESTRICT`
- `status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','finished'))`
- `created_by_device_id TEXT NOT NULL REFERENCES devices(id)`
- `created_at TEXT NOT NULL DEFAULT (datetime('now'))`
- `finished_at TEXT`

约束：每个 kitchen 同时至多一个 `open` 订单，通过唯一部分索引实现：

```sql
CREATE UNIQUE INDEX orders_kitchen_open_unique
  ON orders (kitchen_id)
  WHERE status = 'open';
```

#### `order_items`

用途：订单中的菜品行项。

字段：

- `id TEXT PRIMARY KEY`
- `order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE`
- `dish_id TEXT NOT NULL REFERENCES dishes(id)`
- `added_by_device_id TEXT NOT NULL REFERENCES devices(id)`
- `quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0)`
- `status TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting','cooking','done','cancelled'))`
- `created_at TEXT NOT NULL DEFAULT (datetime('now'))`
- `updated_at TEXT NOT NULL DEFAULT (datetime('now'))`

不存 `selected_specs`（v1 不做规格），不存 `order_round`（不做轮次）。

### 5.3 ER 关系

```
devices ──< members >── kitchens ──< dishes
                                 └──< orders ──< order_items >── dishes
```

## 6. 关键业务规则

### 6.1 入驻流程

1. 首次启动 → 本地生成 `device_id`
2. App 入驻页统一调用单一入口接口，提交 `device_id`、`display_name` 以及当前模式所需字段
3. 若当前设备没有任何 `active` 的 `members` 记录，进入入驻页：
  - 先填写 `display_name`
  - 主路径：主输入框默认用于输入邀请码，模式为 `join`，提交 `device_id + display_name + invite_code` 加入已有 kitchen
  - 次路径：点击「创建我的私厨」后，不新增页面结构，只将主输入框从邀请码切换为 `kitchen name`，模式切为 `create`，提交 `device_id + display_name + kitchen_name` 创建私厨
4. 加入或创建成功后进入主界面

### 6.2 邀请加入

- owner / admin 可查看和刷新邀请码，刷新后旧码立即失效
- 用户输入邀请码即自动加入为 `member`，不 owner 审批
- owner 可踢除 admin / member；admin 可踢除 member；任何人不能踢 owner
- member / admin 可主动退出；owner 在 v1 不允许退出自己的 kitchen

### 6.3 订单生命周期

- 若当前 kitchen 已有 `open` 订单，直接追加菜品；否则可创建新订单
- 任何 `active` 成员（owner / admin / member）都可追加菜品到 open 订单
- owner / admin 可修改每个 `order_item.status`：`waiting → cooking → done / cancelled`
- owner / admin 可点「结束订单」将订单改为 `finished`
- 同一 kitchen 同时只存在一个 `open` 订单

### 6.4 食材采购清单

- 读取当前 open 订单的所有 order_items，关联各 dish 的 `ingredients_json`
- 对食材标签做去重聚合，输出清单：`[{ ingredient: "青椒", dish_count: 2 }, ...]`
- 不做克数/份数精算

### 6.5 菜品图片处理

- 用户选择菜品图片后，由 iOS 客户端本地完成主体提取、去背景、主体有效性检查与最终格式转换 Png
- 客户端只上传处理完成后的成品图，不上传原图，不保留服务端原图副本
- 上传成功后，客户端立即删除本地原图与处理中间文件
- 后端仅负责签发上传地址、保存 `image_key`，不承担图片后处理链路

## 7. 后端 API 边界

所有接口默认要求携带 `device_id`，Worker 先解析设备身份，再按成员角色判断是否允许操作。

```
POST   /onboarding/complete                 — 入驻统一入口 {mode, device_id, display_name, invite_code?|kitchen_name?}
POST   /devices/register                    — 注册设备 {device_id, display_name}
GET    /devices/by-device/:device_id        — 当前设备信息

POST   /kitchens                            — 创建 kitchen（成为 owner）
GET    /kitchens/:id                        — 获取 kitchen 信息
PATCH  /kitchens/:id                        — 改 kitchen 名称（owner 限定）
POST   /kitchens/:id/rotate_invite          — 刷新邀请码（owner/admin）
POST   /kitchens/join                       — 输入邀请码加入

GET    /kitchens/:id/members                — 成员列表
DELETE /kitchens/:id/members/:device_ref_id — 踢人
POST   /kitchens/:id/leave                  — 主动退出

GET    /kitchens/:id/dishes                 — 菜单列表
POST   /kitchens/:id/dishes                 — 新增菜品（owner/admin）
PATCH  /dishes/:id                          — 编辑菜品（owner/admin）
DELETE /dishes/:id                          — 归档菜品（owner/admin）
POST   /dishes/:id/image_upload_url         — 获取成品图的 R2 预签名上传 URL

GET    /kitchens/:id/orders/open            — 当前活跃订单，无则返回 null
POST   /kitchens/:id/orders                 — 创建新活跃订单
POST   /orders/:id/items                    — 追加菜品 {dish_id, quantity}
PATCH  /order_items/:id                     — 改状态或数量
POST   /orders/:id/finish                   — 结束订单（owner/admin）
GET    /orders/:id/shopping_list            — 采购清单

WS     /kitchens/:id/live                   — Durable Object 实时推送
```

## 8. 实时同步

- 每个 kitchen 对应一个 Durable Object 实例，按 `kitchen_id` 路由
- 订单追加菜品、item 状态变更、订单结束时，Worker 通知对应 DO 广播给所有连接客户端
- 客户端主要在「厨房视角」消费实时事件，展示最新状态无需手动刷新
- Cloudflare Workers + Durable Objects + WebSocket 实现实时同步

## 9. 权限矩阵


| 操作            | owner       | admin    | member |
| ------------- | ----------- | -------- | ------ |
| 菜品 CRUD       | 允许          | 允许       | 只读     |
| 邀请码刷新         | 允许          | 允许       | 禁止     |
| 任命 / 撤销 admin | 允许          | 禁止       | 禁止     |
| 踢人            | 允许（含 admin） | 仅 member | 禁止     |
| 改 kitchen 名   | 允许          | 禁止       | 禁止     |
| 创建订单 / 追加菜品   | 允许          | 允许       | 允许     |
| 改 item 状态     | 允许          | 允许       | 禁止     |
| 结束订单          | 允许          | 允许       | 禁止     |
| 查看采购清单        | 允许          | 允许       | 允许     |
| 退出 kitchen    | 禁止          | 允许       | 允许     |


## 10. Phase 实施清单

### Phase 0 — 设计收敛

目标：冻结数据模型与 API 边界，产出可执行的后端方案。

交付物：本文档 + D1 Schema SQL 草稿

任务：

- 确认 ER 图与字段命名
- 产出 `database.sql`（D1 SQLite 方言）
- 产出 D1 seed 脚本

### Phase 1 — 后端基础设施

目标：Cloudflare 上建立可运行的私厨数据底座。

任务：

- 初始化 Workers 项目，绑定 D1 / R2 / Durable Objects
- 实现 `device_id` 注册与设备查找逻辑
- 执行 `database.sql` 建表
- 实现核心 API（device、kitchen、member、dish、order、order_items）
- 实现 Durable Object 广播逻辑
- 验证基于成员角色的写接口判断

### Phase 2 — iOS 最小闭环

目标：iOS 客户端跑通完整主路径。

任务：

- 新建 SwiftUI 工程，首启生成并持久化 `device_id`
- 实现入驻页（邀请码 / 创建私厨）
- 实现菜单页（查看 / 添加菜品）
- 实现点菜流程（追加到订单）
- 实现厨房视角（实时更新 item 状态）
- 实现采购清单展示

## 11. v1 明确不做

- 菜品规格选项（specs）
- 多 kitchen 归属（一个设备归属多个私厨）
- 订单批次 / 轮次管理
- 订单分享链接给外部人
- 匿名访客 / 局域网模式
- owner 转让 / kitchen 解散自助流程
- Android / Web 端
- 邮箱密码 / 第三方登录
- 历史订单统计分析
- 菜品克数级食材配方
