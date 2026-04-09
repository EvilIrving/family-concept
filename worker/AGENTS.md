# Worker 目录规范

## 作用范围

本文件作用于 `worker/` 目录及其所有子目录。

## 目标

本目录专门承载 Cloudflare 侧代码与配置，包括 Workers、D1、R2、接口版本路由和本地开发脚本。
服务端接口统一使用 `/api/v1` 前缀，不在根路径直接暴露业务接口。

## 边界

本目录不放 iOS 客户端代码，不放 SwiftUI 视图，不放客户端持久化逻辑。
Cloudflare 相关资源绑定、数据库迁移、对象存储读写和 API 入口都放在本目录内维护。

## 技术约束

默认使用 TypeScript。
运行时以 Cloudflare Workers 标准为准，不依赖 Node.js 专属服务端框架。
配置通过 `wrangler` 管理，敏感信息使用 secret，不写死到源码。

## 目录建议

`src/` 放 Worker 入口与路由代码。
`migrations/` 放 D1 SQL 迁移。
`wrangler.jsonc` 作为本地与部署配置事实来源。

## 协作约束

当接口字段或路径调整时，需要同步更新 `docs/` 与调用方。
v1 接口字段语义保持兼容，新增能力优先通过新增字段或新增子路径实现。
