# Views 重构计划

## 目标

把入口文件 (`OrdersView.swift`, `OnboardingView.swift`, `SettingsView.swift`, `MenuView.swift`) 收敛成稳定的页面编排层，将流程容器、sheet、局部业务实现、展示映射迁到对应功能目录。

**成功标准：**
- 入口页只保留页面级 `@State`、路由绑定、少量 action dispatch、顶层 layout
- 连续交互流程优先独立成容器
- 现有交互和视觉行为保持一致
- 每个 feature 拆完就完成局部验证

---

## 执行顺序

1. **Orders**（风险最低，已有部分拆分基础）
2. **Settings**（结构简单，只是文件分散）
3. **Onboarding**（需要处理模式切换逻辑）
4. **Menu**（最后处理，状态链最复杂）

---

## 1. Orders 重构

### 当前状态
- `OrdersView.swift`：~498 行，包含：
  - 主视图 `OrdersView`
  - `ShoppingListSheet`（sheet 实现）
  - `ShoppingListExportCard`（导出用）
  - `OrderItemRow`（列表行组件）
  - `OrdersModalRoute` enum
- `Views/Orders/OrderHistorySheets.swift`：已独立（~225 行）

### 目标结构

```
Views/Orders/
├── OrdersView.swift          # 入口，~120 行（编排层）
├── OrdersModalRoute.swift    # 路由 enum 独立文件
├── ShoppingListSheet.swift   # ~150 行
├── OrderHistorySheet.swift   # 已存在，从 OrderHistorySheets.swift 改名
├── OrderHistoryDetailSheet.swift  # 已存在，保持
└── OrderItemRow.swift        # ~80 行
```

### 文件职责

#### OrdersView.swift（编排层，~120 行）
**保留：**
- 页面级 `@StateObject var modalRouter`
- 页面骨架（ZStack + VStack）
- 顶部统计概览（`statusPill` 调用）
- 订单列表区（`AppLoadingBlock` + `ForEach`）
- 底部采购清单 bar
- FloatButton 路由
- `modalRouteBinding` 绑定 helper
- 派生状态计算：`waitingCount`, `cookingCount`, `doneCount`, `shouldShowFinishButton`

**迁出：**
- `ShoppingListSheet` → `ShoppingListSheet.swift`
- `OrderHistorySheet` → 已在独立文件
- `OrderItemRow` → `OrderItemRow.swift`
- `statusPill` → 保持私有 helper（简单展示，无交互）
- `ShoppingListExportCard`, `ActivityShareSheet`, `ShoppingListShareItemSource` → 随 `ShoppingListSheet` 一起

---

#### ShoppingListSheet.swift（~150 行）
**内容：**
- `ShoppingListSheet` 主结构
- `ShoppingListExportCard`
- `ActivityShareSheet`
- `ShoppingListShareItemSource`
- `SharePayload`

**依赖：**
- `@EnvironmentObject AppStore`
- `@EnvironmentObject AppFeedbackRouter`

---

#### OrderItemRow.swift（~80 行）
**内容：**
- `OrderItemRow` 视图
- 私有计算属性：`statusColor`, `statusBackground`

**依赖：**
- 通过参数接收所有交互回调
- 无 Store 依赖

---

#### OrdersModalRoute.swift
**内容：**
- `enum OrdersModalRoute: Identifiable, Equatable`

---

### 状态迁移

| 状态 | 保留位置 |
|------|----------|
| `modalRouter` | OrdersView |
| `shoppingListSheet` 展示 | modalRouter 管理 |
| `historySheet` 展示 | modalRouter 管理 |

### 验证清单

- [ ] 统计 pill 展示正确（待制作/制作中/已完成）
- [ ] 点击订单 item 触发状态流转
- [ ] 减少数量（`-` 按钮）工作正常
- [ ] 取消订单（`x` 按钮）工作正常
- [ ] "这顿好了"按钮工作正常
- [ ] 采购清单 sheet 展示、导出功能正常
- [ ] 历史订单 sheet 展示、详情钻取正常
- [ ] Preview 覆盖：订单列表、采购清单 sheet

---

## 2. Settings 重构

### 当前状态
- `SettingsView.swift`：~380 行，包含：
  - 主视图 `SettingsView`
  - `MemberRoleSheet`（sheet 实现）
  - `MemberSheetToken`, `SettingsModalRoute` 支持类型
  - 大量私有 helper：`kitchenIdentityCluster`, `memberAvatarButton`, `themeSelectionRow`, `toggleRow`, `placeholderRow`

### 目标结构

```
Views/Settings/
├── SettingsView.swift          # 入口，~100 行（编排层）
├── SettingsModalRoute.swift    # 路由 enum 独立文件
├── KitchenInfoCard.swift       # ~80 行
├── MemberAvatarStrip.swift     # ~60 行
├── InviteCodeCard.swift        # ~50 行
├── PreferencesSection.swift    # ~80 行
├── MemberRoleSheet.swift       # ~120 行
└── ThemeSelectionRow.swift     # ~60 行
```

### 文件职责

#### SettingsView.swift（编排层，~100 行）
**保留：**
- 页面级 `@StateObject var modalRouter`
- `@AppStorage` 偏好设置（`hapticsEnabled`, `themeMode`）
- 页面骨架（`AppScrollPage`）
- 各子组件的编排调用
- `modalRouteBinding` 绑定 helper

**迁出：**
- `kitchenIdentityCluster` → `MemberAvatarStrip.swift`
- `memberAvatarButton` → 放入 `MemberAvatarStrip.swift` 或保持私有
- `themeSelectionRow` → `ThemeSelectionRow.swift`
- `MemberRoleSheet` → `MemberRoleSheet.swift`
- 厨房信息卡区块 → `KitchenInfoCard.swift`
- 邀请码区块 → `InviteCodeCard.swift`
- 偏好 section → `PreferencesSection.swift`

---

#### KitchenInfoCard.swift（~80 行）
**内容：**
- 厨房名称展示
- 人数统计
- 调用 `MemberAvatarStrip`
- 调用 `InviteCodeCard`

**依赖：**
- `@EnvironmentObject AppStore`
- `@EnvironmentObject AppFeedbackRouter`（复制提示）

---

#### MemberAvatarStrip.swift（~60 行）
**内容：**
- 横向滚动成员头像
- 头像点击触发 sheet
- 超过 6 人提示文案

**依赖：**
- `@EnvironmentObject AppStore`
- 通过参数接收 `onMemberTap` 回调

---

#### InviteCodeCard.swift（~50 行）
**内容：**
- 邀请码展示卡片
- 复制按钮
- 视觉样式（带图标的卡片）

**依赖：**
- 通过参数接收 `inviteCode` 和 `onCopy` 回调

---

#### PreferencesSection.swift（~80 行）
**内容：**
- `AppSectionHeader`
- 消息通知 toggle
- 震动反馈 toggle
- 多语言 placeholder
- 主题选择行

**依赖：**
- `@Binding` 接收偏好设置
- 调用 `ThemeSelectionRow`

---

#### ThemeSelectionRow.swift（~60 行）
**内容：**
- 主题选择 Menu
- 展示当前主题
- 调用 `store.setThemeMode`

**依赖：**
- `@Binding themeMode`
- `@EnvironmentObject AppStore`

---

#### MemberRoleSheet.swift（~120 行）
**内容：**
- 成员信息展示
- 角色显示
- 移除成员按钮（仅 owner）

**依赖：**
- `@EnvironmentObject AppStore`

---

#### SettingsModalRoute.swift
**内容：**
- `enum SettingsModalRoute: Identifiable, Equatable`
- `MemberSheetToken` 支持类型

---

### 状态迁移

| 状态 | 保留位置 |
|------|----------|
| `notificationsEnabled` | SettingsView |
| `hapticsEnabled` | SettingsView (@AppStorage) |
| `themeMode` | SettingsView (@AppStorage) |
| `modalRouter` | SettingsView |

### 验证清单

- [ ] 邀请码复制功能正常，toast 展示
- [ ] 成员头像点击弹出角色 sheet
- [ ] 角色 sheet 信息展示正确
- [ ] Owner 可以看到"移除成员"按钮
- [ ] 主题切换工作正常
- [ ] 震动反馈 toggle 工作正常
- [ ] Preview 覆盖：厨房信息卡、成员区、偏好区

---

## 3. Onboarding 重构

### 当前状态
- `OnboardingView.swift`：~411 行，包含：
  - 主视图 `OnboardingView`
  - `authSection`（认证表单，~70 行）
  - `kitchenSection`（私厨表单，~60 行）
  - `kitchenModeToggle`（切换条，~35 行）
  - `bottomBar`（提交条，~15 行）
  - 大量 helper：`submit()`, `submitLogin()`, `submitRegister()`, `submitKitchen()`

### 目标结构

```
Views/Onboarding/
├── OnboardingView.swift        # 入口，~100 行（编排层）
├── OnboardingState.swift       # 状态枚举和 helper struct
├── AuthForm.swift              # ~120 行（登录/注册表单）
├── KitchenForm.swift           # ~100 行（加入/创建表单）
├── KitchenModeToggle.swift     # ~50 行
├── OnboardingSubmitBar.swift   # ~40 行
└── OnboardingValidationHelper.swift  # ~60 行（纯 struct，无 Store 依赖）
```

### 文件职责

#### OnboardingView.swift（编排层，~100 行）
**保留：**
- 所有 `@State` 状态（`authMode`, `kitchenMode`, `showKitchenField`, 表单字段，invalid 状态，shake 状态，`isSubmitting`）
- `@FocusState focusedField`
- 页面骨架（`ScrollView` + `formCard` + `bottomBar`）
- `submit()` 入口方法（分发到各表单的 submit）
- `formCard` 作为编排容器

**迁出：**
- `authSection` → `AuthForm.swift`
- `kitchenSection` → `KitchenForm.swift`
- `kitchenModeToggle` → `KitchenModeToggle.swift`
- `bottomBar` → `OnboardingSubmitBar.swift`
- `hintText`, `buttonTitle` → `OnboardingState.swift` 或保持私有
- `submitLogin()`, `submitRegister()`, `submitKitchen()` → 逻辑保留在 OnboardingView，但调用 `OnboardingValidationHelper`

---

#### OnboardingState.swift
**内容：**
- `enum AuthMode { case login, register }`
- `enum KitchenMode { case join, create }`
- `enum OnboardingField: Hashable`

---

#### OnboardingValidationHelper.swift（~60 行，纯 struct）
**内容：**
- 校验逻辑封装
- shake 计数管理
- 错误状态重置

```swift
struct OnboardingValidationHelper {
    static func validateUserName(_ name: String, shake: inout Int, invalid: inout Bool) -> Bool
    static func validatePassword(_ password: String, shake: inout Int, invalid: inout Bool) -> Bool
    // ...
}
```

**依赖：**
- 无 Store 依赖
- 纯值类型操作

---

#### AuthForm.swift（~120 行）
**内容：**
- 用户名输入
- 密码输入
- 昵称输入（注册模式）
- 焦点推进逻辑
- 校验状态绑定

**依赖：**
- `@Binding` 接收所有表单状态
- `@FocusState.Binding` 接收焦点
- 通过参数接收 `onSubmit` 回调

---

#### KitchenForm.swift（~100 行）
**内容：**
- 邀请码/私厨名称输入
- 焦点管理
- 校验状态绑定

**依赖：**
- `@Binding` 接收所有表单状态
- `@FocusState.Binding` 接收焦点

---

#### KitchenModeToggle.swift（~50 行）
**内容：**
- "输入邀请码加入" / "创建私厨" 切换
- 视觉状态（选中/未选中）
- 动画过渡

**依赖：**
- `@Binding` 接收 `kitchenMode` 和 `showKitchenField`

---

#### OnboardingSubmitBar.swift（~40 行）
**内容：**
- 提交按钮
- 按钮文案（通过参数接收）
- loading 状态

**依赖：**
- `@Binding isSubmitting`
- 通过参数接收 `onSubmit` 回调

---

### 状态迁移

| 状态 | 保留位置 |
|------|----------|
| `authMode` | OnboardingView |
| `kitchenMode` | OnboardingView |
| `showKitchenField` | OnboardingView |
| `userName`, `password`, `nickName`, `kitchenInput` | OnboardingView |
| `*_Invalid`, `*_Shake` | OnboardingView |
| `isSubmitting` | OnboardingView |
| `focusedField` | OnboardingView |

### 验证清单

- [ ] 登录模式表单展示正确
- [ ] 注册模式表单展示正确（多昵称字段）
- [ ] 登录/注册切换动画流畅
- [ ] 加入/创建私厨切换动画流畅
- [ ] 字段校验触发 shake
- [ ] 焦点推进正确（用户名 → 密码 → 昵称 → 邀请码）
- [ ] 提交按钮状态正确（loading / disabled）
- [ ] 错误展示位置正确
- [ ] Preview 覆盖：认证表单、私厨表单

---

## 4. Menu 重构

### 当前状态
- `MenuView.swift`：~1103 行，包含：
  - 主视图 `MenuView`（~200 行）
  - `MenuDishFlowContainer`（~300 行，完整流程容器）
  - `MenuDishFormScreen`（~180 行）
  - `MenuDishFlowImagePickerSection`（~120 行）
  - `MenuDishGridView`（~50 行）
  - `MenuEmptyStateView`（~30 行）
  - 支持类型：`MenuDishFlowItem`, `MenuDishFlowResult`, `MenuDishFlowRoute`, `CropRoute`
  - `MenuModalRoute` 在 `MenuSupport.swift`

**已独立文件：**
- `MenuCartSheet.swift`（已独立）
- `MenuDishImagePickerSection.swift`（独立但可能重复）
- `IngredientTagInput.swift`（已独立）
- `MenuSupport.swift`（支持类型）

### 目标结构

```
Views/Menu/
├── MenuView.swift              # 入口，~100 行（编排层）
├── MenuModalRoute.swift        # 从 MenuSupport 拆分
├── MenuDishFlow/
│   ├── MenuDishFlowContainer.swift   # ~250 行（流程容器）
│   ├── MenuDishFormScreen.swift      # ~150 行（表单页）
│   ├── MenuDishFlowImagePickerSection.swift  # ~100 行
│   └── MenuDishFlowState.swift         # 支持类型
├── MenuSearchBar.swift         # ~80 行
├── MenuCartBar.swift           # ~40 行
├── MenuDishGridView.swift      # ~60 行
├── MenuEmptyStateView.swift    # ~40 行
├── MenuCartSheet.swift         # 已存在
└── MenuSupport.swift           # 保留基础类型
```

### 文件职责

#### MenuView.swift（编排层，~100 行）
**保留：**
- 页面级状态（`searchText`, `debouncedSearchText`, `selectedCategory`, `dishFlowItem`, `visibleDishCount`, `focusedField`）
- 页面骨架
- `menuContent` 编排
- `menuCartBar` 调用
- `searchBar` 调用
- `categoryChips` helper
- `filteredDishes`, `menuPhase`, `visibleDishes` 计算属性
- 分页逻辑（`handleDishAppear`, `resetVisibleDishes`）
- `dishFlowItem` fullScreenCover

**迁出：**
- `MenuDishFlowContainer` → `MenuDishFlow/MenuDishFlowContainer.swift`
- `MenuDishFormScreen` → `MenuDishFlow/MenuDishFormScreen.swift`
- `MenuDishFlowImagePickerSection` → `MenuDishFlow/`
- `searchBar` → `MenuSearchBar.swift`
- `menuCartBar` → `MenuCartBar.swift`
- `MenuDishGridView` → 独立文件
- `MenuEmptyStateView` → 独立文件

---

#### MenuDishFlowContainer.swift（~250 行）
**内容：**
- 完整流程状态机
- NavigationStack 路径管理
- 相机/裁图/编辑路由
- 图片处理协调

**依赖：**
- `@EnvironmentObject AppStore`
- `@StateObject DishImageCoordinator`
- 通过参数接收 `onComplete` 回调

---

#### MenuDishFormScreen.swift（~150 行）
**内容：**
- 菜品表单页面
- 快速分类 chips
- 表单字段
- 删除确认对话框

**依赖：**
- `@Binding AddDishDraft`
- `@ObservedObject DishImageCoordinator`

---

#### MenuSearchBar.swift（~80 行）
**内容：**
- 搜索输入框
- 清除按钮
- 新增菜品按钮（权限控制）

**依赖：**
- `@Binding searchText`
- `@FocusState.Binding`
- 通过参数接收 `onAddDish` 回调

---

#### MenuCartBar.swift（~40 行）
**内容：**
- 购物车条目
- 数量展示
- 点击跳转

**依赖：**
- `@EnvironmentObject AppStore`
- 通过参数接收 `onTap` 回调

---

### 状态迁移（MenuDishFlowContainer）

| 状态 | 保留位置 |
|------|----------|
| `dishFlowItem` | MenuView |
| `navigationPath` | MenuDishFlowContainer |
| `selectedPhotoItem` | MenuDishFlowContainer |
| `isPhotoPickerPresented` | MenuDishFlowContainer |
| `archiveConfirmationPresented` | MenuDishFlowContainer |
| `currentCameraSessionID` | MenuDishFlowContainer |
| `isRestartingCamera` | MenuDishFlowContainer |
| `draft` | MenuDishFlowContainer |
| `imageCoordinator` | MenuDishFlowContainer |

---

### Menu 流程状态图

```
MenuView
  │
  ├─ 点击"新增" → MenuDishFlowContainer(.add)
  │   │
  │   ├─ MenuDishFormScreen
  │   │   ├─ 点击"拍照" → Camera → Crop(.camera) → 返回 Form
  │   │   ├─ 点击"相册" → PhotoPicker → Crop(.photoLibrary) → 返回 Form
  │   │   └─ 点击"保存" → Store.addDish → 完成
  │   │
  │   └─ 点击"删除"（编辑模式）→ 确认 → Store.archiveDish → 完成
  │
  └─ 点击购物车 → MenuCartSheet
```

---

### 验证清单

- [ ] 搜索功能正常（防抖 250ms）
- [ ] 分类筛选正常
- [ ] 分页加载正常（12 道/页）
- [ ] 加菜功能正常（+/- 按钮）
- [ ] 编辑菜品流程正常
- [ ] 相机流程正常（拍照→裁图→确认）
- [ ] 相册流程正常（选图→相册→确认）
- [ ] 购物车 sheet 展示正常
- [ ] 下单功能正常
- [ ] Preview 覆盖：搜索头部、购物车条、流程容器主要节点

---

## 依赖顺序

```
Orders 重构
├── OrdersModalRoute.swift（无依赖）
├── OrderItemRow.swift（无依赖）
├── ShoppingListSheet.swift（依赖 OrderItemRow？不，独立）
└── OrdersView.swift（依赖以上所有）

Settings 重构
├── SettingsModalRoute.swift（无依赖）
├── ThemeSelectionRow.swift（无依赖）
├── InviteCodeCard.swift（无依赖）
├── MemberAvatarStrip.swift（依赖 ThemeSelectionRow？不，独立）
├── MemberRoleSheet.swift（依赖 AppStore）
├── KitchenInfoCard.swift（依赖 MemberAvatarStrip, InviteCodeCard）
├── PreferencesSection.swift（依赖 ThemeSelectionRow）
└── SettingsView.swift（依赖以上所有）

Onboarding 重构
├── OnboardingState.swift（无依赖）
├── OnboardingValidationHelper.swift（无依赖）
├── KitchenModeToggle.swift（依赖 OnboardingState）
├── OnboardingSubmitBar.swift（无依赖）
├── AuthForm.swift（依赖 OnboardingState, OnboardingValidationHelper）
├── KitchenForm.swift（依赖 OnboardingState, OnboardingValidationHelper）
└── OnboardingView.swift（依赖以上所有）

Menu 重构
├── MenuModalRoute.swift（已存在 MenuSupport）
├── MenuDishFlowState.swift（无依赖）
├── MenuDishFlowImagePickerSection.swift（依赖 DishImageCoordinator）
├── MenuDishFormScreen.swift（依赖 MenuDishFlowImagePickerSection, AddDishDraft）
├── MenuDishFlowContainer.swift（依赖 MenuDishFormScreen, DishImageCoordinator）
├── MenuSearchBar.swift（无依赖）
├── MenuCartBar.swift（依赖 AppStore）
├── MenuDishGridView.swift（依赖 MenuDishCard）
├── MenuEmptyStateView.swift（无依赖）
├── MenuCartSheet.swift（已存在）
└── MenuView.swift（依赖以上所有）
```

---

## 最终验收

- [ ] iOS 工程编译通过
- [ ] 现有 Store 测试通过
- [ ] 所有入口文件行数 < 150 行
- [ ] 所有 subview 文件有可运行的 Preview
- [ ] 无循环依赖

---

## 备注

- 每个 feature 拆完后立即验证，不等到最后
- 如果拆分过程中发现某个 subview 过于复杂，继续向下拆分
- 保持视觉行为不变，只做代码重组，不做设计修改
