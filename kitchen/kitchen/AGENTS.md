# kitchen/kitchen — App 源码规范

## 概述

iOS App 的核心源码目录，包含模型、服务、Store、视图和 UI 组件。遵循父目录 `kitchen/CLAUDE.md` 的所有约束，本文件只补充当前源码分工和真实启动流程。

## 目录结构

```
kitchen/
├── kitchenApp.swift      # App 入口，注入全局 AppStore
├── Design/               # 设计 token（颜色、间距、圆角、字体）
├── Models/               # 领域模型和本地草稿状态
├── Services/             # APIClient、Endpoint、图片处理与上传编排
├── Stores/               # 全局状态与副作用入口
├── Views/                # 业务页面（入驻、菜单、订单、设置）
└── UI/
    ├── Components/       # 可复用 UI 组件
    ├── Containers/       # 页面/弹层容器
    ├── Feedback/         # Toast、校验反馈等交互反馈
    └── Layout/           # 通用布局能力
```

## 身份与启动流程

1. `kitchenApp.swift` 创建单个 `AppStore`，通过 `.environmentObject` 注入全局
2. `ContentView` 首次 `.task` 调用 `AppStore.bootstrap()`
3. `AppStore.init()` 从 `UserDefaults` 读取 `authToken` 与 `nickName`
4. 有 token 时调用 `GET /api/v1/auth/me` 恢复账号；成功后尝试用 `lastKitchenID` 恢复当前 kitchen
5. `store.isBootstrapping` 为真时占位；恢复完成后：
   - 有 kitchen：进入 `MainTabView`
   - 无 kitchen：进入 `OnboardingView`
6. `ContentView.task(id: store.kitchen?.id)` 在 kitchen 切换后触发 `fetchAll()`，并行拉取成员、菜品和当前开放订单

UserDefaults 持久化项：`authToken`、`accountID`、`nickName`、`lastKitchenID`。

## 入驻页逻辑

- 单页状态机，页面主体始终停留在 `OnboardingView`
- 未登录时支持 `login` / `register` 两种认证模式
- `register` 比 `login` 多一个昵称输入
- 登录或注册时可以直接附带“邀请码加入”或“创建私厨”输入
- 已登录但无 kitchen 时，只保留加入/创建区域和退出登录入口
- 加入与创建统一走 `POST /api/v1/onboarding/complete`
- 登录走 `login()`，注册走 `register()`，进入 kitchen 后由 `fetchAll()` 补全数据

## 模块分工原则

- Models：定义领域 struct、enum、本地草稿状态和轻量计算属性
- Services：封装 API、上传、图片处理流程；不持有页面状态
- Stores：管理网络请求、持久化、聚合状态和业务动作
- Views：消费 Store 状态做页面编排；局部交互状态可以留在 View
- UI/Components：无业务依赖，通过参数驱动渲染
- UI/Feedback：负责 toast、shake、校验反馈等全局或局部反馈能力
- 输入类组件遵循“原生行为优先，样式封装单独处理”

## 当前页面结构

- `ContentView`：启动分流与数据预取触发点
- `MainTabView`：三栏 Tab，包含 `MenuView`、`OrdersView`、`SettingsView`
- `Views/Menu/`：菜单搜索、筛选、加菜、拍照、裁图、购物车相关页面与支持类型
- `OnboardingView`：账号登录、注册、加入私厨、创建私厨
- `OrdersView`：开放订单、状态流转、采购清单 sheet
- `SettingsView`：私厨信息、成员列表、邀请码复制、退出登录

## 文档维护

- 如果本文件规则已经和代码、文档或实际流程不一致，修代码或修文档后顺手修正本文件。
- 保持 `AGENTS.md` 和 `CLAUDE.md` 内容一致。任何一方更新，另一方必须同步更新。
