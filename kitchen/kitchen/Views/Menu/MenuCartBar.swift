import SwiftUI

struct MenuCartBar: View {
    let cartCount: Int
    let isCollapsed: Bool
    let onTap: () -> Void

    @State private var buttonWidth: CGFloat = 0

    private let trailingPadding = AppSpacing.md

    var body: some View {
        Button {
            HapticManager.shared.fire(.medium)
            onTap()
        } label: {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "cart.fill")
                    .font(.system(size: AppIconSize.lg, weight: .bold))

                Text("已选 \(cartCount) 道菜")
                    .font(AppTypography.bodyStrong)
                    .lineLimit(1)
            }
            .foregroundStyle(AppComponentColor.FloatingButton.foreground)
            .padding(.horizontal, AppSpacing.lg)
            .frame(height: AppDimension.floatingButtonHeight)
            .background(AppComponentColor.FloatingButton.background, in: Capsule())
            .appShadow(AppShadow.floating)
        }
        .buttonStyle(.plain)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        buttonWidth = proxy.size.width
                    }
                    .onChange(of: proxy.size.width) { _, width in
                        buttonWidth = width
                    }
            }
        }
        .offset(x: isCollapsed ? collapsedOffset : 0)
        .accessibilityLabel(L10n.tr("已选 %lld 道菜", cartCount))
    }

    private var collapsedOffset: CGFloat {
        guard buttonWidth > 0 else { return 0 }
        return max(buttonWidth + trailingPadding - buttonWidth / 3, 0)
    }
}
