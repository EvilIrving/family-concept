import SwiftUI

/// 历史订单详情行组件
struct OrderHistoryDetailRow: View {
    let item: OrderItem
    let dishName: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(dishName)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppSemanticColor.textPrimary)
                Text(L10n.tr("format.quantityTimes", item.quantity))
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.textSecondary)
            }
            Spacer()
            AppPill(title: item.status.title, tint: statusColor, background: statusBackground)
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .waiting: AppSemanticColor.infoForeground
        case .cooking: AppSemanticColor.warning
        case .done: AppSemanticColor.primary
        case .cancelled: AppSemanticColor.textSecondary
        }
    }

    private var statusBackground: Color {
        switch item.status {
        case .waiting: AppSemanticColor.infoBackground
        case .cooking: AppSemanticColor.warningBackground
        case .done: AppSemanticColor.interactiveSecondary
        case .cancelled: AppSemanticColor.surfaceSecondary
        }
    }
}
