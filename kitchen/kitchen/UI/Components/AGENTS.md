# UI/Components — 可复用组件规范

## 概述

无业务依赖的可复用 UI 组件放在此目录。组件通过参数渲染，不直接访问 Store。遵循父目录所有约束。

## 当前组件

- `AppButton.swift`：主按钮、次按钮、ghost、危险按钮
- `AppCard.swift`：统一卡片容器
- `AppIconActionButton.swift`：小尺寸加减与图标动作按钮
- `AppTextField.swift`：原生输入行为 + 自定义外观与扩展命中区
- `FloatButton.swift`：悬浮按钮
- `MenuDishCard.swift`：菜单网格卡片

## 主题系统

组件统一消费 `Design/` 下拆分后的 token：

- 语义颜色：`AppSemanticColor`
- 组件态颜色：`AppComponentColor`
- 间距：`AppSpacing`
- 圆角：`AppRadius`
- 阴影：`AppShadow`
- 字体：`AppTypography`

需要直接映射资源色时只在 `AppPalette` 和 `AppSemanticColor` 层处理；组件侧优先消费 `AppComponentColor`。允许使用 token 组合具体样式；禁止绕开 token 直接定义新的全局视觉语言。

## 当前实现约束

### AppButton

- 最小高度 50pt
- 使用 `AppButtonStyle` 处理按下态透明度和轻微缩放
- `primary`、`secondary`、`ghost`、`destructive` 四种样式统一走同一实现

### AppCard

- 作为页面卡片、sheet 内容卡片和信息容器的统一底座
- 默认负责背景、圆角、阴影、内边距一致性

### AppTextField

- 底层使用系统 `TextField` / `SecureField`
- 支持 `.card` 与 `.inline` 两种 chrome
- `.card` 模式提供额外 focus 命中区，视觉框和点击区分离
- 校验态通过 `appValidationFeedback` 叠加

### MenuDishCard

- 支持图片 URL 或占位图
- 分类标签直接叠在头图区域
- 数量控制使用 `AppIconActionButton`

## 通用规则

- 组件只接收参数和回调，不直接读写业务状态
- 组件优先保留原生交互行为，样式通过包装层完成
- 新组件优先复用现有 token 和现有小组件
- 组件对外 API 追求小而稳定，避免把业务对象整包塞进组件

## 禁止事项

- 禁止在组件内直接访问 `AppStore`
- 禁止硬编码跨组件复用的颜色、间距、圆角、字体
- 禁止用系统默认 `Form` / `List` 外观直接承担产品界面主体

## 文档维护

- 如果本文件规则已经和代码、文档或实际流程不一致，修代码或修文档后顺手修正本文件。
- 保持 `AGENTS.md` 和 `CLAUDE.md` 内容一致。任何一方更新，另一方必须同步更新。
