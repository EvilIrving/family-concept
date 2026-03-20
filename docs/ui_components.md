# UI Components

## 1. 文档目标

这份文档用于冻结 v1 的组件系统，避免页面开发时重复拼样式和重复定义交互。

组件分为三层：

- Foundation
- Shared Business
- Page Section

原则：

- 优先抽基础组件，不在页面中直接硬编码视觉
- 同类交互保持统一组件入口
- 页面只负责布局与业务编排

## 2. Token 来源

组件不再重复定义 design token，统一引用 [ui_theme.md](/Users/cain/Documents/code/flutter-family-concept/docs/ui_theme.md)。

本文件只约束：

- 组件职责
- 组件参数
- 组件变体
- 组件复用边界

涉及以下内容时，以主题文档为准：

- 颜色
- spacing
- radius
- typography
- icon size
- padding
- shadow

## 3. Foundation Components

### 3.1 `AppScaffold`

用途：

- 承载全局页面背景
- 统一 safe area、padding、scroll 行为

参数建议：

- `title`
- `body`
- `actions`
- `bottomNavigationBar`
- `floatingActionButton`
- `showAppBar`
- `useGradientHeader`

规则：

- 主导航页允许渐变头部
- 表单页默认纯色 header
- 登录、注册页可关闭 app bar，仅保留内容区
- Android 统一关闭 stretch overscroll

### 3.1.1 `CenteredContent`

用途：

- 登录、注册、onboarding 等表单页内容居中

规则：

- 长屏采用视觉偏上的居中，避免表单落在屏幕正中显得过低
- 在 `SingleChildScrollView` 内也必须基于 viewport 高度居中，不能退化成顶部对齐
- 登录、注册页内容直接与页面背景一体展示，不再包裹 `AppCard`
- 登录、注册页优先使用基于 viewport 的自适应上下 padding，不使用偏大的固定上下留白

### 3.2 `AppCard`

用途：

- 统一内容卡片底板

参数建议：

- `child`
- `padding`
- `onTap`
- `bordered`
- `highlighted`

规则：

- 默认白底
- 默认圆角 16
- 点击态只改边框或阴影，不整体缩放

### 3.3 `PrimaryButton`

用途：

- 主路径操作

场景：

- 登录
- 注册
- 创建家庭
- 创建订单
- 保存菜品

规则：

- 一屏最多一个主按钮
- 不与另一个同级主按钮并列出现

### 3.4 `SecondaryButton`

用途：

- 次路径操作

场景：

- 取消
- 返回
- 打开筛选
- 打开分享

### 3.4.1 `AppIconButton`

用途：

- 紧凑图标操作

场景：

- 编辑个人信息
- 复制邀请码
- 刷新邀请码
- 采购清单入口

### 3.5 `DangerButton`

用途：

- 危险操作

场景：

- 删除菜品
- 移除成员
- 退出家庭
- 退出登录
- 结束订单（全宽更紧凑的危险按钮）

### 3.6 `AppTextField`

用途：

- 统一输入框视觉、错误态、说明文案

场景：

- username
- password
- family name
- join code

规则：

- 文案错误显示在字段下方
- 密码字段支持显隐切换

### 3.7 `AppSearchBar`

用途：

- 搜索菜品
- 搜索历史订单

规则：

- 搜索图标左侧固定
- 清空按钮在有内容时出现
- 搜索为空时不展示无结果态

### 3.7.1 `QuantityStepper`

用途：

- 菜品卡片内直接加减菜

规则：

- `- / +` 同行展示
- 局部 loading 不阻塞整页
- `- / +` 按钮字号与点击热区放大，优先保证触达性

### 3.8 `StatusChip`

用途：

- 统一订单状态、菜品项状态、成员角色标签

变体：

- `ordering`
- `placed`
- `finished`
- `waiting`
- `cooking`
- `done`
- `owner`
- `admin`
- `member`

规则：

- 使用浅底深字
- 不使用高饱和纯色实心块

### 3.9 `CategoryChip`

用途：

- 菜品分类筛选

规则：

- 单选
- 选中态使用绿色体系
- 未选中态使用 `surfaceSoft`

### 3.10 `EmptyState`

用途：

- 统一空态展示

参数建议：

- `title`
- `description`
- `actionLabel`
- `onAction`
- `illustrationKey`

### 3.11 `ErrorState`

用途：

- 统一错误与重试

参数建议：

- `title`
- `description`
- `retryLabel`
- `onRetry`

### 3.12 `AppBottomSheet`

用途：

- 统一全局底部弹层

规则：

- 顶部 handle 固定
- 最大高度建议 80% 屏高
- 内容超长时 sheet 内部滚动
- 个人资料、成员管理、历史订单优先走 sheet

### 3.13 `ConfirmDialog`

用途：

- 统一二次确认

参数建议：

- `title`
- `message`
- `confirmLabel`
- `cancelLabel`
- `isDanger`

## 4. Shared Business Components

### 4.1 `FamilyHeader`

用途：

- Shell 顶部家庭上下文

内容：

- 家庭名称
- 家庭切换入口
- 可选副标题

补充：

- 当前实现中家庭切换收口到 app bar，不再在 `menu_page`、`orders_page` 内容区重复渲染家庭头卡

### 4.2 `DishGridCard`

用途：

- 菜单双列菜品卡片

内容：

- 图片区
- 菜名
- 数量步进器

规则：

- 图片区约占卡片高度 60%
- 点击图片打开菜品详情 sheet
- 卡片正文不显示食材数量
- 仅在订单为 `ordering`（进行中）时展示数量角标
- 若订单状态为 `placed`，但当前轮次已存在新增菜品，则视为新一轮已开始，按 `ordering` 展示
- 角标数量为当前轮次（`current_round`）该菜的全员累计数量
- 订单为 `placed` / `finished` 时不展示角标
- 标题与步进器采用紧凑布局，避免中部出现大面积留白
- 当前实现正文区使用更紧凑的上下内边距、标题行高与控件尺寸，避免双列卡片底部溢出

### 4.2 `DishCard`

用途：

- 菜单页展示菜品

内容：

- 封面图
- 菜名
- 分类
- 食材摘要
- 管理入口或加菜入口

变体：

- `member`
- `admin`

### 4.3 `OrderCard`

用途：

- 订单列表摘要

内容：

- 订单状态
- 创建时间
- 当前轮次
- 参与人数
- 快捷操作

### 4.4 `OrderItemTile`

用途：

- 订单详情中的菜品项

内容：

- 菜名
- 数量
- 状态
- 添加人
- 轮次标记

### 4.5 `MemberAvatarGroup`

用途：

- 展示参与者头像或昵称集合

规则：

- 超过 4 人后显示 `+n`

### 4.6 `QuantityStepper`

用途：

- 点菜数量调整

规则：

- 最小值 1
- 长按连续变化不是 v1 必需

### 4.7 `IngredientListEditor`

用途：

- 菜品编辑页维护食材列表

内容：

- 食材名
- 数量
- 单位
- 新增和删除行

### 4.8 `RoleActionRow`

用途：

- 成员管理中展示角色与操作按钮

内容：

- 成员名
- 角色标签
- 提升 / 取消管理员
- 移除成员

## 5. Page Section Components

### 5.1 `MenuHeroSection`

用于菜单页头部：

- 页面标题
- 搜索框
- 分类筛选

### 5.2 `CurrentOrderSummary`

用于订单页顶部：

- 当前订单状态
- 当前轮次
- 参与人数
- 主操作按钮

### 5.3 `ShoppingListRoundBanner`

用于采购清单：

- 当前轮次提示
- 新增食材高亮说明

### 5.4 `SettingsActionList`

用于设置页：

- 个人资料
- 家庭成员
- 历史订单
- 退出登录

## 6. 组件使用规则

### 6.1 复用优先级

优先顺序：

1. Foundation
2. Shared Business
3. Page Section
4. 页面局部私有 widget

### 6.2 禁止事项

不要：

- 在页面里重复写状态 chip 样式
- 在不同页面各自实现空态布局
- 为同一类按钮写多个不同圆角和高度
- 让每个 sheet 都有不同的顶部结构

### 6.3 命名建议

统一使用业务可读命名：

- `DishCard`
- `OrderCard`
- `FamilyHeader`

不要：

- `Box1`
- `MenuWidgetNew`
- `CustomContainer2`

## 7. 开发顺序

建议先实现：

1. `AppScaffold`
2. `AppCard`
3. `PrimaryButton` / `SecondaryButton` / `DangerButton`
4. `StatusChip`
5. `EmptyState` / `ErrorState`
6. `AppBottomSheet`
7. `DishCard`
8. `OrderCard`
9. `OrderItemTile`

这样可以最早支撑 Phase 2-5 的主要页面。
