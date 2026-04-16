import SwiftUI

struct MenuDishCard: View {
    let title: String
    let category: String
    var quantity: Int = 0
    var imageURL: URL? = nil
    var imageSystemName: String = "fork.knife"
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        AppCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                dishArtwork

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text(title)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppSemanticColor.textPrimary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Spacer()

                        HStack(spacing: 2) {
                            if quantity > 0 {
                                AppIconActionButton(
                                    systemImage: "minus",
                                    tone: .neutral,
                                    action: onDecrease
                                )

                                Text("\(quantity)")
                                    .font(AppTypography.bodyStrong)
                                    .foregroundStyle(AppSemanticColor.textPrimary)
                                    .frame(minWidth: AppDimension.quantityBadgeMinWidth)
                                    .frame(height: AppDimension.iconButtonSide)
                                    .padding(.horizontal, AppGap.tight / 2)
                            }

                            AppIconActionButton(
                                systemImage: "plus",
                                tone: .brand,
                                action: onIncrease
                            )
                        }
                    }
                }
                .padding(AppSpacing.sm)
            }
        }
    }

    private var dishArtwork: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: AppRadius.md,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: AppRadius.md,
            style: .continuous
        )
        .fill(
            LinearGradient(
                colors: [AppSemanticColor.interactiveSecondaryPressed, AppSemanticColor.interactiveSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(height: AppDimension.dishArtworkHeight)
        .overlay(alignment: .topTrailing) {
            AppPill(title: category)
                .padding(AppSpacing.sm)
        }
        .overlay {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(AppSpacing.xs)
                    case .empty:
                        AppLoadingBlock(label: "加载中", tone: .secondary)
                    default:
                        imageFailurePlaceholder
                    }
                }
            } else {
                placeholderIcon
            }
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
    }

    private var placeholderIcon: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: "photo")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(AppSemanticColor.textSecondary)

            Text("暂无图片")
                .font(AppTypography.micro)
                .foregroundStyle(AppSemanticColor.textSecondary)
        }
        .padding(AppSpacing.sm)
    }

    private var imageFailurePlaceholder: some View {
        VStack(spacing: AppSpacing.xs) {
            placeholderIcon
            Text("图片加载失败")
                .font(AppTypography.micro)
                .foregroundStyle(AppSemanticColor.textSecondary)
        }
        .padding(AppSpacing.sm)
    }
}

#Preview {
    MenuDishCard(
        title: "青椒小炒肉",
        category: "家常菜",
        quantity: 2,
        onDecrease: {},
        onIncrease: {}
    )
    .padding()
    .background(AppSemanticColor.background)
}
