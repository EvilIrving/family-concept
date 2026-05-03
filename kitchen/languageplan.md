# iOS App 多语言实施计划

## 目标

App UI 本地化为 **English / 简体中文 / 繁體中文 / 日本語 / 한국어**。
默认语言固定为 **English**，不跟随系统语言。
缺失翻译回退顺序：当前语言 → 英语 → key 原样返回。

---

## 已完成（Phase 1 — 基础设施 + Settings 入口）

### 1. 语言运行时
- `kitchen/Stores/AppLanguageStore.swift`
  - `AppLanguage` 枚举：`en` / `zh-Hans` / `zh-Hant` / `ja` / `ko`
  - `displayName` 始终用该语言自身的名字（English / 简体中文 / 繁體中文 / 日本語 / 한국어）
  - 通过 `UserDefaults` key `appLanguageCode` 持久化
  - 首次启动默认 `.english`，**不读系统语言**
- `kitchen/Stores/L10n.swift`
  - `L10n.tr(_ key:_ args:)` 显式查找：当前语言 → en → 返回 key
  - 适用于已解析为 `String` 的场景（Toast / alert / 模型显示名 / 服务兜底错误 / `accessibilityLabel(_ String)`）
  - SwiftUI `Text("...")` / `Button("...")` 等接收 `LocalizedStringKey` 的 API 由 `\.locale` 环境自动本地化，**不需要**调用 `L10n.tr`

### 2. App 根部 Locale 注入
- `kitchen/kitchenApp.swift`
  - 创建 `@StateObject AppLanguageStore`
  - `.environmentObject(languageStore)`
  - `.environment(\.locale, languageStore.locale)`
  - `.id(languageStore.language)` 强制全树在切换时重建

### 3. Xcode 工程配置
- `kitchen.xcodeproj/project.pbxproj`
  - `developmentRegion = zh-Hans`（源字符串语言；`Text("偏好设置")` 直接作为 key）
  - `knownRegions = (en, zh-Hans, zh-Hant, ja, ko, Base)`
- 工程使用 `PBXFileSystemSynchronizedRootGroup`，`Localizable.xcstrings` 放在 `kitchen/kitchen/` 即被自动加入 target，不需要额外注册

### 4. 字符串目录种子
- `kitchen/Localizable.xcstrings` 已收录 **27 条** key × 5 语言：
  - Settings 全套：偏好设置 / 通知 / 语言 / 触感反馈 / 外观 / 跟随系统 / 浅色 / 深色 / 会员套餐 / 帮助与反馈 / 意见反馈 / 账户与隐私 / 恢复购买 / 隐私说明 / 退出登录 / 确认退出 / 升级 / 不限菜品数量 / 稍后推出 / 已用 %lld / %lld 道
  - 通用按钮：取消 / 保存 / 关闭 / 删除
  - 通用状态：加载中 / 加载失败

### 5. 设置页语言选择器
- `kitchen/Views/Settings/PreferencesSection.swift`
  - 删除「稍后推出」占位行，替换为 `Picker` 绑定 `AppLanguageStore.language`
  - 5 个选项；切换后 SwiftUI 立刻刷新；持久化到 `UserDefaults`，重启保留
  - 不提供「跟随系统」
- `kitchen/Views/Settings/SettingsView.swift` Preview 注入 `AppLanguageStore`

### 6. 验证
- `xcodebuild build` 在真机 `00008150-0019546A2100401C` ✅ **BUILD SUCCEEDED**

---

## 翻译策略调整

为加快推进，Phase 2 各批次先只填 **en + zh-Hans** 两种语言，`zh-Hant / ja / ko` 留待统一二次校对补齐。
缺失语言通过 `L10n.tr` 的回退链（当前语言 → en → key 原样）自然降级到英语。

---

## 待完成（Phase 2 — 业务文案翻译）

总量预估：~150 条剩余硬编码字符串，分布在 ~17 个文件。
建议按下面的批次推进，每批结束后提交一次。

### ✅ 批次 A：Onboarding — 已完成
- 文件：`Views/Onboarding/OnboardingView.swift`、`AuthForm.swift`、`KitchenForm.swift`
- 新增 14 条 key（en + zh-Hans）：`用户名` / `密码` / `昵称` / `邀请码` / `私厨名称` / `登录` / `注册` / `还没有账号？注册` / `已有账号？登录` / `输入邀请码加入` / `创建私厨` / `登录并加入私厨` / `登录并创建私厨` / `创建新账号`
- 所有 String 参数（`AppTextField.title`、`AppLinkButton.title`、`AppSegmentedButton.Segment.title/accessibilityLabel`、`AppButton.title`）改走 `L10n.tr(...)`
- `OnboardingSubmitBar.swift` 与 `OnboardingValidationHelper.swift` 无用户可见字面量
- 顺手修复 `OrdersView.swift:23` 的预存编译错误（`AppLoadingBlock` 缺少 `skeletonView` 类型推断）：`skeletonView: nil as (() -> EmptyView)?`
- ✅ `xcodebuild build` 真机 `00008150-0019546A2100401C` BUILD SUCCEEDED
- 待跟进：`OnboardingView` 的 `store.error` 兜底（服务端原文目前直接展示，待批次 F 在 Store/Service 层走 `L10n.tr`）

### ✅ 批次 B：Menu — 已完成
- 文件：`Views/Menu/MenuView.swift`、`MenuSearchBar.swift`、`MenuCartBar.swift`、`MenuCartSheet.swift`、`MenuEmptyStateView.swift`、`AddDishFlow/*`、`DishImageFlow/*`
- 关键文案：全部 / 常用分类 / 主食 / 凉菜 / 家常菜 / 已选 N 道菜 / 下单 / 加菜 / 使用空格添加多个食材 / 待添加图片 / 使用框内图片 / 当前设备不可用相机 等
- 数量插值（"已选 %lld 道菜"）使用 `%lld` 占位符
- 用户可见硬编码已收口：`购物车是空的`、`常用分类`、`删除后会归档该菜品`、`删除菜品`、`关闭`、`取消`、`暂无图片` 改走 `L10n.tr(...)`
- `Localizable.xcstrings` 已将当前收录的非空 key 补齐到 en / zh-Hans / zh-Hant / ja / ko；翻译按目标语言语境调整，不做机械直译
- 业务数据继续原样展示：菜名、用户自定义分类、食材和服务端业务返回不翻译

### ✅ 批次 C：Orders — 已完成
- 文件：`Views/Orders/OrdersView.swift`、`OrderItemRow.swift`、`ShoppingListSheet.swift`、`OrderHistorySheet.swift`、`OrderHistoryDetailSheet.swift`、`OrderHistoryDetailRow.swift`
- 关键文案：待制作 / 制作中 / 已完成 / 已取消 / 这顿好了 / 历史订单 / 历史订单详情 / 所需菜品 / 刷新订单 / 刷新历史 / N 道菜 / N 份 等
- Toast：`已减少 %@ 1 份`、`已取消 %@`、`这顿收好了` 走 `L10n.tr(...)`
- 数量插值统一使用 `%lld` 占位符，菜名等业务数据继续原样展示
- 导出采购清单、历史订单日期展示改为按当前 App 语言使用本地化日期格式
- `ItemStatus.title` 与订单未知菜品兜底已改为模型层本地化
- `Localizable.xcstrings` 已补齐本批次 key 的 en / zh-Hans / zh-Hant / ja / ko 五语言翻译
- ✅ `xcodebuild build` iOS Simulator generic BUILD SUCCEEDED

### ✅ 批次 D：UI Components + Feedback — 已完成
- 文件：`UI/Components/*`、`UI/Feedback/AppToastModels.swift`
- Toast / Banner 文案；通用按钮文案；空态文案；加载/错误占位文案
- VoiceOver `accessibilityLabel(_ String)` 一律走 `L10n.tr`
- `AppLoading` 空态、错误占位、网络/鉴权/通用反馈默认文案已补齐五语言
- `AppLoadingBlock`、`RemoteDishImage` 的重试、加载和图片失败文案已改走 `L10n.tr`

### ✅ 批次 E：Settings 子页面 — 已完成
- 文件：`Views/Settings/UpgradeSheet.swift`、`FeedbackSheet.swift`、`KitchenInfoCard.swift`、`InviteCodeCard.swift`、`MemberAvatarStrip.swift`、`MemberRoleSheet.swift`、`ThemeSelectionRow.swift`
- 关键文案：升级 / 商品信息加载失败… / 当前已经是 Unlimited… / 复制邀请码 / 已复制邀请码 / 共 N 人 / 副管理员 / 已移除成员 / 已提交反馈 / 想提的需求和吐槽 等
- 自定义组件参数、Toast、加载 phase、无障碍标签和插值文案已统一走 `L10n.tr`
- `Localizable.xcstrings` 已补齐本批次 key 的 en / zh-Hans / zh-Hant / ja / ko 五语言翻译

### ✅ 批次 F：服务层 & 模型 — 已完成
- 文件：`Services/*`、`Models/*`、`Stores/AppStore+*.swift`
- 兜底错误文案、`PlanCode.displayName`、订单状态显示名等
- 业务数据（菜名、食材、分类、用户输入、服务端原文）**不翻译**
- `KitchenRole.title`、`PlanCode.displayName`、API 兜底错误、菜品图片状态和 AppStore 业务兜底错误已改走 `L10n.tr`
- 服务端原始业务 message 继续原样展示，不做客户端翻译

### ✅ 批次 G：Info.plist — 已完成
- 新建 `kitchen/InfoPlist.xcstrings`，键：
  - `CFBundleDisplayName`（食单）
  - `NSCameraUsageDescription`
  - `NSPhotoLibraryUsageDescription`
- 提供 5 语翻译；说明这层文案为 iOS 系统在装包时确定，**不承诺随 App 内 Picker 实时切换**
- 已新增 `kitchen/InfoPlist.xcstrings`，为 App 名称、相机权限、相册权限提供 en / zh-Hans / zh-Hant / ja / ko 五语言翻译

---

## 工程约定

- **新增用户可见字符串**：用中文写 `Text("…")`，然后在 `Localizable.xcstrings` 同步加入 `en / zh-Hans / zh-Hant / ja / ko` 五语言翻译
- **翻译质量要求**：翻译优先表达真实含义和界面意图，不做逐词直译；每种目标语言都应符合当地 App 文案习惯、文化语境和自然表达风格，必要时可调整句式、语气和信息顺序
- **resolved `String` 路径**（变量、Toast、alert message、`accessibilityLabel(_ String)`、模型显示名、服务兜底错误、所有接收 `String` 而非 `LocalizedStringKey` 的 UI 组件参数）：必须走 `L10n.tr("key", args)`，不要直接传中文字面量
- **业务数据**（菜名、食材、用户输入、服务端返回）：不翻译，原样展示
- **CLAUDE.md 同步**：`kitchen/CLAUDE.md` 现已规定「禁止硬编码任何用户可见展示字符串」「新增或修改任何用户可见文案时，必须同步新增或更新五语言本地化 key，并通过本地化资源引用展示」，本计划与之保持一致

---

## 测试清单（每批完成后跑一次）

- [ ] `xcodebuild build` 真机 `00008110-000A48C41141401E` 通过
- [ ] `xcodebuild test` 通过
- [ ] 五种 Picker 语言切换：UI 立即刷新
- [ ] 冷启动持久化：选定语言重启后保留
- [ ] 系统语言变化不影响 App 默认英语（首次安装系统为中文 → App 仍为英语）
- [ ] 缺失翻译路径：删一条非英语翻译 → 显示英语；再删英语 → 显示 key 原文（zh-Hans 即中文）
