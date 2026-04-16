# Design — Token 规范

## 概述

Design 目录是全局视觉语言的唯一来源。UI 代码通过 token 使用设计决策，不直接写具体数值或颜色。本文件覆盖颜色、间距、字体、阴影、动效的所有规范。

---

## 文件职责

| 文件 | 职责 |
|---|---|
| `AppColor.swift` | 调色板（Palette）+ 语义色（Semantic）+ 组件态 |
| `AppTypography.swift` | 字体层级 token |
| `AppLayoutToken.swift` | 间距、内边距、圆角、尺寸、图标尺寸 |
| `AppStyleToken.swift` | 阴影、透明度、动效、材质 |
| `AppThemeExtensions.swift` | View 扩展（`.appPageBackground()`、`.appShadow()`） |

---

## 颜色体系

### 分层结构

```
Palette → Semantic → UI 使用
```

三层严格单向依赖，禁止越层引用。

#### 1. Palette（基础色）

定义纯颜色值，不带语义，**禁止在 UI 中直接使用**。

```swift
// AppColor.swift — Palette 区域
static let green900 = Color("green900")
static let green800 = Color("green800")
static let green500 = Color("green500")
static let green100 = Color("green100")
```

所有 Palette 颜色在 `Assets.xcassets` 中定义 light / dark 两套值，代码只写 `Color("名称")`，不写 hex / RGB。

#### 2. Semantic（语义色）

描述用途，**UI 代码唯一允许使用的颜色层**。

```swift
// AppColor.swift — 当前语义色

// 背景层
AppColor.backgroundBase        // 页面底层背景
AppColor.backgroundElevated    // 浮层、sheet 背景

// 表面层
AppColor.surfacePrimary        // 卡片、输入框背景
AppColor.surfaceSecondary      // 列表行、次级容器
AppColor.surfaceTertiary       // 禁用态填充

// 分割线
AppColor.lineSoft              // 弱分割（section 分隔）
AppColor.lineStrong            // 强分割（跨区域）

// 文字
AppColor.textPrimary           // 正文、主标题
AppColor.textSecondary         // 辅助说明
AppColor.textTertiary          // 占位符、标签
AppColor.textOnBrand           // 品牌色背景上的文字

// 交互
AppColor.interactivePrimary         // 主操作按钮背景（normal）
AppColor.interactivePrimaryPressed  // 主操作按钮背景（pressed）
AppColor.interactiveSecondary       // 次级操作、chip 背景
AppColor.interactiveDisabled        // 禁用态背景

// 状态
AppColor.success      // 成功（绿色，深）
AppColor.successSoft  // 成功背景（浅绿）
AppColor.warning      // 警告（黄色）
AppColor.warningSoft  // 警告背景
AppColor.danger       // 错误 / 破坏性操作
AppColor.dangerSoft   // 错误背景
AppColor.info         // 提示
AppColor.infoSoft     // 提示背景

// 特殊
AppColor.focusRing        // 焦点环
AppColor.scrim            // 遮罩
AppColor.toastBackground  // Toast 背景
```

#### 3. Component Tokens（组件态）

通过语义色推导，写在各组件自身文件内，不单独汇总。

```swift
// 示例：ButtonView 内部
private var background: Color {
    isDisabled ? AppColor.interactiveDisabled : AppColor.interactivePrimary
}
private var foreground: Color {
    isDisabled ? AppColor.textTertiary : AppColor.textOnBrand
}
```

---

### Light / Dark 实现规则

- 所有颜色在 `Assets.xcassets` 定义 **Any / Dark** 两套
- 代码只写 `Color("tokenName")`，**禁止**在代码中判断 `colorScheme`：

```swift
// ✅ 正确
.foregroundStyle(AppColor.textPrimary)

// ❌ 禁止
@Environment(\.colorScheme) var colorScheme
let color = colorScheme == .dark ? Color.white : Color.black
```

---

### 颜色使用规则

| 规则 | 说明 |
|---|---|
| UI 禁用 Palette | 不写 `AppColor.green800`、`Color("green500")` 等 |
| UI 禁用 hex/RGB | 不写 `.foregroundStyle(Color(hex: "#1a7a3c"))` |
| 不允许内联计算颜色 | 组件内部不自行 `.opacity()` 推导新语义，走现有 token |
| 状态必须有 token | pressed / disabled 不用 `.opacity(0.5)` 代替，使用 `interactivePrimaryPressed` 等 |
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
            AsyncImage(url: dish.imageURL)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))

            VStack(alignment: .leading, spacing: AppGap.tight) {
                Text(dish.name)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColor.textPrimary)

                Text(dish.description)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Text("¥\(dish.price)")
                .font(AppTypography.bodyStrong)
                .foregroundStyle(
                    isDisabled ? AppColor.textTertiary : AppColor.interactivePrimary
                )
        }
        .padding(AppInset.card)
        .background(AppColor.surfacePrimary)
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
        .foregroundStyle(AppColor.textOnBrand)
        .frame(maxWidth: .infinity)
        .frame(height: AppDimension.buttonHeight)
        .background(isPressed ? AppColor.interactivePrimaryPressed : AppColor.interactivePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.pill))
}
.animation(AppMotion.press, value: isPressed)
```

```swift
// 错误提示 banner
if let error = store.error {
    HStack(spacing: AppGap.compact) {
        Image(systemName: "exclamationmark.circle.fill")
            .foregroundStyle(AppColor.danger)
        Text(error.localizedDescription)
            .font(AppTypography.caption)
            .foregroundStyle(AppColor.danger)
    }
    .padding(.horizontal, AppInset.pageHorizontal)
    .padding(.vertical, AppSpacing.xs)
    .background(AppColor.dangerSoft)
    .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
}
```

---

## 新增 Token 规则

1. **Palette**：在 `Assets.xcassets` 添加 Color Set，同时提供 Any / Dark 两套值，在 `AppColor.swift` Palette 区域声明静态属性
2. **Semantic**：在 `AppColor.swift` Semantic 区域声明，必须映射到现有 Palette，并在本文件语义色列表中补充说明
3. **禁止**为一次性用途造新语义名；不确定时先复用最接近的现有 token

---

## 反模式（禁止）

```swift
// ❌ 直接使用 Palette
.foregroundStyle(AppColor.green800)

// ❌ 直接写颜色值
.background(Color(red: 0.1, green: 0.5, blue: 0.3))

// ❌ 代码内判断暗色模式
@Environment(\.colorScheme) var colorScheme
.foregroundStyle(colorScheme == .dark ? .white : .black)

// ❌ 自行推导状态色
.background(AppColor.interactivePrimary.opacity(0.5))

// ❌ 直接写数值
.padding(14)
.font(.system(size: 13))
.cornerRadius(10)
```
