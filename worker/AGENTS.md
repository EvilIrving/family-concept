# worker — Cloudflare Worker 后端规范

## 概述

私厨 App 的后端服务，运行于 Cloudflare Workers。提供 REST API、D1 数据持久化、R2 图片存储和 Durable Objects 实时广播。

## 技术栈

- 运行时：Cloudflare Workers（Edge Runtime）
- 语言：TypeScript，严格模式（`strict: true`）
- 数据库：Cloudflare D1（SQLite 方言）
- 对象存储：Cloudflare R2，bucket 名 `dishes`
- 实时推送：Cloudflare Durable Objects + WebSocket
- 包管理：pnpm
- 配置：`wrangler.jsonc`
- 入口：`src/index.ts`

## 代码风格

- 函数命名：`camelCase`，动词开头（`createKitchen`、`getMembers`）
- 类型/接口：`PascalCase`
- 文件命名：`kebab-case`（如 `kitchen-routes.ts`、`auth-middleware.ts`）
- 不使用 `any`，所有类型明确声明
- 优先 `async/await`，禁止裸 Promise 链
- 每个路由处理函数不超过 50 行，超出拆分到 service 层

## 目录结构约定

```
src/
├── index.ts          # 路由注册入口
├── middleware/        # 身份解析、角色校验中间件
├── routes/           # 按资源分文件（kitchen.ts, dishes.ts, orders.ts...）
├── services/         # 业务逻辑（与路由层解耦）
├── db/               # D1 查询封装
└── types.ts          # 共享类型定义
```

## 身份与鉴权

- 所有业务接口默认要求请求携带 `Authorization: Bearer <token>`
- Worker 先解析 session token → 查 `sessions` 表获取当前登录账号
- 再查 `members` 表获取该账号在目标 kitchen 中的角色
- 权限判断基于角色，D1 无 RLS 能力，必须在 Worker 层手动校验
- 账号登录字段为 `user_name + password`
- token 只在服务端以 `token_hash` 形式存储
- v1 使用 session token，不使用 JWT、OAuth

## 权限矩阵

| 操作              | owner       | admin     | member |
|-----------------|-------------|-----------|--------|
| 菜品 CRUD          | 允许          | 允许        | 只读     |
| 邀请码刷新           | 允许          | 允许        | 禁止     |
| 任命/撤销 admin      | 允许          | 禁止        | 禁止     |
| 踢人              | 允许（含 admin） | 仅 member  | 禁止     |
| 改 kitchen 名      | 允许          | 禁止        | 禁止     |
| 创建订单/追加菜品       | 允许          | 允许        | 允许     |
| 改 item 状态        | 允许          | 允许        | 禁止     |
| 结束订单            | 允许          | 允许        | 禁止     |
| 查看采购清单          | 允许          | 允许        | 允许     |
| 退出 kitchen       | 禁止          | 允许        | 允许     |

## API 接口列表

```
POST   /auth/register                       — 注册账号 {user_name, password, nick_name}
POST   /auth/login                          — 登录 {user_name, password}
POST   /auth/logout                         — 登出当前 session
GET    /auth/me                             — 当前账号信息

POST   /onboarding/complete                 — 入驻统一入口 {mode, nick_name?, invite_code?|kitchen_name?}

POST   /kitchens                            — 创建 kitchen（成为 owner）
GET    /kitchens/:id                        — 获取 kitchen 信息
PATCH  /kitchens/:id                        — 改 kitchen 名称（owner 限定）
POST   /kitchens/:id/rotate_invite          — 刷新邀请码（owner/admin）
POST   /kitchens/join                       — 输入邀请码加入

GET    /kitchens/:id/members                — 成员列表
DELETE /kitchens/:id/members/:account_id    — 踢人
POST   /kitchens/:id/leave                  — 主动退出

GET    /kitchens/:id/dishes                 — 菜单列表（不含已归档）
POST   /kitchens/:id/dishes                 — 新增菜品（owner/admin）
PATCH  /dishes/:id                          — 编辑菜品（owner/admin）
DELETE /dishes/:id                          — 归档菜品（owner/admin，软删除）
POST   /dishes/:id/image_upload_url         — 获取 R2 预签名上传 URL

GET    /kitchens/:id/orders/open            — 当前活跃订单，无则返回 null
POST   /kitchens/:id/orders                 — 创建新活跃订单
POST   /orders/:id/items                    — 追加菜品 {dish_id, quantity}
PATCH  /order_items/:id                     — 改状态或数量
POST   /orders/:id/finish                   — 结束订单（owner/admin）
GET    /orders/:id/shopping_list            — 采购清单

WS     /kitchens/:id/live                   — Durable Object 实时推送
```

## 数据库表结构（D1 SQLite）

### accounts
- `id TEXT PRIMARY KEY`
- `user_name TEXT NOT NULL UNIQUE`
- `password_hash TEXT NOT NULL`
- `nick_name TEXT NOT NULL`
- `created_at TEXT NOT NULL DEFAULT (datetime('now'))`

### sessions
- `id TEXT PRIMARY KEY`
- `account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE`
- `token_hash TEXT NOT NULL UNIQUE`
- `expires_at TEXT NOT NULL`
- `created_at TEXT NOT NULL DEFAULT (datetime('now'))`

### kitchens
- `id TEXT PRIMARY KEY`
- `name TEXT NOT NULL`
- `owner_account_id TEXT NOT NULL REFERENCES accounts(id)`
- `invite_code TEXT NOT NULL UNIQUE`
- `invite_code_rotated_at TEXT NOT NULL DEFAULT (datetime('now'))`
- `created_at TEXT NOT NULL DEFAULT (datetime('now'))`

### members
- `id TEXT PRIMARY KEY`
- `kitchen_id TEXT NOT NULL REFERENCES kitchens(id) ON DELETE CASCADE`
- `account_id TEXT NOT NULL REFERENCES accounts(id) ON DELETE CASCADE`
- `role TEXT NOT NULL CHECK (role IN ('owner','admin','member'))`
- `status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','removed'))`
- `joined_at TEXT NOT NULL DEFAULT (datetime('now'))`
- `removed_at TEXT`
- `UNIQUE (kitchen_id, account_id)`

### dishes
- `id TEXT PRIMARY KEY`
- `kitchen_id TEXT NOT NULL REFERENCES kitchens(id) ON DELETE CASCADE`
- `name TEXT NOT NULL`
- `category TEXT NOT NULL`
- `image_key TEXT` — R2 key，格式 `{kitchen_id}/{dish_id}.jpg`
- `ingredients_json TEXT NOT NULL DEFAULT '[]'`
- `created_by_account_id TEXT NOT NULL REFERENCES accounts(id)`
- `created_at TEXT NOT NULL DEFAULT (datetime('now'))`
- `updated_at TEXT NOT NULL DEFAULT (datetime('now'))`
- `archived_at TEXT` — 软删除
- `UNIQUE (kitchen_id, name)`

### orders
- `id TEXT PRIMARY KEY`
- `kitchen_id TEXT NOT NULL REFERENCES kitchens(id) ON DELETE RESTRICT`
- `status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','finished'))`
- `created_by_account_id TEXT NOT NULL REFERENCES accounts(id)`
- `created_at TEXT NOT NULL DEFAULT (datetime('now'))`
- `finished_at TEXT`
- 唯一索引：每个 kitchen 同时至多一个 `open` 订单

### order_items
- `id TEXT PRIMARY KEY`
- `order_id TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE`
- `dish_id TEXT NOT NULL REFERENCES dishes(id)`
- `added_by_account_id TEXT NOT NULL REFERENCES accounts(id)`
- `quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0)`
- `status TEXT NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting','cooking','done','cancelled'))`
- `created_at TEXT NOT NULL DEFAULT (datetime('now'))`
- `updated_at TEXT NOT NULL DEFAULT (datetime('now'))`

## 实时推送

- 每个 kitchen 对应一个 Durable Object 实例，按 `kitchen_id` 路由
- 触发广播的事件：追加菜品、item 状态变更、订单结束
- 客户端连接：`WS /kitchens/:id/live`

## 图片处理约定

- 客户端本地完成主体提取、去背景、格式转换（PNG），只上传成品图
- Worker 只负责签发 R2 预签名上传 URL 和保存 `image_key`
- R2 key 格式：`{kitchen_id}/{dish_id}.jpg`

## 迁移规范

- 迁移文件在 `migrations/` 目录，按序号命名（`0001_init.sql`）
- 只允许向前迁移，不写回滚脚本
- 新字段必须有默认值或允许 NULL，确保迁移不破坏已有数据
- 已存在对象的迁移要优先使用幂等写法（如 `IF NOT EXISTS`），避免远端库和本地状态不一致时卡住 migration 链

## 禁止事项

- 禁止在 Worker 层直接拼接 SQL 字符串（用参数化查询）
- 禁止把 `account_id` 或 session token 当做信任凭证跳过角色校验
- 禁止在接口响应里返回 `password_hash` 或 `token_hash`
- 禁止在接口层写业务逻辑（应在 service 层）
- v1 明确不做：菜品规格、多 kitchen 归属、订单轮次、外部分享、Android/Web
