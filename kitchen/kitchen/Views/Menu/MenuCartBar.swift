import SwiftUI

struct MenuCartBar: View {
    let cartCount: Int
    let isCollapsed: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.fire(.medium)
            onTap()
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "cart.fill")
                    .font(.system(size: AppIconSize.lg, weight: .bold))

                Text("\(cartCount)")
                    .font(AppTypography.bodyStrong)
            }
            .foregroundStyle(AppComponentColor.FloatingButton.foreground)
            .padding(.horizontal, AppSpacing.lg)
            .frame(height: AppDimension.floatingButtonHeight)
            .background(AppComponentColor.FloatingButton.background, in: Capsule())
            .appShadow(AppShadow.floating)
        }
        .buttonStyle(.plain)
        .opacity(isCollapsed ? 0.2 : 1.0)
        .accessibilityLabel(L10n.tr("%lld selected", cartCount))
    }
}
