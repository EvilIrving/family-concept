import SwiftUI

struct FloatButton: View {
    enum Kind {
        case icon
        case extended(String)
    }

    let systemImage: String
    var kind: Kind = .icon
    var badgeCount: Int? = nil
    var haptic: AppHapticIntent = .medium
    var action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.fire(haptic)
            action()
        } label: {
            Group {
                switch kind {
                case .icon:
                    Image(systemName: systemImage)
                        .font(.system(size: AppIconSize.md, weight: .bold))
                        .foregroundStyle(AppComponentColor.FloatingButton.foreground)
                        .frame(width: AppDimension.floatingButtonHeight, height: AppDimension.floatingButtonHeight)
                        .background(AppComponentColor.FloatingButton.background, in: Circle())
                case let .extended(title):
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: systemImage)
                            .font(.system(size: AppIconSize.md, weight: .bold))
                        Text(title)
                            .font(AppTypography.bodyStrong)
                    }
                    .foregroundStyle(AppComponentColor.FloatingButton.foreground)
                    .padding(.horizontal, AppSpacing.lg)
                    .frame(height: AppDimension.floatingButtonHeight)
                    .background(AppComponentColor.FloatingButton.background, in: Capsule())
                }
            }
            .overlay(alignment: .topTrailing) {
                if let badgeCount, badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: AppIconSize.xxs + 1, weight: .bold))
                        .foregroundStyle(AppComponentColor.FloatingButton.badgeForeground)
                        .padding(.horizontal, AppInset.badgeHorizontal)
                        .frame(minWidth: AppDimension.badgeMinSide, minHeight: AppDimension.badgeMinSide)
                        .background(AppComponentColor.FloatingButton.badgeBackground, in: Capsule())
                        .offset(x: AppInset.badgeHorizontal, y: -AppInset.badgeHorizontal)
                }
            }
            .appShadow(AppShadow.floating)
        }
        .buttonStyle(.plain)
    }
}
