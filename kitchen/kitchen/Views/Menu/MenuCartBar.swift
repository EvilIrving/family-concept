import SwiftUI

struct MenuCartBar: View {
    let cartCount: Int
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppSemanticColor.border)
                .frame(height: 1)

            Button {
                onTap()
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: AppIconSize.md, weight: .semibold))
                        .foregroundStyle(AppSemanticColor.primary)

                    Text("已选 \(cartCount) 道菜")
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppSemanticColor.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: AppIconSize.xs, weight: .semibold))
                        .foregroundStyle(AppSemanticColor.textTertiary)
                }
                .padding(.horizontal, AppSpacing.md)
                .frame(maxWidth: .infinity, minHeight: AppDimension.toolbarButtonHeight, alignment: .leading)
                .background(AppSemanticColor.surface)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
