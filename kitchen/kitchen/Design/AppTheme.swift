import SwiftUI

enum AppColor {
    static let green900 = Color(hex: 0x1F4D3A)
    static let green800 = Color(hex: 0x2D6A4F)
    static let green700 = Color(hex: 0x3F8A67)
    static let green500 = Color(hex: 0x78B798)
    static let green300 = Color(hex: 0xBFE3CF)
    static let green200 = Color(hex: 0xDCEFE3)
    static let green100 = Color(hex: 0xEEF7F1)

    static let backgroundBase = Color(hex: 0xF4F8F5)
    static let backgroundElevated = Color(hex: 0xFAFCFA)
    static let surfacePrimary = Color.white
    static let surfaceSecondary = Color(hex: 0xF7FAF7)
    static let surfaceTertiary = Color(hex: 0xF1F5F1)
    static let lineSoft = Color(hex: 0xE3EBE4)
    static let lineStrong = Color(hex: 0xD2DDD4)

    static let textPrimary = Color(hex: 0x1E2A22)
    static let textSecondary = Color(hex: 0x5F6F64)
    static let textTertiary = Color(hex: 0x8A968E)
    static let textOnBrand = Color.white

    static let success = green800
    static let successSoft = Color(hex: 0xE7F4EC)
    static let warning = Color(hex: 0xC98A2E)
    static let warningSoft = Color(hex: 0xFAF0DE)
    static let danger = Color(hex: 0xD85C4A)
    static let dangerSoft = Color(hex: 0xFCE9E6)
    static let info = Color(hex: 0x5F8F7A)
    static let infoSoft = Color(hex: 0xEAF4EF)
}

enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum AppRadius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 28
    static let pill: CGFloat = 999
}

enum AppShadow {
    static let cardColor = AppColor.green900.opacity(0.08)
    static let sheetColor = AppColor.green900.opacity(0.12)
}

enum AppTypography {
    static let pageTitle = Font.system(size: 28, weight: .semibold)
    static let sectionTitle = Font.system(size: 20, weight: .semibold)
    static let cardTitle = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 15)
    static let bodyStrong = Font.system(size: 15, weight: .semibold)
    static let caption = Font.system(size: 13)
    static let micro = Font.system(size: 12, weight: .medium)
    static let button = Font.system(size: 16, weight: .semibold)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

extension View {
    func appPageBackground() -> some View {
        background(AppColor.backgroundBase.ignoresSafeArea())
    }
}
