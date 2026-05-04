# UI/Feedback — 反馈组件规范

## 概述

全局或局部交互反馈组件放在此目录。当前实现包含 toast、top banner、表单校验反馈和触觉反馈。遵循父目录所有约束。

## 当前文件

- `AppFeedbackState.swift`：反馈语义、默认触觉、展示位置和 loading phase 模型
- `AppFeedbackRouter.swift`：全局反馈路由，负责 toast / banner 展示选择和重复抑制
- `AppFeedbackHaptics.swift`：toast / banner 展示态触觉去重
- `AppToastModels.swift`：toast 与 banner 数据模型和视图
- `AppToastHost.swift`：全局 toast / banner 挂载层
- `AppShakeFeedback.swift`：输入校验的描边和 shake 动效
- `HapticManager.swift`：统一管理轻量触觉反馈事件

## Toast 与 Banner

### 当前实现

- 数据模型：`AppToastData` / `TopBannerData`
- 挂载方式：根视图使用 `appToastHost()`
- 位置：`AppFeedbackPlacement.topToast`、`AppFeedbackPlacement.centerToast`、`AppFeedbackPlacement.topBanner`
- 动画：toast 使用 spring，banner 使用 easeInOut
- 生命周期：toast 固定约 2.2 秒；banner 可自动消失或 persistent

### 使用规则

- `AppFeedbackSeverity` 只表达语义重要性、配色和默认触觉，不直接承担唯一位置决策
- 未显式设置位置时使用 `severity.defaultPlacement`：info / success 默认 top toast，warning / error 默认 top banner
- 调用方需要改变位置时优先传 `feedbackRouter.show(feedback, placement: ...)`
- `AppFeedbackPayload.placement` 可表达 payload 自身的默认位置，`show(..., placement:)` 的临时覆盖优先级更高
- 旧 Hint 类型仅作为兼容别名保留，新代码不要继续使用

## Router 返回值

- `AppFeedbackRouter.show(...)` 返回 `AppFeedbackPresentationResult`
- `.shown(UUID)` 表示已创建 toast 或 banner presentation
- `.ignoredDuplicate` 表示被短时间语义去重拦截
- `.blockedByActiveBanner` 表示 banner 互斥规则阻止了本次展示
- 返回值带 `@discardableResult`，普通调用可以忽略；调试、验证或未来排队逻辑应读取该结果

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

- `AppHapticIntent` 独立表达触觉意图（light / medium / heavy / selection / success / warning / error）
- `HapticManager.shared.fire(_:)` 是统一入口，内部按 intent 分发到对应 `UIFeedbackGenerator`
- `hapticsEnabled` 开关由 `HapticManager` 统一拦截，调用处无需再判断
- `AppButton` 的 automatic haptic 只发 selection 级即时点击确认，不表达业务结果
- success / warning / error 触觉由 toast / banner presentation 阶段触发，并由 `AppFeedbackPresentationHaptics` 按 presentation id 去重

### 使用规则

- `AppButton` 只负责按下态、加载态和即时点击确认，不负责表达业务结果
- 保存、删除、提交等异步结果反馈统一走 `AppFeedbackRouter`
- 构建 `AppFeedback` 时如需覆盖默认触觉，使用 `.low(..., haptic: .light)`；如需显式静音，可继续使用 `withHaptic`
- 直接调用 `HapticManager.shared.fire(...)` 只适合局部即时交互，不用于异步业务结果
- 页面局部轻提示继续优先用 toast，就地校验继续优先用描边和 shake

## 设计原则

- 反馈组件保持轻量，不引入重型协调器
- 页面级错误优先由 View 直接渲染文案或卡片区域提示
- 可恢复的轻量结果优先用 toast
- 表单错误优先就地展示，避免跳出式打断

## 文档维护

- 如果本文件规则已经和代码、文档或实际流程不一致，修代码或修文档后顺手修正本文件。
- 保持 `AGENTS.md` 和 `CLAUDE.md` 内容一致。任何一方更新，另一方必须同步更新。
