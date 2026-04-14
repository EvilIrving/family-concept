# 私厨 App

私人厨房管理工具。一个 owner 拥有一个私厨，通过邀请码加入，支持菜品管理、点菜、订单协作与实时同步。

## 项目结构

```
swift-family-concept/
├── kitchen/        # iOS App（SwiftUI）
├── worker/         # Cloudflare Worker 后端
└── docs/           # 设计文档（事实源）
```

## 技术栈

| 层 | 技术 |
|---|---|
| iOS 客户端 | Swift 6 + SwiftUI，iOS 17.6+ |
| 后端运行时 | Cloudflare Workers（TypeScript） |
| 数据库 | Cloudflare D1（SQLite） |
| 对象存储 | Cloudflare R2（菜品图片） |
| 实时推送 | Cloudflare Durable Objects + WebSocket |

## 身份体系

无账号密码，无第三方登录。App 首次启动本地生成 `device_id`（UUID）作为稳定身份主键，后端基于此识别设备与角色。

## 角色权限

| 角色 | 说明 |
|---|---|
| `owner` | 唯一，全权控制私厨 |
| `admin` | 协作厨手，可管理菜品和订单状态 |
| `member` | 点菜方，只能追加菜品和查看 |

## 文档

- 设计总规格与业务规则：[`docs/family_v1_design.md`](docs/family_v1_design.md)
- 视觉主题规范：[`docs/ui_theme.md`](docs/ui_theme.md)
- iOS 开发规范：[`kitchen/CLAUDE.md`](kitchen/CLAUDE.md)
- 后端开发规范：[`worker/CLAUDE.md`](worker/CLAUDE.md)

## 快速开始

### iOS App

用 Xcode 打开 `kitchen/kitchen.xcodeproj`，选择模拟器运行即可。不需要额外配置，当前阶段使用内存种子数据。

### Worker 后端

```bash
cd worker
pnpm install

# 登录 Cloudflare
wrangler login

# 创建 D1 数据库（填返回的 database_id 到 wrangler.jsonc）
pnpm d1:create

# 创建 R2 bucket
pnpm r2:create

# 本地启动
pnpm dev

# 执行迁移（本地）
pnpm d1:migrate:local

# 执行迁移（线上）
pnpm d1:migrate:remote

# 部署
pnpm deploy
```

### 部署到 Cloudflare 正式环境

当前正式 API 域名为 `https://api.kitchen.onecat.dev`。

部署前准备：

- `onecat.dev` 已接入 Cloudflare
- `api.kitchen.onecat.dev` 交给 Worker 自定义域名路由
- `worker/wrangler.jsonc` 已包含 `routes` 配置、D1 `database_id`、R2 bucket 绑定

部署步骤：

```bash
cd worker
pnpm install
npx wrangler login

# 执行线上迁移
pnpm d1:migrate:remote

# 部署 Worker
pnpm deploy
```

部署完成后，验证以下地址：

- `https://api.kitchen.onecat.dev/api/v1/health`
- `https://api.kitchen.onecat.dev/api/v1/bootstrap`

两个接口都返回 JSON 后，iPhone 真机即可直接连接正式后端。

### 真机联调

iOS App 当前默认请求地址已经配置为：

- `https://api.kitchen.onecat.dev`

对应配置位置：

- `kitchen/kitchen/Info.plist`
- `kitchen/kitchen/Services/APIClient.swift`

真机测试时，先完成 Worker 部署，再运行 iPhone App。

## v1 明确不做

- 菜品规格选项
- 多 kitchen 归属
- 订单轮次管理
- Android / Web 端
- 邮箱密码 / 第三方登录
- 历史订单统计分析
