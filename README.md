# 私厨「食单」

家庭场景的私厨协作应用：菜单与菜品维护、点餐购物车、单笔开放订单流转、采购清单汇总、邀请码组队、成员与权限，以及与后端的 REST + WebSocket 实时同步。**无 Android / Web 客户端**。

---

## 仓库结构

```
swift-family-concept/
├── kitchen/               # Xcode 工程与 iOS SwiftUI 源码（主 target：kitchen/kitchen/）
├── worker/                # Cloudflare Worker（REST、D1、R2、Durable Objects）
├── docs/                  # 上架文案、图标生成 Prompt、产品与文案备忘（非代码事实源的备忘合集）
├── batch-import-dishes/   # 离线批量导入菜品脚本（可选；调用现有菜品创建接口）
└── THEME.md               # Kitchen 语义色与设计基调说明（与代码内 Design Token 对齐）
```

---

## 技术栈一览

| 层 | 技术 |
|---|---|
| iOS | Swift 6 · SwiftUI · 最低部署 **iOS 17.6**（参见 [`kitchen/CLAUDE.md`](kitchen/CLAUDE.md)） |
| 后端运行时 | Cloudflare Workers（TypeScript，`worker/src/index.ts`） |
| 数据库 | Cloudflare **D1**（SQLite）；迁移在 `worker/migrations/` |
| 图片存储 | Cloudflare **R2**；公开访问基址见 `kitchen/kitchen/Info.plist` 中的 `R2PublicBaseURL` |
| 实时 | **Durable Object**：`GET /api/v1/kitchens/:id/live`（WebSocket 升级） |
| IAP | StoreKit ↔ `POST /api/v1/kitchens/:id/iap/sync`（参见 [`worker/CLAUDE.md`](worker/CLAUDE.md) 路由表；实现见 `worker/src/routes/iap.ts`） |

---

## 账号与权限（与实现对齐）

- **注册 / 登录**：用户名 + 口令（`POST /api/v1/auth/register`、`POST /api/v1/auth/login`）；服务端签发 **Bearer session**，客户端写入 **UserDefaults**（`authToken` 等），恢复逻辑见 `kitchen/kitchen/Stores/AppStore.swift`。
- **不做** OAuth / 第三方 SSO；亦非「仅用 device id 无账号」模型。
- **Kitchen 角色**（简述）：

| 角色 | 摘要 |
|---|---|
| `owner` | 房主；名称修改、高危成员治理等特权 |
| `admin` | 协作管理：菜品 CRUD、订单推进、刷新邀请码等 |
| `member` | 参与点菜 / 阅览；条目状态改写等受限 |

细则与完整 API 仍以 **[`worker/CLAUDE.md`](worker/CLAUDE.md)**（及同源 `worker/AGENTS.md`）为准。

---

## 文档索引（仓库内现存）

| 主题 | 路径 |
|---|---|
| iOS 规范 | [`kitchen/CLAUDE.md`](kitchen/CLAUDE.md) |
| Worker 规范与路由 | [`worker/CLAUDE.md`](worker/CLAUDE.md) |
| App Store Connect 可复制字段（中英） | [`docs/app-store-submission.zh.md`](docs/app-store-submission.zh.md) · [`docs/app-store-submission.en.md`](docs/app-store-submission.en.md) |
| 上架与设计工具备忘 | [`docs/app-store-tools-and-links.md`](docs/app-store-tools-and-links.md) |
| 产品与交互想法备忘录 | [`docs/product-ideas-notes.zh.md`](docs/product-ideas-notes.zh.md) |
| UI 英文文案原则 | [`docs/ui-copywriting-principles.en.md`](docs/ui-copywriting-principles.en.md) |
| Kitchen 小图标分批生成文稿 | [`docs/kitchen-icon-batch-prompts.zh.md`](docs/kitchen-icon-batch-prompts.zh.md) |
| 1024 master 图标生成 Prompt（英文模板） | [`docs/app-icon-master-prompt.md`](docs/app-icon-master-prompt.md) |
| Claude Code 内置提醒快照存档 | [`docs/claude-code-system-reminder-snapshot.md`](docs/claude-code-system-reminder-snapshot.md) |
| 配色叙事 / token 说明 | [`THEME.md`](THEME.md) |
| 批量导入菜品脚本 | [`batch-import-dishes/README.md`](batch-import-dishes/README.md) |

---

## 快速开始

### iOS

1. 用 Xcode 打开 **`kitchen/kitchen.xcodeproj`**。
2. 默认 API：**`kitchen/kitchen/Info.plist` → `APIBaseURL`**，当前示例为 `https://api.kitchen.onecat.dev`；联调本地 Worker 时改为 `wrangler dev` 的根 URL。
3. 请求编排见 **`kitchen/kitchen/Services/APIClient.swift`**；业务路由统一带 **`/api/v1`** 前缀，与 **`worker/src/index.ts`** 中注册一致。
4. `NSAppTransportSecurity` 已启用 **本地网络**，便于访问局域网后端。

### Worker

```bash
cd worker
pnpm install

# 首次绑定 Cloudflare 账号
npx wrangler login

pnpm dev                    # wrangler dev
pnpm d1:migrate:local      # D1：本地迁移
pnpm d1:migrate:remote     # D1：远程迁移（部署前按需）
pnpm deploy                 # wrangler deploy
```

初次自建资源时仍可配合 `package.json` 中的 `d1:create` / `r2:create`（见 **`worker/wrangler.jsonc`** 中的绑定命名）。

---

## 环境与线上地址

| 用途 | 说明 |
|---|---|
| 默认 API 域名 | **`api.kitchen.onecat.dev`**（`worker/wrangler.jsonc` 的 `routes`） |
| 健康检查 | `GET https://api.kitchen.onecat.dev/api/v1/health` |
| 自检（DB） | `GET https://api.kitchen.onecat.dev/api/v1/bootstrap` |

两处均返回 JSON 即表示网关与 Worker 路由可用。

---

## 批量导入

见 **[`batch-import-dishes/README.md`](batch-import-dishes/README.md)**。不要将含口令的 `config.local.json` 提交到 Git；请从 `config.local.example.json` 复制。

---

## v1 不做 / 延后（与后端 README 对齐）

包括但不限于：菜品规格 SKU、账号同时归属多套 Kitchen、订单轮次、外部分享、Android / Web 客户端、OAuth 联邦登录。**以后端 `CLAUDE` 中的禁令段为准**，产品侧备忘见 **`docs/product-ideas-notes.zh.md`**。

---

## Agent 上架技能

自动生成 App Store Connect 字段草稿的规则见 **[`.agents/skills/appstore-submission/SKILL.md`](.agents/skills/appstore-submission/SKILL.md)**；生成的 Markdown **输出路径**为该技能所列的 **`docs/`** 下中英文件。
