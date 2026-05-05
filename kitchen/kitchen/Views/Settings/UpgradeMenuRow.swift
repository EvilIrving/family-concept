import SwiftUI

struct UpgradeMenuRow: View {
    let entitlement: KitchenEntitlement
    let canUpgrade: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AppSpacing.sm) {
                    Text(entitlement.planCode.displayName)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppSemanticColor.textPrimary)
                    if entitlement.isUnlimited {
                        Text(L10n.tr("Unlimited dishes"))
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppSemanticColor.primary)
                            .lineLimit(1)
                    }
                    if !entitlement.isUnlimited, let limit = entitlement.dishLimit {
                        Text(L10n.tr("%lld / %lld used", Int64(entitlement.activeDishCount), Int64(limit)))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppSemanticColor.textSecondary)
                    }
                }
            }
            Spacer()
            if canUpgrade {
                Text("Upgrade")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: AppIconSize.xs, weight: .semibold))
                .foregroundStyle(AppSemanticColor.textTertiary)
        }
        .frame(minHeight: AppDimension.listRowMinHeight)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
