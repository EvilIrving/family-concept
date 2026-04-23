# Views — 业务页面规范

## 概述

所有业务页面、业务 sheet 和页面级支持类型都放在此目录。View 负责页面编排、局部交互和状态绑定。遵循父目录所有约束。

## 当前页面清单

- `ContentView.swift`：启动阶段路由，按 `isBootstrapping` / `hasKitchen` 分流
- `MainTabView.swift`：自定义三栏 Tab 容器，承载 `MenuView`、`OrdersView`、`SettingsView`
- `OnboardingView.swift`：登录、注册、加入私厨、创建私厨
- `OrdersView.swift`：开放订单、状态 pill、采购清单入口
- `SettingsView.swift`：私厨信息、成员操作 sheet、邀请码复制、退出登录
- `Orders/`：
  - `OrderHistorySheets.swift`：历史订单列表与历史订单详情弹层
- `Menu/`：
  - `MenuView.swift`：菜单搜索、分类筛选、加菜入口、购物车入口
  - `MenuCartSheet.swift`：购物车弹层
  - `AddDishFlow/`：新增/编辑菜品流程，包含表单页面、图片选择区、食材输入和流程状态类型
  - `DishImageFlow/`：相机拍照、取景裁切及其画布/遮罩支持视图

## 导航与弹层约束

- 顶层结构由 `ContentView` 和 `MainTabView` 控制，不依赖系统 `TabView`
- 表单和辅助流程优先用 `.sheet` 或 `.fullScreenCover`
- 菜单图片流程通过 `ModalRouter` 在“加菜 / 相机 / 裁图”之间切换
- 每个弹层都要有明确的退出路径和 dismiss 同步

## 页面组织规范

- 一个主页面一个文件；复杂页面允许同文件私有子 View 或支持类型
- 局部状态留在 View，例如搜索词、sheet 展示、焦点、表单校验、toast
- 共享业务状态通过 `@EnvironmentObject private var store: AppStore`
- 页面级过渡路由优先放 `@StateObject private var modalRouter`

## 状态来源

- 启动状态、账号、私厨、成员、菜品、订单来自 `AppStore`
- 表单输入、搜索关键字、焦点、弹层展示来自 `@State` / `@FocusState`
- 轻量反馈可以直接用局部 `AppToastData?`
- 图片草稿流程可以由页面持有专用 coordinator，例如 `DishImageCoordinator`

## 权限表达

- `store.canManageDishes` 控制加菜和菜品管理入口
- `store.canManageOrders` 控制订单状态流转入口
- View 负责入口可见性与交互禁用
- 真实权限以 Store 调 API 后的服务端结果为准

## 当前实现特征

- `OnboardingView` 是单页状态机，未登录与已登录无 kitchen 两种形态共用一个页面
- `MenuView` 内部做搜索防抖、分类筛选、本地 toast 和图片流程编排
- `OrdersView` 用底部 bar 打开采购清单，用浮动按钮打开历史订单
- `SettingsView` 用成员头像横向列表触发成员信息 sheet

## 文档维护

- 如果本文件规则已经和代码、文档或实际流程不一致，修代码或修文档后顺手修正本文件。
- 保持 `AGENTS.md` 和 `CLAUDE.md` 内容一致。任何一方更新，另一方必须同步更新。
