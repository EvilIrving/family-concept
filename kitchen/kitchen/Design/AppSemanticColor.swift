import SwiftUI

enum AppSemanticColor {
    // MARK: - Brand / Interactive

    static let primary = AppPalette.green800
    static let primaryPressed = AppPalette.green900
    static let primaryDisabled = AppPalette.gray200
    static let onPrimary = AppPalette.gray000

    static let interactiveSecondary = AppPalette.green100
    static let interactiveSecondaryPressed = AppPalette.green200

    static let brandAccent = AppPalette.green700

    // MARK: - Background & Surface

    static let background = AppPalette.gray050
    static let backgroundElevated = AppPalette.gray100
    static let surface = AppPalette.gray000
    static let surfaceSecondary = AppPalette.gray100
    static let surfaceTertiary = AppPalette.gray200

    // MARK: - Text

    static let textPrimary = AppPalette.gray900
    static let textSecondary = AppPalette.gray600
    static let textTertiary = AppPalette.gray500

    // MARK: - Border & Divider

    static let border = AppPalette.gray200
    static let divider = AppPalette.gray300

    // MARK: - Status (foreground)

    static let success = AppPalette.green800
    static let warning = AppPalette.yellow500
    static let danger = AppPalette.red500
    static let dangerPressed = AppPalette.red500

    // MARK: - Status (background)

    static let successBackground = AppPalette.green100
    static let warningBackground = AppPalette.yellow100
    static let dangerBackground = AppPalette.red100
    static let infoBackground = AppPalette.green100
    static let infoForeground = AppPalette.green700

    // MARK: - Overlay & Special

    static let scrim = AppPalette.green900.opacity(0.12)
    static let shadowSubtle = AppPalette.green900.opacity(AppOpacity.subtleShadow)
    static let shadowCard = AppPalette.green900.opacity(AppOpacity.cardShadow)
    static let shadowSheet = AppPalette.green900.opacity(AppOpacity.sheetShadow)

    static let toastBackground = AppPalette.green900
    static let toastAccent = AppPalette.green300

    // MARK: - Camera / Crop

    static let cameraBackdrop = AppPalette.gray900
    static let cropBackdropGradientCenter = AppPalette.green900
    static let cropBackdropGradientEdge = AppPalette.gray900
    static let cropOverlay = AppPalette.gray900.opacity(0.55)
    static let cropViewportBorder = AppPalette.gray000.opacity(0.85)
    static let cropViewportShadow = AppPalette.gray900.opacity(0.45)
    static let cropControlForeground = AppPalette.gray000
    static let cropControlBorder = AppPalette.gray000.opacity(0.55)
    static let cropConfirmBackground = AppPalette.gray000
    static let cropConfirmForeground = AppPalette.gray900
}
