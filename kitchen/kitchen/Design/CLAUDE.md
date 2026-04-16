# Design — Token 规范

## 概述

Design 目录是全局视觉语言的唯一来源。UI 代码通过 token 使用设计决策，不直接写具体数值或颜色。本文件覆盖颜色、间距、字体、阴影、动效的所有规范。

---

## 文件职责

| 文件 | 职责 |
|---|---|
| `AppPalette.swift` | 基础调色板，映射 `Assets.xcassets` 色值 |
| `AppSemanticColor.swift` | 语义色，供页面和组件直接消费 |
| `AppComponentColor.swift` | 组件态颜色，从语义色继续收束 |
| `AppTypography.swift` | 字体层级 token |
| `AppLayoutToken.swift` | 间距、内边距、圆角、尺寸、图标尺寸 |
| `AppStyleToken.swift` | 阴影、透明度、动效、材质 |
| `AppThemeExtensions.swift` | View 扩展（`.appPageBackground()`、`.appShadow()`） |

---

## 颜色体系

### 分层结构

```
Palette → Semantic → Component → UI 使用
```

四层严格单向依赖，禁止越层引用。

#### 1. Palette（基础色）

定义纯颜色值，不带语义，**禁止在 UI 中直接使用**。

```swift
// AppPalette.swift
static let green900 = Color("green900")
static let green800 = Color("green800")
static let green500 = Color("green500")
static let green100 = Color("green100")
```

所有 Palette 颜色在 `Assets.xcassets` 中定义 light / dark 两套值，代码只写 `Color("名称")`，不写 hex / RGB。

#### 2. Semantic（语义色）

描述用途，**UI 代码唯一允许使用的颜色层**。

```swift
// AppSemanticColor.swift

// 背景层
AppSemanticColor.background         // 页面底层背景
AppSemanticColor.backgroundElevated // 浮层、sheet 背景

// 表面层
AppSemanticColor.surface          // 卡片、输入框背景
AppSemanticColor.surfaceSecondary // 列表行、次级容器
AppSemanticColor.surfaceTertiary  // 禁用态填充

// 分割线
AppSemanticColor.border   // 弱分割和常规描边
AppSemanticColor.divider  // 强分割（跨区域）

// 文字
AppSemanticColor.textPrimary   // 正文、主标题
AppSemanticColor.textSecondary // 辅助说明
AppSemanticColor.textTertiary  // 占位符、标签
AppSemanticColor.onPrimary     // 品牌色背景上的文字

// 交互
AppSemanticColor.primary                     // 主操作按钮背景（normal）
AppSemanticColor.primaryPressed              // 主操作按钮背景（pressed）
AppSemanticColor.primaryDisabled             // 禁用态背景
AppSemanticColor.interactiveSecondary        // 次级操作、chip 背景
AppSemanticColor.interactiveSecondaryPressed // 次级操作按下态

// 状态
AppSemanticColor.success           // 成功（绿色，深）
AppSemanticColor.successBackground // 成功背景（浅绿）
AppSemanticColor.warning           // 警告（黄色）
AppSemanticColor.warningBackground // 警告背景
AppSemanticColor.danger            // 错误 / 破坏性操作
AppSemanticColor.dangerBackground  // 错误背景
AppSemanticColor.infoForeground    // 提示前景
AppSemanticColor.infoBackground    // 提示背景

// 特殊
AppSemanticColor.brandAccent     // 品牌强调
AppSemanticColor.scrim           // 遮罩
AppSemanticColor.toastBackground // Toast 背景
```

#### 3. Component Tokens（组件态）

通过语义色推导，统一写在 `AppComponentColor.swift`，组件按需消费对应命名空间。

```swift
// 示例：AppComponentColor.Button
static let primaryBackground = AppSemanticColor.primary
static let primaryBackgroundPressed = AppSemanticColor.primaryPressed
static let primaryBackgroundDisabled = AppSemanticColor.primaryDisabled
static let primaryText = AppSemanticColor.onPrimary
```

---

### Light / Dark 实现规则

- 所有颜色在 `Assets.xcassets` 定义 **Any / Dark** 两套
- 代码只写 `Color("tokenName")`，**禁止**在代码中判断 `colorScheme`：

```swift
// ✅ 正确
.foregroundStyle(AppSemanticColor.textPrimary)

// ❌ 禁止
@Environment(\.colorScheme) var colorScheme
let color = colorScheme == .dark ? Color.white : Color.black
```

---

### 颜色使用规则

| 规则 | 说明 |
|---|---|
| UI 禁用 Palette | 不写 `AppPalette.green800`、`Color("green500")` 等 |
| UI 禁用 hex/RGB | 不写 `.foregroundStyle(Color(hex: "#1a7a3c"))` |
| 不允许内联计算颜色 | 组件内部不自行 `.opacity()` 推导新语义，走现有 token |
| 状态必须有 token | pressed / disabled 不用 `.opacity(0.5)` 代替，使用 `primaryPressed`、`primaryDisabled` 等 |
| 颜色不是唯一信息通道 | 状态差异需同时配图标或文字（无障碍要求） |

---

## 间距体系（AppLayoutToken.swift）

### 基础刻度（AppSpacing）

4pt 基线，主节奏 8pt 系列：

```
xxs=4  xs=8  sm=12  md=16  lg=20  xl=24  xxl=32
```

### 语义内边距（AppInset）

```swift
AppInset.pageHorizontal   // 页面左右边距 = md(16)
AppInset.card             // 卡片内边距 = md(16)
AppInset.sheetHorizontal  // Sheet 左右边距 = lg(20)
AppInset.buttonHorizontal // 按钮左右内边距 = md(16)
```

### 语义间距（AppGap）

```swift
AppGap.tight    // 4  — icon 与文字间距
AppGap.compact  // 8  — 列表行内元素
AppGap.control  // 12 — 表单控件间距
AppGap.section  // 16 — 卡片内分组间距
AppGap.block    // 20 — 页面内模块间距
AppGap.page     // 24 — 主要区块间距
```

### 圆角（AppRadius）

```swift
AppRadius.sm   // 12 — chip、badge
AppRadius.md   // 16 — 卡片、输入框
AppRadius.lg   // 20 — 底部 sheet 顶部圆角
AppRadius.pill // 999 — 全圆角按钮、标签
```

### 尺寸（AppDimension）

```swift
AppDimension.minTouchTarget      // 44 — 最小触控目标（强制）
AppDimension.buttonHeight        // 50 — 标准按钮高度
AppDimension.textFieldHeight     // 52 — 输入框高度
AppDimension.floatingButtonHeight // 56 — 浮动按钮（FAB）
```

---

## 字体体系（AppTypography.swift）

语义 text style，自动适配 Dynamic Type：

```swift
AppTypography.pageTitle    // title.semibold — 页面主标题
AppTypography.sectionTitle // title3.semibold — 区块标题
AppTypography.cardTitle    // headline.semibold — 卡片标题
AppTypography.body         // body — 正文
AppTypography.bodyStrong   // body.semibold — 强调正文
AppTypography.caption      // caption — 辅助说明
AppTypography.button       // body.semibold — 按钮文字
AppTypography.chip         // caption — 筛选标签
AppTypography.badge        // caption2.bold — 数字徽章
```

**禁止**在 UI 中写 `.font(.system(size: 14))`，所有字体走 `AppTypography`。

---

## 阴影与动效（AppStyleToken.swift）

### 阴影（AppShadow）

```swift
AppShadow.card      // 卡片阴影：radius 18，y 6
AppShadow.sheet     // Sheet 阴影：radius 28，y 12
AppShadow.floating  // 浮动元素：radius 10，y 6

// 用法
.appShadow(AppShadow.card)
```

### 透明度（AppOpacity）

```swift
AppOpacity.pressed       // 0.92 — 按压态整体透明度
AppOpacity.disabled      // 0.45 — 禁用态文字透明度
AppOpacity.cardShadow    // 0.08 — 卡片阴影颜色透明度
```

### 动效（AppMotion）

```swift
AppMotion.press         // easeOut 0.16s — 按压反馈
AppMotion.standardEase  // easeInOut 0.2s — 通用转场
```

---

## View 扩展（AppThemeExtensions.swift）

```swift
// 页面底层背景（自动 ignoresSafeArea）
.appPageBackground()

// 语义阴影
.appShadow(AppShadow.card)
.appShadow(AppShadow.floating)
```

---

## 完整使用示例

```swift
struct DishCard: View {
    let dish: Dish
    var isDisabled: Bool = false

    var body: some View {
        HStack(spacing: AppGap.compact) {
            AsyncImage(url: dish.publicImageURL(baseURL: DishImageSpec.r2PublicBaseURL))
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))

            VStack(alignment: .leading, spacing: AppGap.tight) {
                Text(dish.name)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppSemanticColor.textPrimary)

                Text(dish.category)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Text("\(dish.ingredients.count) 种食材")
                .font(AppTypography.bodyStrong)
                .foregroundStyle(
                    isDisabled ? AppSemanticColor.textTertiary : AppSemanticColor.primary
                )
        }
        .padding(AppInset.card)
        .background(AppSemanticColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
        .appShadow(AppShadow.card)
        .opacity(isDisabled ? AppOpacity.disabled : 1)
    }
}
```

```swift
// 主操作按钮（pressed 态）
Button(action: onTap) {
    Text("加入购物车")
        .font(AppTypography.button)
        .foregroundStyle(AppSemanticColor.onPrimary)
        .frame(maxWidth: .infinity)
        .frame(height: AppDimension.buttonHeight)
        .background(isPressed ? AppSemanticColor.primaryPressed : AppSemanticColor.primary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill))
}
.animation(AppMotion.press, value: isPressed)
```

```swift
// 错误提示 banner
if let error = store.error {
    HStack(spacing: AppGap.compact) {
        Image(systemName: "exclamationmark.circle.fill")
            .foregroundStyle(AppSemanticColor.danger)
        Text(error)
            .font(AppTypography.caption)
            .foregroundStyle(AppSemanticColor.danger)
    }
    .padding(.horizontal, AppInset.pageHorizontal)
    .padding(.vertical, AppSpacing.xs)
    .background(AppSemanticColor.dangerBackground)
    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
}
```

---

## 新增 Token 规则

1. **Palette**：在 `Assets.xcassets` 添加 Color Set，同时提供 Any / Dark 两套值，在 `AppPalette.swift` 声明静态属性
2. **Semantic**：在 `AppSemanticColor.swift` 声明，必须映射到现有 Palette，并在本文件语义色列表中补充说明
3. **Component**：跨组件复用的状态色写进 `AppComponentColor.swift` 对应命名空间
4. **禁止**为一次性用途造新语义名；不确定时先复用最接近的现有 token

---

## 反模式（禁止）

```swift
// ❌ 直接使用 Palette
.foregroundStyle(AppPalette.green800)

// ❌ 直接写颜色值
.background(Color(red: 0.1, green: 0.5, blue: 0.3))

// ❌ 代码内判断暗色模式
@Environment(\.colorScheme) var colorScheme
.foregroundStyle(colorScheme == .dark ? .white : .black)

// ❌ 自行推导状态色
.background(AppSemanticColor.primary.opacity(0.5))

// ❌ 直接写数值
.padding(14)
.font(.system(size: 13))
.cornerRadius(10)
```
