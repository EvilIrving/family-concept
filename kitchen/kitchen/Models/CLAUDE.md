# Models — 领域模型规范

## 概述

所有领域模型定义在此目录。模型保持纯数据和轻量派生逻辑，不发起网络请求，不依赖 SwiftUI 视图。遵循父目录所有约束。

## 当前文件

- `Domain.swift`：账号、私厨、成员、菜品、订单、购物车、认证响应等核心模型
- `DishDraftImageState.swift`：新增菜品流程里的图片状态机
- `DishImageSpec.swift`：菜品图片处理规格

## 核心模型

### Account
```swift
struct Account: Identifiable, Codable, Equatable {
    let id: String
    let userName: String
    let nickName: String
    let createdAt: String
}
```

### Kitchen
```swift
struct Kitchen: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let ownerAccountId: String
    let inviteCode: String
    let inviteCodeRotatedAt: String
    let createdAt: String
}
```

### Member
```swift
struct Member: Identifiable, Codable, Equatable {
    let id: String
    let kitchenId: String
    let accountId: String
    let role: KitchenRole
    let status: MemberStatus
    let joinedAt: String
    let removedAt: String?
    let nickName: String
}
```

### Dish
```swift
struct Dish: Identifiable, Codable, Equatable {
    let id: String
    let kitchenId: String
    let name: String
    let category: String
    let imageKey: String?
    let ingredientsJson: String
    let createdByAccountId: String
    let createdAt: String
    let updatedAt: String
    let archivedAt: String?
}
```

### Order / OrderItem
```swift
struct Order: Identifiable, Codable, Equatable {
    let id: String
    let kitchenId: String
    let status: OrderStatus
    let createdByAccountId: String
    let createdAt: String
    let finishedAt: String?
}

struct OrderItem: Identifiable, Codable, Equatable {
    let id: String
    let orderId: String
    let dishId: String
    let addedByAccountId: String
    let quantity: Int
    let status: ItemStatus
    let createdAt: String
    let updatedAt: String
}
```

### 本地专用模型

- `CartItem`：购物车本地状态，不走后端持久化
- `ShoppingListItem`：按当前订单聚合后的采购项，`id` 复用 `ingredient`
- `AuthResponse` / `AuthMeResponse`：认证接口响应

## 模型规则

- 所有服务端模型实现 `Codable`
- 需要列表渲染或 diff 的模型实现 `Identifiable`
- 需要本地比较的模型实现 `Equatable`
- 时间字段统一使用 `String`，由服务端负责格式一致性
- 允许轻量计算属性，例如 `Dish.ingredients`、`Dish.isArchived`、`KitchenRole.title`
- 允许自定义 `Codable` 兼容后端可选字段，例如 `Member.nickName`
- 模型层保留图片 key、JSON 字符串等原始数据，派生结果通过计算属性暴露

## 状态流转

- `OrderStatus`：`open` → `finished`
- `ItemStatus`：`waiting` → `cooking` → `done`，取消项为 `cancelled`
- `MemberStatus`：`active` / `removed`

## 文档维护

- 如果本文件规则已经和代码、文档或实际流程不一致，修代码或修文档后顺手修正本文件。
- 保持 `AGENTS.md` 和 `CLAUDE.md` 内容一致。任何一方更新，另一方必须同步更新。
