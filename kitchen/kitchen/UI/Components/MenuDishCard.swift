import SwiftUI

struct MenuDishCard: View {
    let title: String
    let category: String
    var quantity: Int = 0
    var imageSystemName: String = "fork.knife"
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        AppCard(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                dishArtwork

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(title)
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(AppColor.textPrimary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

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
                                    .foregroundStyle(AppColor.textPrimary)
                                    .frame(minWidth: 24)
                                    .frame(height: 32)
                                    .padding(.horizontal, 2)
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
                colors: [AppColor.green200, AppColor.green100],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
            .frame(height: 112)
            .overlay(alignment: .topTrailing) {
                AppPill(title: category)
                    .padding(AppSpacing.sm)
            }
            .overlay {
                Image(systemName: imageSystemName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppColor.green800)
            }
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
    .background(AppColor.backgroundBase)
}
