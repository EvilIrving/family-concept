# UI/Components — 可复用组件规范

## 概述

无业务依赖的可复用 UI 组件。所有组件通过参数配置，不直接访问 Store 或全局状态。遵循父目录所有约束。

## 主题系统（AppTheme）

所有组件必须通过 AppTheme 消费 token，不允许硬编码视觉值。

### 颜色 Token（AppColor）

**Brand（绿色体系）**
- `green900`: `#1F4D3A` — 主按钮按下态
- `green800`: `#2D6A4F` — 主按钮填充、success 语义色
- `green700`: `#3F8A67` — 强调元素
- `green500`: `#78B798` — 中性绿
- `green300`: `#BFE3CF` — 选中描边、弱高亮
- `green200`: `#DCEFE3` — 页面局部高光容器
- `green100`: `#EEF7F1` — 次按钮底色、选中弱底

**Neutral**
- `backgroundBase`: `#F4F8F5` — 页面背景
- `backgroundElevated`: `#FAFCFA` — 略高层背景
- `surfacePrimary`: `#FFFFFF` — 卡片、sheet 背景
- `surfaceSecondary`: `#F7FAF7`
- `surfaceTertiary`: `#F1F5F1`
- `lineSoft`: `#E3EBE4` — 弱分割线
- `lineStrong`: `#D2DDD4` — 强分割线

**Text**
- `textPrimary`: `#1E2A22`
- `textSecondary`: `#5F6F64`
- `textTertiary`: `#8A968E`
- `textOnBrand`: `#FFFFFF`

**Semantic**
- `success` / `successSoft`: `#2D6A4F` / `#E7F4EC`
- `warning` / `warningSoft`: `#C98A2E` / `#FAF0DE`
- `danger` / `dangerSoft`: `#D85C4A` / `#FCE9E6`
- `info` / `infoSoft`: `#5F8F7A` / `#EAF4EF`

### 间距（AppSpacing）
- `space4 = 4`, `space8 = 8`, `space12 = 12`, `space16 = 16`
- `space20 = 20`, `space24 = 24`, `space32 = 32`
- 行内小间距用 `8`，卡片内部用 `16`，弹层内容区用 `20`，模块间用 `24` 或 `32`

### 圆角（AppRadius）
- `radius12 = 12`, `radius16 = 16`, `radius20 = 20`
- `radius24 = 24`, `radius28 = 28`, `radiusPill = 999`
- 输入框：`16`，卡片：`20`，大弹层/sheet：`24-28`，胶囊按钮：`Pill`

### 阴影（AppShadow）
- `shadowCard`: y=6, blur=18, color=`rgba(31,77,58,0.08)`
- `shadowSheet`: y=12, blur=28, color=`rgba(31,77,58,0.12)`
- 禁止黑色重阴影、超大模糊、多层高对比投影

### 字体（AppTypography）
- `pageTitle`: 28 / semibold
- `sectionTitle`: 20 / semibold
- `cardTitle`: 17 / semibold
- `body`: 15 / regular
- `bodyStrong`: 15 / semibold
- `caption`: 13 / regular
- `micro`: 12 / medium
- `buttonLabel`: 16 / semibold

## 组件目录

### AppButton
- 主按钮：实体绿底（`green800`）+ 白字，圆角 `16` 或 Pill
- 按下态：降低亮度 + 轻微缩放（`.scaleEffect(0.97)`），不做弹跳
- 次按钮：浅绿底（`green100`）或白底加浅描边
- 危险按钮：浅红底（`dangerSoft`）+ 红字（`danger`），不用大面积高饱和红
- 触控高度 >= 44pt

### AppCard
- 背景：`surfacePrimary`（白色）
- 圆角：`radius20`
- 阴影：`shadowCard`
- 内边距：`space16`
- 内部分区用垂直间距和标题权重，不用粗线框

### AppListSection
- 不强依赖系统 `List` 默认外观
- 使用 `ScrollView + LazyVStack` 结构，卡片化 section
- 行高 >= 44pt
- 行尾控件（箭头、开关、数量）对齐统一

## 禁止事项

- 禁止在组件内硬编码颜色、间距、圆角、阴影数值
- 禁止在组件内访问 Store 或全局环境
- 禁止使用系统默认 `Form`、`List`、`DatePicker` 外观直接上线
- 禁止米杏色/暖棕色作为全局主色
- 禁止重拟物、强玻璃拟态、复杂自定义转场
