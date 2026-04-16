import SwiftUI

/// 基础空间刻度。以 4pt 为基线，主节奏落在 8pt 系列。
enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

/// 语义内边距，减少页面里散落的“这个地方用 md，那个地方用 lg”。
enum AppInset {
    static let pageHorizontal = AppSpacing.md
    static let pageTop = AppSpacing.xs
    static let pageBottomWithFloatingBar: CGFloat = 110

    static let card = AppSpacing.md
    static let cardComfortable = AppSpacing.lg
    static let sheetHorizontal = AppSpacing.lg
    static let sheetBottom = AppSpacing.lg
    static let toolbarHorizontal = AppSpacing.lg

    static let chipHorizontal = AppSpacing.sm
    static let chipVertical: CGFloat = 6
    static let badgeHorizontal: CGFloat = 6

    static let buttonHorizontal = AppSpacing.md
    static let inputHorizontal = AppSpacing.md
}

/// 语义间距，用于组件内部与模块之间的布局关系。
enum AppGap {
    static let tight = AppSpacing.xxs
    static let compact = AppSpacing.xs
    static let control = AppSpacing.sm
    static let section = AppSpacing.md
    static let block = AppSpacing.lg
    static let page = AppSpacing.xl
}

enum AppRadius {
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 28
    static let pill: CGFloat = 999
}

enum AppBorderWidth {
    static let hairline: CGFloat = 1
    static let regular: CGFloat = 1.5
    static let strong: CGFloat = 2
}

enum AppDimension {
    static let minTouchTarget: CGFloat = 44
    static let listRowMinHeight: CGFloat = 44

    static let compactControlHeight: CGFloat = 32
    static let regularControlHeight: CGFloat = 44
    static let buttonHeight: CGFloat = 50
    static let textFieldHeight: CGFloat = 52
    static let floatingButtonHeight: CGFloat = 56
    static let tabBarItemHeight: CGFloat = 56

    static let iconButtonSide: CGFloat = 32
    static let avatar: CGFloat = 44
    static let badgeMinSide: CGFloat = 20

    static let divider: CGFloat = 1
    static let dragIndicatorWidth: CGFloat = 42
    static let dragIndicatorHeight: CGFloat = 5
    static let focusHitOutsetVertical = AppSpacing.xs
    static let focusHitOutsetHorizontal = AppSpacing.xxs
}

enum AppIconSize {
    static let xxs: CGFloat = 10
    static let xs: CGFloat = 12
    static let sm: CGFloat = 14
    static let md: CGFloat = 16
    static let lg: CGFloat = 18
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 22
    static let display: CGFloat = 28
}
