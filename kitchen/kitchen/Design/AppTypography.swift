import SwiftUI

/// 使用语义 text style，支持 Dynamic Type 与更稳定的层级关系。
enum AppTypography {
    static let pageTitle = Font.title.weight(.semibold)
    static let sectionTitle = Font.title3.weight(.semibold)
    static let cardTitle = Font.headline.weight(.semibold)
    static let body = Font.body
    static let bodyStrong = Font.body.weight(.semibold)
    static let caption = Font.caption
    static let micro = Font.caption2.weight(.medium)
    static let button = Font.body.weight(.semibold)

    static let tabLabel = Font.caption2.weight(.medium)
    static let chip = Font.caption
    static let badge = Font.caption2.weight(.bold)
    static let iconLabel = Font.footnote.weight(.semibold)
}
