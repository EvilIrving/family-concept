import SwiftUI

struct MenuDishGridSkeletonView: View {
    private let gridColumns = [
        GridItem(.flexible(), spacing: AppSpacing.md),
        GridItem(.flexible(), spacing: AppSpacing.md)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: gridColumns, spacing: AppSpacing.md) {
                ForEach(0..<6, id: \.self) { _ in
                    MenuDishCardSkeleton()
                }
            }
            .padding(AppSpacing.md)
            .padding(.bottom, AppSpacing.md)
        }
        .scrollDisabled(true)
        .accessibilityHidden(true)
        .shimmering()
    }
}

private struct MenuDishCardSkeleton: View {
    var body: some View {
        AppCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                UnevenRoundedRectangle(
                    topLeadingRadius: AppRadius.md,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: AppRadius.md,
                    style: .continuous
                )
                .fill(AppSemanticColor.textSecondary.opacity(0.12))
                .frame(height: AppDimension.dishArtworkHeight)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .fill(AppSemanticColor.textSecondary.opacity(0.12))
                        .frame(height: 16)
                        .frame(maxWidth: .infinity)

                    HStack {
                        Spacer()
                        RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                            .fill(AppSemanticColor.textSecondary.opacity(0.12))
                            .frame(width: AppDimension.iconButtonSide, height: AppDimension.iconButtonSide)
                    }
                }
                .padding(AppSpacing.sm)
            }
        }
    }
}

#Preview {
    MenuDishGridSkeletonView()
        .background(AppSemanticColor.background)
}
