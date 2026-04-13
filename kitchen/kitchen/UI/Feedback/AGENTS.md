# UI/Feedback — 反馈组件规范

## 概述

全局反馈层组件：Toast、Banner、Skeleton/Shimmer。所有组件无业务依赖，通过环境对象或参数触发。遵循父目录所有约束。

## Toast（AppToastHost）

### 用途
- 操作成功确认（菜品已添加、订单已结束）
- 破坏性操作的 undo 提示（删除菜品后「撤销」）
- 轻量错误提示（网络失败等）

### 设计规范
- 悬浮在底部安全区上方，不阻塞当前操作
- 背景：深绿色（`green800`）或高对比中性色
- 圆角：`radius20` 或更大
- 支持：图标 + 文案 + 单个动作按钮（如「撤销」）
- 出现/消失：淡入 + 轻位移（向上 8pt），不做弹跳
- 自动消失：3 秒（带操作按钮时 5 秒）
- 同时只展示一条，新 toast 替换旧 toast

### 触发方式
- 通过 `@EnvironmentObject` 的 `ToastStore` 触发
- View 内调用 `toastStore.show("已添加到订单")`
- 禁止在 View 内直接管理 toast 显隐状态

## Banner（AppBanner）

### 用途
- 页面级错误提示（网络错误、权限不足）
- 持续性提醒（当前订单已结束，无法追加菜品）

### 设计规范
- 内联展示在页面顶部内容区（不覆盖导航栏）
- 根据语义使用对应色：错误用 `dangerSoft + danger`，提醒用 `warningSoft + warning`，信息用 `infoSoft + info`
- 可手动关闭（右侧关闭按钮）
- 不自动消失

### 触发方式
- Store 的 `@Published var bannerMessage: BannerMessage?` 驱动
- View 通过条件渲染展示/隐藏

## Skeleton / Shimmer

### 用途
- 数据加载中的占位展示
- 替代阻塞式 spinner，保持页面结构稳定

### 设计规范
- 形状与实际内容一致（卡片型、行型、圆形头像型）
- 颜色：`surfaceSecondary` 到 `surfaceTertiary` 之间的渐变动画
- 动效：横向扫光（shimmer），服从 Reduce Motion 设置（关闭时静态占位色）
- 不显示实际文字或图片

### 使用规则
- 列表页首次加载时展示 skeleton
- 刷新时不展示 skeleton（保持现有内容，顶部展示细进度条或无提示）
- 不在 skeleton 消失时做突兀切换，使用 `.transition(.opacity)`

## 空态（AppEmptyState）

### 用途
- 列表为空时展示，不显示空白页面

### 设计规范
- 包含：插图/图标 + 标题 + 副文案 + 可选操作按钮
- 垂直居中在列表区域
- 颜色使用 `textSecondary` / `textTertiary`，不抢夺视觉焦点
