# kitchen — iOS App 项目规范

## 概述

私厨 App 的 iOS 客户端，SwiftUI 原生实现，iOS only。本文件覆盖整个 `kitchen/` Xcode 项目的开发约束，子目录的 CLAUDE.md 只写局部规则，不重复本文件内容。


## 技术栈

- 语言：Swift 6，严格并发模式
- UI 框架：SwiftUI，不引入 UIKit 除非 SwiftUI 能力明确不足
- 状态管理：`@Observable` / `ObservableObject` Store，不使用 Redux、TCA 等外部架构
- 持久化：当前为内存 + 种子数据，方向为 SwiftData；不使用 Core Data，不用 UserDefaults 存储领域数据
- 最低部署目标：iOS 17.6

## 目录职责

```
kitchen/
├── kitchen/          # App 源码（Models、Stores、Views、UI）
├── kitchenTests/     # 测试目录
└── kitchenUITests/   # 测试目录
```

## 命名规范

- 类型（struct、class、enum、protocol）：`PascalCase`
- 属性、方法、变量：`camelCase`
- 文件名：与主类型名一致，`PascalCase`（如 `AppStore.swift`、`Domain.swift`）
- 常量：`camelCase`，不用 `k` 前缀
- Bool 属性：以 `is`、`has`、`can`、`should` 开头
- 枚举 case：`camelCase`（Swift 惯例）
- 用户可见字符串：中文，直接硬编码，不使用本地化文件
- 注释：允许中文

## Swift 代码风格

### 类型选择

- 优先 `struct` 而非 `class`；Store 用 `class` + `@Observable` / `ObservableObject`
- 禁止用 `class` 表示数据模型，领域模型统一 `struct`
- 遵循 Swift 标准库风格，不引入 Objective-C 遗留风格

### 访问控制

- 能 `private` 的都 `private`
- Store 对外状态用 `private(set)` 或只读计算属性
- 禁止全局变量，Store 通过环境注入（`.environmentObject` / `.environment`）

### 函数

- 函数体不超过 40 行，超出拆分
- 单一职责：一个函数只做一件事
- 异步操作用 `async/await`，禁止回调闭包
- 错误处理用 `throws` + `do/catch`

### 可选值

- 禁止 `!` 强制解包（仅 `Bundle.main` 等 API 契约保证的场景除外）
- 优先 `guard let` 提前返回，不嵌套 `if let`
- 禁止 `try!`，禁止 `as!`

### SwiftUI View

- View struct 只负责布局和状态绑定，不写业务逻辑
- body 超过 50 行时，拆分为私有子 struct 或 `@ViewBuilder` 方法
- 不在 View 内直接散写颜色、字号、圆角、阴影——必须通过 `AppTheme` token
- Preview 必须可正常编译展示，不允许空 Preview

### 文件拆分原则

- 一个文件一个主类型，相关扩展可同文件
- 超过 200 行的 View 必须拆分
- 有明显区块（header / list / footer）时，各区块抽为独立私有 struct
- 扩展文件命名：`TypeName+FeatureName.swift`

## 触控与布局约束

- 触控目标 >= 44pt（与 iOS skill 一致）
- 主要操作放在拇指区（屏幕下半部分）
- 间距遵循 8pt 倍数网格：8、12、16、20、24、32
- 支持所有屏幕尺寸（iPhone SE 375pt 到 Pro Max 430pt）
- 内容在 safe area 内，背景图可 `.ignoresSafeArea()`

## 交互设计约束

- 从任意 Tab 根页出发，导航深度不超过 2 层
- 破坏性操作（删除）：滑动删除 + undo toast，不弹确认框
- 所有表单填写通过 sheet，不 push 新页面
- 单字段修改（数量、名称等）内联编辑，不开 sheet
- 加载状态：skeleton / shimmer，禁止阻塞式 spinner modal
- 错误提示：内联 banner 或 toast，禁止阻塞弹窗
- 动效：只用 SwiftUI 默认转场（淡入淡出、位移、尺寸变化），不自定义复杂动效
- 支持 Reduce Motion（`@Environment(\.accessibilityReduceMotion)`）

## 质量要求

- 业务逻辑和 UI 都需要配套测试代码
- View 不强制单测，但必须能正常编译和 Preview
- 执行 iOS `build`、`test`、运行或安装时，默认目标设备为真机 `“xujinghui”的 iPhone`，`destination id=00008150-0019546A2100401C`
- 除非用户明确要求 simulator，否则不要默认选择 `iphonesimulator`、`simulatorId` 或任何模拟器目标
- 如工具支持显式目标参数，优先传 `platform=iOS` 与上述 `deviceId`，避免回退到 simulator
 

## 禁止事项

- 禁止 `print()` 调试（用 `#if DEBUG` 包裹或删除）
- 禁止注释掉的代码留在提交中
- 禁止空的 `catch {}` 块
- 禁止 `DispatchQueue.main.async` 替代 `@MainActor`
- 禁止 `NotificationCenter` 替代 Store 状态传递
- 禁止汉堡菜单 / Drawer 导航模式
- 禁止颜色唯一的信息表达（需同时配图标或文字）
