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
                .fill(.clear)
                .frame(height: AppDimension.dishArtworkHeight)
                .overlay {
                    SkeletonPrimitive(cornerRadius: AppRadius.md)
                }
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: AppRadius.md,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: AppRadius.md,
                        style: .continuous
                    )
                )

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SkeletonPrimitive(cornerRadius: AppRadius.sm)
                        .frame(height: 16)
                        .frame(maxWidth: .infinity)

                    SkeletonPrimitive(cornerRadius: AppRadius.sm)
                        .frame(width: 72, height: 14)

                    HStack {
                        SkeletonPrimitive(cornerRadius: AppRadius.sm)
                            .frame(width: AppDimension.iconButtonSide, height: AppDimension.iconButtonSide)

                        Spacer()

                        SkeletonPrimitive(cornerRadius: AppRadius.sm)
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
