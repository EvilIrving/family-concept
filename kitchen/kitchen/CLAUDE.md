# kitchen/kitchen — App 源码规范

## 概述

iOS App 的核心源码目录，包含模型、Store、视图和 UI 组件。遵循父目录 `kitchen/CLAUDE.md` 的所有约束，本文件只补充模块分工。

## 目录结构

```
kitchen/
├── kitchenApp.swift      # App 入口，注入全局 Store
├── Models/               # 领域模型（纯 struct，无副作用）
├── Stores/               # 全局状态管理（ObservableObject）
├── Views/                # 业务页面（Tab 页、子页面、sheet）
├── UI/
│   ├── Components/       # 可复用 UI 组件（AppButton、AppCard 等）
│   ├── Containers/       # 布局容器（AppSheetContainer 等）
│   └── Feedback/         # 反馈组件（Toast、Banner、Skeleton）
└── Design/               # 设计资产（AppTheme、Color Token 等）
```

## 身份与启动流程

1. App 首次启动 → 本地生成 UUID 作为 `device_id`，存入 `UserDefaults`（仅此一处允许）
2. `AppStore` 读取 `device_id`，向后端请求或创建设备记录
3. 若当前设备没有任何 `active` 的 `members` 记录 → 展示入驻页（`OnboardingView`）
4. 入驻成功后进入主 Tab 界面

## 入驻页逻辑

- 入驻页只有单一页面结构，不 push 子页面
- 默认模式为 `join`（输入邀请码）；点击「创建我的私厨」切换为 `create`（输入厨房名）
- 两种模式共用同一主输入框，不新增页面结构
- 统一调用 `POST /onboarding/complete`

## 模块分工原则

- Models：只定义数据结构和枚举，不含任何 UI 或网络代码
- Stores：只管理状态和副作用（网络、持久化），不含 View 代码
- Views：只消费 Store 状态进行布局，不直接调用网络
- UI/Components：无业务依赖，只接受配置参数渲染
- UI/Feedback：Toast、Banner、Skeleton 全局可用，通过环境对象触发
- 输入类组件遵循“行为尽量原生，样式单独封装”：焦点、键盘、输入法联动优先交给系统控件，组件层负责外观、布局、点击热区和校验态

## 全局 Store 注入

`kitchenApp.swift` 创建所有顶层 Store 并通过 `.environmentObject` 注入，View 通过 `@EnvironmentObject` 获取，不直接实例化 Store。
