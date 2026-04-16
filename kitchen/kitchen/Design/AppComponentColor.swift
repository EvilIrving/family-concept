import SwiftUI

enum AppComponentColor {
    enum Button {
        static let primaryBackground = AppSemanticColor.primary
        static let primaryBackgroundPressed = AppSemanticColor.primaryPressed
        static let primaryBackgroundDisabled = AppSemanticColor.primaryDisabled
        static let primaryText = AppSemanticColor.onPrimary

        static let secondaryBackground = AppSemanticColor.interactiveSecondary
        static let secondaryBackgroundPressed = AppSemanticColor.interactiveSecondaryPressed
        static let secondaryBackgroundDisabled = AppSemanticColor.primaryDisabled
        static let secondaryText = AppSemanticColor.primary

        static let ghostBackground = AppSemanticColor.surface
        static let ghostBackgroundPressed = AppSemanticColor.surfaceSecondary
        static let ghostBorder = AppSemanticColor.border
        static let ghostText = AppSemanticColor.textPrimary

        static let destructiveBackground = AppSemanticColor.dangerBackground
        static let destructiveBackgroundPressed = AppSemanticColor.dangerPressed
        static let destructiveText = AppSemanticColor.danger
    }

    enum Card {
        static let background = AppSemanticColor.surface
        static let border = AppSemanticColor.border
        static let eyebrow = AppSemanticColor.brandAccent
    }

    enum Input {
        static let background = AppSemanticColor.surfaceSecondary
        static let border = AppSemanticColor.border
        static let placeholder = AppSemanticColor.textTertiary
        static let text = AppSemanticColor.textPrimary
        static let cursor = AppSemanticColor.primary
    }

    enum IconActionButton {
        static let neutralForeground = AppSemanticColor.textPrimary
        static let neutralBackground = AppSemanticColor.surfaceSecondary
        static let neutralBorder = AppSemanticColor.border

        static let brandForeground = AppSemanticColor.onPrimary
        static let brandBackground = AppSemanticColor.primary

        static let dangerForeground = AppSemanticColor.danger
        static let dangerBackground = AppSemanticColor.dangerBackground

        static let disabledForeground = AppSemanticColor.textTertiary
        static let disabledBackground = AppSemanticColor.surfaceTertiary
        static let disabledBorder = AppSemanticColor.border
    }

    enum FloatingButton {
        static let background = AppSemanticColor.primary
        static let foreground = AppSemanticColor.onPrimary
        static let badgeBackground = AppSemanticColor.danger
        static let badgeForeground = AppSemanticColor.onPrimary
    }

    enum Feedback {
        static let successBackground = AppSemanticColor.successBackground
        static let warningBackground = AppSemanticColor.warningBackground
        static let dangerBackground = AppSemanticColor.dangerBackground
        static let infoBackground = AppSemanticColor.infoBackground
        static let infoForeground = AppSemanticColor.infoForeground
    }

    enum Overlay {
        static let scrim = AppSemanticColor.scrim
    }

    enum Toast {
        static let background = AppSemanticColor.toastBackground
        static let foreground = AppSemanticColor.onPrimary
        static let accent = AppSemanticColor.toastAccent
    }

    enum Cropper {
        static let backdrop = AppSemanticColor.cameraBackdrop
        static let overlay = AppSemanticColor.cropOverlay
        static let viewportBorder = AppSemanticColor.cropViewportBorder
        static let viewportShadow = AppSemanticColor.cropViewportShadow
        static let controlForeground = AppSemanticColor.cropControlForeground
        static let controlBorder = AppSemanticColor.cropControlBorder
        static let confirmBackground = AppSemanticColor.cropConfirmBackground
        static let confirmForeground = AppSemanticColor.cropConfirmForeground
    }
}
