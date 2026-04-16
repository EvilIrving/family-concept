# UI/Feedback — 反馈组件规范

## 概述

全局或局部交互反馈组件放在此目录。当前实现包含 toast、表单校验反馈和触觉反馈。遵循父目录所有约束。

## 当前文件

- `AppToast.swift`：通过 `ViewModifier` 在页面底部叠加 toast
- `AppShakeFeedback.swift`：输入校验的描边和 shake 动效
- `HapticManager.swift`：统一管理轻量触觉反馈事件

## Toast

### 当前实现

- 数据模型：`AppToastData`
- 挂载方式：`view.appToast($toast)`
- 位置：底部 overlay
- 样式：深绿色 capsule，左侧成功图标，可选单个 action
- 动画：底部位移 + 渐隐渐现
- 生命周期：基于 `.task(id:)` 自动消失，当前默认约 2.2 秒

### 使用规则

- 适合轻量成功提示和单步可撤销动作
- toast 状态可以是页面局部 `@State`
- 新 toast 直接替换旧 toast

## 校验反馈

### 当前实现

- `AppShakeEffect` 使用 `GeometryEffect` 做横向抖动
- `AppValidationFeedbackModifier` 叠加描边和 shake
- 默认描边色在正常态为 `border`，非法态为 `danger`

### 使用规则

- 输入框校验失败时通过 `validationTrigger` 驱动重复动画
- 反馈层只负责视觉提示，具体校验逻辑放在 View 或表单状态机

## 触觉反馈

### 当前实现

- `HapticManager.shared` 统一封装成功、错误、状态推进、新菜加入等反馈事件
- 当前由 `AppStore` 在订单状态流转、刷新失败和新菜加入时触发
- 触觉开关通过本地偏好控制，页面只表达交互意图

### 使用规则

- 触觉反馈适合确认关键动作完成或提示状态变化
- 业务层只触发语义事件，具体 `UIFeedbackGenerator` 细节留在 `HapticManager`
- 页面局部轻提示继续优先用 toast，就地校验继续优先用描边和 shake

## 设计原则

- 反馈组件保持轻量，不侵入业务逻辑
- 页面级错误优先由 View 直接渲染文案或卡片区域提示
- 可恢复的轻量结果优先用 toast
- 表单错误优先就地展示，避免跳出式打断

## 文档维护

- 如果本文件规则已经和代码、文档或实际流程不一致，修代码或修文档后顺手修正本文件。
- 保持 `AGENTS.md` 和 `CLAUDE.md` 内容一致。任何一方更新，另一方必须同步更新。
