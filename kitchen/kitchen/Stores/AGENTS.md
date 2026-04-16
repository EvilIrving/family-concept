# Stores — 状态管理规范

## 概述

全局状态存储层使用 `ObservableObject` + `@Published`。Store 负责副作用、网络、持久化和资源聚合。遵循父目录所有约束。

## 当前 Store

### AppStore (`AppStore.swift`)

当前目录只有一个顶层 Store，由 `kitchenApp.swift` 创建并注入全局。它同时承担认证、私厨上下文、菜品、订单、购物车和采购清单状态。

### 已管理状态

- 账号与鉴权：`currentAccount`、`authToken`、`storedNickName`
- 私厨上下文：`kitchen`、`members`、`currentRole`
- 菜品：`dishes`、`activeDishes`、`dishCategories`
- 订单：`currentOrder`、`orderItems`
- 购物车：`cartItems`、`cartCount`
- 采购清单：`shoppingListItems`
- 页面级状态：`isLoading`、`isBootstrapping`、`error`

### 已提供动作

- 启动恢复：`bootstrap()`、`fetchAll()`、`refreshOrderItems()`
- 认证：`login()`、`register()`、`signOut()`、`clearSession()`
- 入驻：`joinKitchen()`、`createKitchen()`
- 私厨管理：`updateKitchenName()`、`rotateInviteCode()`、`leaveKitchen()`
- 成员管理：`removeMember(accountID:)`
- 菜品管理：`addDish()`、`uploadDishImage()`、`archiveDish(id:)`
- 购物车：`addToCart()`、`updateCartQuantity()`、`removeFromCart()`、`clearCart()`、`submitCart()`
- 订单流转：`cycleStatus(for:)`、`cycleStatuses(for:)`、`finishOrder()`、`fetchShoppingList()`

## 设计规范

### 状态暴露

- 对外暴露 `@Published` 状态和只读计算属性
- 业务动作统一收口到 Store 方法，View 不直接改共享状态
- UserDefaults 读写集中在 Store 内部

### 异步与错误

- 网络请求统一使用 `async/await`
- `AppStore` 标注 `@MainActor`，保证 UI 状态更新留在主线程
- 页面错误通过 `error` 暴露给 View 渲染
- 认证失效优先走 `clearSession()`

### 职责边界

- View 负责局部输入、sheet/router、焦点和过渡状态
- Store 负责业务动作、接口调用、跨页面共享状态
- 服务层细节下沉到 `Services/APIClient.swift` 及相关服务对象
- 当前项目规模允许 `AppStore` 聚合多个资源域；新资源域复杂度继续增长时再拆分独立 Store

## 当前实现特征

- `fetchAll()` 并行拉取成员、菜品和开放订单
- `bootstrap()` 成功恢复账号后只恢复 kitchen 上下文，完整数据由 `ContentView.task(id:)` 二次触发
- 购物车仍是本地瞬时状态，提交成功后清空
- 采购清单由当前开放订单和菜品配料实时聚合，不单独持久化

## 文档维护

- 如果本文件规则已经和代码、文档或实际流程不一致，修代码或修文档后顺手修正本文件。
- 保持 `AGENTS.md` 和 `CLAUDE.md` 内容一致。任何一方更新，另一方必须同步更新。
