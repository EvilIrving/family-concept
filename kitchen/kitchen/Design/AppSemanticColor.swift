import SwiftUI

/// 语义色：UI 代码唯一允许消费的颜色层。
/// 设计原则：
/// - 主交互在 `green600`（中深叶绿），按下加深到 `green700`，禁用退到中性灰。
/// - 背景/表面走灰阶顶部三档，让卡片层级控制在 3–4 层内。
/// - 成功复用品牌绿；警告/错误/提示走独立 hue，但饱和度均经过协调。
/// - Cream/apricot 仅用于 badge、chip、提醒态浅底等小面积装饰。
enum AppSemanticColor {
    // MARK: - Brand / Interactive
    static let primary                     = AppPalette.green600
    static let primaryPressed              = AppPalette.green700
    static let primaryDisabled             = AppPalette.gray200
    static let onPrimary                   = AppPalette.pureWhite

    static let interactiveSecondary        = AppPalette.green100
    static let interactiveSecondaryPressed = AppPalette.green200

    static let brandAccent                 = AppPalette.green500

    // MARK: - Background & Surface
    static let background          = AppPalette.gray50
    static let backgroundElevated  = AppPalette.gray100
    static let surface             = AppPalette.pureWhite
    static let surfaceSecondary    = AppPalette.gray100
    static let surfaceTertiary     = AppPalette.gray200

    // MARK: - Text
    static let textPrimary   = AppPalette.inkBlack
    static let textSecondary = AppPalette.gray600
    static let textTertiary  = AppPalette.gray400

    // MARK: - Border / Divider
    static let border  = AppPalette.gray200
    static let divider = AppPalette.gray300

    // MARK: - Status (foreground)
    static let success       = AppPalette.green600
    static let warning       = AppPalette.warning
    static let danger        = AppPalette.danger
    static let dangerPressed = AppPalette.danger

    // MARK: - Status (background)
    static let successBackground = AppPalette.green100
    static let warningBackground = AppPalette.warningSoft
    static let dangerBackground  = AppPalette.dangerSoft
    static let infoBackground    = AppPalette.infoSoft
    static let infoForeground    = AppPalette.info

    // MARK: - Pending（低优先级提醒，用米杏点缀）
    static let pendingForeground = AppPalette.gray800
    static let pendingBackground = AppPalette.cream

    static let warmAccent = AppPalette.apricot

    // MARK: - Overlay & Shadow
    static let scrim        = AppPalette.gray900.opacity(0.32)
    static let shadowSubtle = AppPalette.green900.opacity(AppOpacity.subtleShadow)
    static let shadowCard   = AppPalette.green900.opacity(AppOpacity.cardShadow)
    static let shadowSheet  = AppPalette.green900.opacity(AppOpacity.sheetShadow)

    // MARK: - Toast
    static let toastBackground = AppPalette.green800
    static let toastAccent     = AppPalette.green300

    // MARK: - Camera / Crop（相机相关用非自适应的纯黑/纯白，避免暗色模式被反转）
    static let cameraBackdrop              = AppPalette.pureBlack
    static let cropBackdropGradientCenter  = AppPalette.green900
    static let cropBackdropGradientEdge    = AppPalette.pureBlack
    static let cropOverlay                 = AppPalette.pureBlack.opacity(0.55)
    static let cropViewportBorder          = AppPalette.pureWhite.opacity(0.85)
    static let cropViewportShadow          = AppPalette.pureBlack.opacity(0.45)
    static let cropControlForeground       = AppPalette.pureWhite
    static let cropControlBorder           = AppPalette.pureWhite.opacity(0.55)
    static let cropConfirmBackground       = AppPalette.pureWhite
    static let cropConfirmForeground       = AppPalette.pureBlack
}
