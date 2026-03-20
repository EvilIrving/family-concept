# 绿色主题系统

## 1. 文档目标

这份文档用于冻结当前 App 的全局视觉配色方向，作为 Flutter `ThemeData`、`ColorScheme`、组件样式和页面实现的颜色依据。

本方案明确采用 `design/Orders.svg`、`design/Setting.svg`、`design/order_history.svg`、`design/shopping_list_sheet.svg` 的绿色系设计语言，不采用 `design/Menu.svg` 的暖棕主视觉作为全局主题。

## 2. 主题方向

关键词：

- 清爽
- 自然
- 家庭厨房感
- 功能清晰

设计原则：

- 绿色承担主交互色和主要状态表达。
- 暖橘只作为提醒和食欲感点缀，不作为全局主色。
- 页面底色保持浅绿白，避免纯白过硬。
- 卡片、弹层、表单以高可读性为优先。

## 3. 核心颜色

### 3.1 Brand / Primary

- `primary`: `#2D6A4F`
- `primaryLight`: `#40916C`
- `primaryAccent`: `#52B788`
- `primarySoft`: `#95D5B2`
- `primaryContainer`: `#D8F3DC`

用途：

- 主按钮
- 选中态
- 导航高亮
- 关键数据强调
- 成功态基础色

### 3.2 Background / Surface

- `background`: `#F4F9F6`
- `surface`: `#FFFFFF`
- `surfaceSoft`: `#E9F5EC`
- `surfaceMuted`: `#F8FAF9`

用途：

- 页面背景使用 `background`
- 卡片、弹窗、表单容器使用 `surface`
- 轻标签、弱选中、分组底使用 `surfaceSoft`
- 清单项和次级块面可使用 `surfaceMuted`

### 3.3 Text

- `textPrimary`: `#1B4332`
- `textSecondary`: `#6C757D`
- `textOnPrimary`: `#FFFFFF`

用途：

- 主标题、正文重点使用 `textPrimary`
- 辅助信息、说明文字使用 `textSecondary`
- 深色按钮与深色头部上的文字使用 `textOnPrimary`

### 3.4 Accent / Semantic Support

- `warning`: `#F4A261`
- `warningSoft`: `#FEF3E2`
- `danger`: `#EF5350`
- `dangerSoft`: `#FFEBEE`

用途：

- `warning` 用于进行中、提醒、需关注状态
- `danger` 用于退出登录、删除、移除成员等危险操作

## 4. 状态色规范

订单和菜品状态建议统一如下：

### 4.1 订单状态

- `ordering`
  - bg: `#FEF3E2`
  - fg: `#E76F51`
- `placed`
  - bg: `#E9F5EC`
  - fg: `#40916C`
- `finished`
  - bg: `#D8F3DC`
  - fg: `#2D6A4F`

### 4.2 菜品项状态

- `waiting`
  - bg: `#E9F5EC`
  - fg: `#40916C`
  - dot: `#95D5B2`
- `cooking`
  - bg: `#FEF3E2`
  - fg: `#E76F51`
  - dot: `#F4A261`
- `done`
  - bg: `#D8F3DC`
  - fg: `#2D6A4F`
  - dot: `#2D6A4F`

## 5. 组件配色规则

### 5.1 App Bar / Header

- 主页面头部可使用绿色渐变：
  - start: `#2D6A4F`
  - end: `#52B788`
- 头部文字与图标使用白色
- 头部下方承接页面背景时，可保留浅曲线或柔和过渡

### 5.2 Button

主按钮：

- bg: `#2D6A4F` 或 `#2D6A4F -> #52B788`
- fg: `#FFFFFF`

次按钮：

- bg: `#E9F5EC`
- fg: `#2D6A4F`

危险按钮：

- bg: `#FFEBEE`
- fg: `#EF5350`

禁用按钮：

- bg: `#E9ECEF`
- fg: `#ADB5BD`

### 5.3 Card

- 默认卡片背景：`#FFFFFF`
- 卡片阴影避免过重，建议沿用绿色低透明阴影思路
- 卡片内的状态标签优先用浅色底 + 深色字，不要直接大面积高饱和填充

### 5.4 Tag / Badge / Chip

- 默认弱标签：`#E9F5EC` / `#2D6A4F`
- 强调标签：`#D8F3DC` / `#2D6A4F`
- 提醒标签：`#FEF3E2` / `#E76F51`
- 危险标签：`#FFEBEE` / `#EF5350`

### 5.5 List / Sheet

- Bottom sheet 背景：`#FFFFFF`
- Handle：`#D8F3DC`
- 分组标题建议使用 `textSecondary`
- 行项目若需要强调新增内容，可用左侧绿色细条，不直接整块高亮

## 6. Flutter 落地建议

建议拆成以下层级：

- `AppColors`
- `AppColorScheme` 或直接映射到 `ColorScheme`
- `AppTheme`

建议最少包含这些 token：

```dart
abstract final class AppColors {
  static const primary = Color(0xFF2D6A4F);
  static const primaryLight = Color(0xFF40916C);
  static const primaryAccent = Color(0xFF52B788);
  static const primarySoft = Color(0xFF95D5B2);
  static const primaryContainer = Color(0xFFD8F3DC);

  static const background = Color(0xFFF4F9F6);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSoft = Color(0xFFE9F5EC);
  static const surfaceMuted = Color(0xFFF8FAF9);

  static const textPrimary = Color(0xFF1B4332);
  static const textSecondary = Color(0xFF6C757D);

  static const warning = Color(0xFFF4A261);
  static const warningSoft = Color(0xFFFEF3E2);
  static const danger = Color(0xFFEF5350);
  static const dangerSoft = Color(0xFFFFEBEE);
}
```

建议 `ColorScheme` 对应关系：

- `primary` -> `AppColors.primary`
- `onPrimary` -> `Colors.white`
- `primaryContainer` -> `AppColors.primaryContainer`
- `secondary` -> `AppColors.primaryAccent`
- `surface` -> `AppColors.surface`
- `onSurface` -> `AppColors.textPrimary`
- `error` -> `AppColors.danger`
- `onError` -> `Colors.white`

## 7. 补充 Token 规范

除了颜色，v1 统一补充以下 UI token，避免每个页面各写一套尺寸。

### 7.1 Spacing

- `spaceXs = 4`
- `spaceSm = 8`
- `spaceMd = 12`
- `spaceLg = 16`
- `spaceXl = 20`
- `spaceXxl = 24`
- `spaceSection = 32`

建议用途：

- 页面内小间距优先使用 `8 / 12`
- 卡片内容和按钮区优先使用 `16`
- 分区之间优先使用 `24 / 32`

### 7.2 Radius

- `radiusSm = 8`
- `radiusMd = 12`
- `radiusLg = 16`
- `radiusXl = 24`
- `radiusPill = 999`

建议用途：

- 输入框：`12` 或 `14`
- 卡片：`16`
- sheet：`24`
- chip：`999`

### 7.3 Typography

建议最少冻结以下样式：

- `pageTitle`: 28 / 600 / `textPrimary`
- `sectionTitle`: 20 / 600 / `textPrimary`
- `cardTitle`: 17 / 600 / `textPrimary`
- `body`: 15 / 400 / `textPrimary`
- `bodySecondary`: 14 / 400 / `textSecondary`
- `caption`: 13 / 400 / `textSecondary`
- `chipLabel`: 12 / 500
- `buttonLabel`: 15 / 600

原则：

- 标题层级不要过多
- 正文默认使用 15
- 辅助说明和标签使用 12 到 14

## 8. 儿童绘本风插画规范

为了让“家庭厨房”主题更有亲和力，v1 补充一套独立于界面组件的插画语言。该插画不替代全局绿色主题，而是在首页头图、空状态、引导位中提供更强的情绪表达。

素材位置：

- `design/illustrations/home_storybook_hero.svg`
- `design/illustrations/empty_menu_storybook.svg`
- `design/illustrations/empty_family_storybook.svg`
- `design/illustrations/empty_orders_storybook.svg`

使用原则：

- 主色仍然遵循绿色主题系统，插画只引入奶油黄、蜂蜜橙、柔和粉作为陪衬色。
- 描边统一使用偏棕色软线条，避免黑色硬描边破坏绘本感。
- 人物不追求写实比例，允许头身比偏大、五官简化、表情明确。
- 场景道具优先围绕厨房、餐桌、便签、餐盘、锅具、家庭成员协作展开。
- 页面同屏只放一张主插画，避免与信息卡片竞争注意力。
- 空状态插画优先放在文案上方，并保留足够留白，不应压缩到过窄比例。

推荐落点：

- 首页顶部欢迎区使用 `home_storybook_hero.svg`
- 菜单为空时使用 `empty_menu_storybook.svg`
- 家庭或成员为空时使用 `empty_family_storybook.svg`
- 当前无订单或历史为空时使用 `empty_orders_storybook.svg`

### 7.4 Icon Size

- `iconSm = 16`
- `iconMd = 20`
- `iconLg = 24`
- `iconXl = 32`

### 7.5 Page Padding

- 页面左右内边距：`16`
- 页面顶部内容起始：`12`
- 卡片内边距：`16`
- sheet 左右内边距：`20`
- sheet 上下内边距：`16`

### 7.6 Shadow

建议只保留一档轻阴影：

- 低透明绿色或中性灰阴影
- y 偏移小于等于 8
- blur 控制在 16 到 24

避免：

- 过重阴影
- 多层高对比投影
- 强烈悬浮感

## 8. 组件视觉规则

### 8.1 输入框

- 默认背景使用 `surface`
- 边框使用低对比度浅绿灰
- 聚焦边框使用 `primary`
- 错误态使用 `danger`

### 8.2 底部导航

- 背景使用 `surface`
- 选中图标和文字使用 `primary`
- 未选中使用 `textSecondary`
- 顶部分隔线保持极浅

### 8.3 Skeleton

- 骨架底色使用 `surfaceSoft`
- shimmer 对比保持轻微
- 不使用高对比灰色骨架

### 8.4 Empty State

- 插图区域允许使用 `primaryContainer`
- 标题使用 `textPrimary`
- 描述使用 `textSecondary`
- 若有 CTA，仅保留一个主动作

## 9. 响应式约束

v1 采用 mobile-first。

规则：

- 最小适配宽度按小屏手机处理
- 平板先采用居中手机容器，不做双栏
- 底部导航固定
- sheet 最大高度建议不超过 80% 屏高

## 10. 不采用的方向

以下方向不作为全局主题基准：

- `design/Menu.svg` 的暖棕色大面积主视觉
- 高饱和橙红作为主按钮色
- 纯白背景 + 纯黑文字的通用后台风格

原因：

- 暖棕更适合作为菜单页插画或食物氛围表达，不适合作为全局交互主色。
- 绿色更符合当前订单、清单、状态、协作类页面的整体一致性。
- 当前业务更需要“清晰可用”，再叠加“轻厨房感”，而不是纯品牌化海报效果。

## 8. 当前结论

当前 App 主题以绿色系为唯一全局主题方向：

- 主色：`#2D6A4F`
- 主背景：`#F4F9F6`
- 主文字：`#1B4332`
- 提醒强调：`#E76F51` / `#F4A261`
- 危险操作：`#EF5350`

后续新增页面、组件和插画，如无特殊理由，均应优先服从本主题系统。
