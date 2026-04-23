# kitchenUITests — UI 测试规范

## 概述

关键用户流程的 UI 测试。测试覆盖入驻流程和核心点菜流程。遵循父目录所有约束。

## 框架

使用 Swift Testing + XCUIApplication（UI 测试必须用 XCUITest 能力，但测试组织用 Swift Testing）。测试执行命令统一走 `xcodebuild`，禁止使用 `swift test`。

## 覆盖范围

### 必须覆盖
- 入驻流程：首次启动 → 展示入驻页 → 输入邀请码加入 → 进入主界面
- 入驻流程：首次启动 → 点击「创建我的私厨」→ 输入厨房名 → 进入主界面
- 点菜流程：在菜单页选择菜品 → 追加到订单 → 订单页显示新 item

### 不覆盖
- 所有 Store / Model 逻辑（已由 kitchenTests 覆盖）
- 视觉细节（颜色、间距）
- 网络请求（使用 stub 或种子数据）

## 规范

- 测试使用页面语义标识符（`.accessibilityIdentifier`），不依赖视图层级或坐标
- 每个测试流程独立，不依赖其他测试的状态
- 测试前重置 App 状态（清除 `device_id`）
