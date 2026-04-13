# Views — 业务页面规范

## 概述

所有业务页面（Tab 根页、子页面、sheet 页）均在此目录。View 只负责布局和状态绑定，不写业务逻辑。遵循父目录所有约束。

## 页面清单（v1）

| 页面 | 文件 | 触达路径 |
|------|------|---------|
| 入驻页 | `OnboardingView.swift` | App 启动，无 active member |
| 主 Tab 容器 | `MainTabView.swift` | 入驻成功后 |
| 菜单页（点菜方视角） | `MenuView.swift` | Tab 1 |
| 订单页（厨房视角） | `OrderView.swift` | Tab 2 |
| 成员页 | `MembersView.swift` | Tab 3 |
| 厨房设置页 | `KitchenSettingsView.swift` | Tab 3 → 设置入口 |
| 菜品详情 sheet | `DishDetailSheet.swift` | 菜单页点击菜品 |
| 新增菜品 sheet | `AddDishSheet.swift` | 菜单页（owner/admin）|
| 采购清单 sheet | `ShoppingListSheet.swift` | 订单页 |

## 导航约束

- Tab 根页导航深度不超过 2 层（根 → 子页面，子页面不再 push）
- 所有表单使用 `.sheet`，不 push 新页面
- sheet 必须有明确关闭路径（关闭按钮或下滑手势）
- 不使用 `NavigationLink` 进入表单类页面

## 页面组织规范

- 每个页面一个文件，文件名以 `View` 或 `Sheet` 结尾
- 页面 body 超过 50 行必须拆分为私有子 struct
- 有明显区块（header / list / empty state / footer）时各抽为独立私有 struct
- View 内不直接实例化 Store，通过 `@EnvironmentObject` 获取

## 状态来源

- 全局状态（当前 kitchen、当前角色）来自 `AppStore`
- 菜品列表来自 `DishStore`
- 订单和 item 来自 `OrderStore`
- 成员列表来自 `MemberStore`
- 本地表单状态（输入框文字、sheet 是否展示）用 `@State`

## 权限在 View 层的表达

- owner/admin 可见的操作（新增菜品、改 item 状态、结束订单）通过 `currentRole` 条件渲染
- 不允许仅隐藏按钮而不校验后端权限
- View 只做展示隐藏，实际权限由 Store 调用 API 时后端校验

## 空状态与加载

- 列表为空时展示统一空态组件（`AppEmptyState`），不显示空白页面
- 加载中展示 skeleton，不阻塞页面
- 错误通过 banner 展示在页面顶部，不替换整个页面内容
