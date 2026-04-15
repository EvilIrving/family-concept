# Stores — 状态管理规范

## 概述

全局状态存储层，使用 `ObservableObject` + `@Published`（或 `@Observable`）。Store 是唯一允许发起网络请求和管理副作用的地方。遵循父目录所有约束。

## 现有 Store

### AppStore (`AppStore.swift`)
全局单例，在 `kitchenApp.swift` 创建并注入。负责：
- `authToken` 的读取与持久化（UserDefaults，仅此一处允许）
- 当前登录账号信息（`currentAccount: Account?`）
- 当前所在 Kitchen 信息（`kitchen: Kitchen?`）
- 当前成员角色（`currentRole: KitchenRole?`）
- 启动恢复流程（`bootstrap()`：验证 token → 恢复 lastKitchenID）
- 顶层导航状态（`isBootstrapping`、`hasKitchen`、`isAuthenticated`）
- 认证操作：`login()`、`register()`、`signOut()`、`clearSession()`

## Store 设计规范

### 命名
- Store 类名以 `Store` 结尾（`AppStore`、`OrderStore`、`DishStore`）
- 方法名动词开头：`fetchDishes()`、`addItem(_:)`、`finishOrder()`

### 状态暴露
- 对外状态用 `@Published private(set) var` 或只读计算属性
- 不直接暴露可变集合让外部修改，提供明确的操作方法

### 异步与错误
- 所有网络操作用 `async/await`，标注 `@MainActor` 确保 UI 更新在主线程
- 错误状态通过 `@Published var error: String?` 暴露，View 通过 banner/toast 展示
- 不在 Store 内弹 alert 或操控 UI

### 职责边界
- 每个 Store 只管理一个资源域（dishes / orders / members）
- Store 之间如需共享状态，通过 `AppStore` 传递，不直接持有彼此引用
- 不在 Store 中写 SwiftUI View 代码

## 种子数据

当前阶段（Phase 1-2）使用内存种子数据，无真实网络请求：
- 种子数据在 Store 初始化时填充
- 种子数据定义在 Store 内部或单独的 `Seeds.swift` 文件
- 联调后端后逐步替换为真实 API 调用，种子数据文件删除

## 实时同步

- `OrderStore` 负责维护 WebSocket 连接（`WS /kitchens/:id/live`）
- 收到事件后直接更新 `@Published` 状态，触发 View 刷新
- 连接管理（建立、断开、重连）封装在 Store 内部，不暴露给 View
