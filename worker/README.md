# worker — Cloudflare Worker 后端

私厨 App 的后端服务，运行于 Cloudflare Workers。详细规范见 [`CLAUDE.md`](CLAUDE.md)。

## 技术栈

- 运行时：Cloudflare Workers（Edge Runtime）
- 语言：TypeScript，严格模式
- 数据库：Cloudflare D1（SQLite 方言）
- 对象存储：Cloudflare R2，bucket 名 `dishes`
- 实时推送：Cloudflare Durable Objects + WebSocket

## 快速开始

```bash
pnpm install

# 登录 Cloudflare
wrangler login

# 创建 D1 数据库，把返回的 database_id 填入 wrangler.jsonc
pnpm d1:create

# 创建 R2 bucket
pnpm r2:create

# 本地启动
pnpm dev
```

## 常用命令

| 命令 | 说明 |
|---|---|
| `pnpm dev` | 本地启动 Worker |
| `pnpm deploy` | 部署到 Cloudflare |
| `pnpm d1:migrate:local` | 执行 D1 迁移（本地） |
| `pnpm d1:migrate:remote` | 执行 D1 迁移（线上） |
| `pnpm d1:create` | 创建 D1 数据库 |
| `pnpm r2:create` | 创建 R2 bucket |

## 迁移文件

迁移文件在 `migrations/` 目录，按序号命名（`0001_init.sql`）。只允许向前迁移。
