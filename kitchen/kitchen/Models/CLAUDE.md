# Models — 领域模型规范

## 概述

所有领域模型定义在此目录。模型是纯 Swift `struct`，无副作用，无网络调用，无 UI 依赖。遵循父目录所有约束。

## 文件组织

- `Domain.swift`：所有核心领域 struct 和 enum（当前集中单文件，量级小时无需拆分）
- 若某个模型扩展超过 100 行，拆到 `ModelName+Extensions.swift`

## 枚举定义

```swift
enum KitchenRole: String, Codable {
    case owner, admin, member
}

enum MemberStatus: String, Codable {
    case active, removed
}

enum OrderStatus: String, Codable {
    case open, finished
}

enum ItemStatus: String, Codable {
    case waiting, cooking, done, cancelled
}
```

## 核心领域模型

### Account
```swift
struct Account: Identifiable, Codable {
    let id: String
    let userName: String
    let nickName: String
    let createdAt: String
}
```

### Kitchen
```swift
struct Kitchen: Identifiable, Codable {
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
struct Member: Identifiable, Codable {
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
struct Dish: Identifiable, Codable {
    let id: String
    let kitchenId: String
    let name: String
    let category: String
    let imageKey: String?        // R2 key: {kitchen_id}/{dish_id}.jpg
    let ingredientsJson: String  // JSON string array: ["青椒","姜"]
    let createdByAccountId: String
    let createdAt: String
    let updatedAt: String
    let archivedAt: String?      // nil = 未归档
}
```

### Order
```swift
struct Order: Identifiable, Codable {
    let id: String
    let kitchenId: String
    let status: OrderStatus
    let createdByAccountId: String
    let createdAt: String
    let finishedAt: String?
}
```

### OrderItem
```swift
struct OrderItem: Identifiable, Codable {
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

### ShoppingListItem（本地聚合，非持久化）
```swift
struct ShoppingListItem {
    let ingredient: String
    let dishCount: Int
}
```

## Auth 响应模型

```swift
struct AuthResponse: Codable {
    let token: String
    let account: Account
}

struct AuthMeResponse: Codable {
    let account: Account
}
```

## ER 关系

```
accounts ──< members >── kitchens ──< dishes
                                  └──< orders ──< order_items >── dishes
```

## 状态流转

- `OrderStatus`: `open` → `finished`（不可逆）
- `ItemStatus`: `waiting` → `cooking` → `done` 或 `cancelled`（owner/admin 操作）
- `MemberStatus`: `active` → `removed`（不可自助恢复，需重新加入）

## 模型规则

- 所有模型实现 `Identifiable`、`Codable`
- 时间字段统一用 `String`（ISO 8601），不用 `Date`（避免时区转换复杂性）
- `archivedAt == nil` 表示菜品有效，`!= nil` 表示已归档（软删除）
- `ingredientsJson` 在客户端解码为 `[String]` 使用，模型层保留原始字符串
- v1 不做菜品规格（specs），不做订单轮次（order_round）
