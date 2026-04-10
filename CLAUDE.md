# 项目 AI Agent 使用规范

## 作用范围

本文件作用于仓库根目录及所有未被更近层级 `AGENTS.md` 或 `CLAUDE.md` 覆盖的子目录。

进入某个子目录工作时，优先遵循离目标文件最近的 `AGENTS.md`；若该目录同时存在 `CLAUDE.md`，两者内容必须保持一致。

## 文档同步要求

`docs/` 是与代码实时对齐的事实来源。

`README.md` 是产品说明，用于对用户解释产品。

`AGENTS.md` 与 `CLAUDE.md` 是给 AI Agent 看的规范文件，任何目录下都必须保持内容一致。

## 目录化规范

推荐每个承担独立职责的目录都维护自己的 `AGENTS.md` 与 `CLAUDE.md`，只写该目录的目标、边界、约束和与相邻目录的协作方式。

子目录规范只补充局部规则，不重复改写根目录的通用规则；若发生冲突，以更近目录的规范为准。

## 交互设计

操作像现实一样直接。反馈几乎是瞬时的。出错可以轻松恢复。整个过程连续无阻。

具体约束：

- 从任意 tab 根页面出发，导航深度不超过 2 层。
- 破坏性操作（删除、撤销）使用滑动删除 + undo toast，不弹确认框。
- 所有表单填写通过 sheet 呈现，不使用 push 页面。
- 单字段修改（数量、名称等）使用内联编辑，不开 sheet。
- 加载状态使用 skeleton/shimmer，不使用阻塞式 spinner modal。
- 错误提示通过内联 banner 或 toast 呈现，不使用阻塞弹窗。
- 状态变化使用 SwiftUI 默认过渡动画，不自定义复杂动效。
- 少一些 page，可以多使用 sheet 方式填写信息。

## 数据层

- 全局状态通过 `Stores/` 目录下的 `ObservableObject` Store 管理
- 当前为内存数据 + 种子数据（`seedDemoData()`），持久化方向为 SwiftData
- 领域模型统一放在 `Models/`，Store 放在 `Stores/`
- 不使用 Core Data，不使用 UserDefaults 存储领域数据

## 命名规范

- 代码标识符：英文，类型 PascalCase，属性/方法 camelCase
- 文件名：PascalCase，与主类型名一致（如 `AppStore.swift`、`Domain.swift`）
- 用户可见字符串：中文，当前直接硬编码，不使用本地化文件
- 注释与文档：允许中文
- Xcode target/project 名称：小写（`kitchen`）

## 质量要求

- 新增 Model / Store 代码必须在 `kitchenTests/` 中配套单元测试，使用 Swift Testing 框架
- View 不强制单元测试，但必须能正常编译和 Preview
- 提交前运行以下命令验证构建：

  ```
  xcodebuild -scheme kitchen -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' build
  ```

- `kitchenUITests/` 中的 UI 测试针对关键流程（入驻、下单）逐步补充
