import SwiftUI

enum AppShadow {
    struct Token {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    static let card = Token(color: AppSemanticColor.shadowCard, radius: 18, x: 0, y: 6)
    static let sheet = Token(color: AppSemanticColor.shadowSheet, radius: 28, x: 0, y: 12)
    static let floating = Token(color: AppSemanticColor.shadowCard, radius: 10, x: 0, y: 6)

    static let cardColor = card.color
    static let sheetColor = sheet.color
}

enum AppOpacity {
    static let pressed: Double = 0.92
    static let subtleShadow: Double = 0.06
    static let cardShadow: Double = 0.08
    static let sheetShadow: Double = 0.12
    static let disabled: Double = 0.45
}

enum AppMotion {
    static let quick: Double = 0.16
    static let standard: Double = 0.2

    static let press = Animation.easeOut(duration: quick)
    static let standardEase = Animation.easeInOut(duration: standard)

    // Launch screen animations
    static let launchPulse = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
    static let launchRotate = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
}

enum AppMaterial {
    static let bottomBar: Material = .regularMaterial
    static let sheetBackground = AppSemanticColor.surface
}
