# kitchenTests — 单元测试规范

## 概述

Model 和 Store 的单元测试。测试代码使用 Swift Testing 框架，测试执行命令统一走 `xcodebuild`，禁止使用 `swift test`。

## 框架

```swift
import Testing
// 不使用 XCTest
```

## 测试覆盖要求

### 必须测试
- 所有 Model 的状态流转逻辑（枚举变化、computed property）
- 所有 Store 的业务方法（添加、删除、状态变更）
- 业务规则：如同时只有一个 open 订单、权限校验逻辑、采购清单聚合算法

### 不需要测试
- SwiftUI View（通过 Preview 覆盖）
- 纯数据容器（无逻辑的 struct）
- 网络请求（当前阶段使用种子数据，联调阶段视情况添加）

## 命名规范

```swift
@Test("当订单状态为 open 时，可以追加菜品")
func canAddItemToOpenOrder() { ... }

@Test("当订单状态为 finished 时，追加菜品应失败")
func cannotAddItemToFinishedOrder() { ... }
```

- 测试函数名：`camelCase`，动词开头，描述具体行为
- `@Test` 标注字符串用中文描述预期行为

## 测试结构

```swift
@Suite("OrderStore")
struct OrderStoreTests {
    @Test("新建订单默认状态为 open")
    func newOrderIsOpen() {
        let order = Order(...)
        #expect(order.status == .open)
    }
}
```

- 使用 `@Suite` 按 Store 或 Model 分组
- 每个测试只验证一个行为
- 使用 `#expect` 而非 `XCTAssert`

## 文件组织

- 每个 Store 对应一个测试文件：`AppStoreTests.swift`、`OrderStoreTests.swift`
- 共享测试辅助方法放在 `TestHelpers.swift`
- 不在测试文件中定义领域类型（从主 target import）
