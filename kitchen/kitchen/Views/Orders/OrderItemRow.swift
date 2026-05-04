import SwiftUI

/// 订单项行组件
struct OrderItemRow: View {
    let item: GroupedOrderItem
    let canChangeStatus: Bool
    let canEditWaiting: Bool
    let onTap: () -> Void
    let onReduce: () -> Void
    let onCancel: () -> Void

    var body: some View {
        rowContent
    }

    private var rowContent: some View {
        HStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(statusColor)
                .frame(width: AppDimension.statusDot, height: AppDimension.statusDot)

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(item.dishName)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppSemanticColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(1)

                Text("×\(item.quantity)")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppSemanticColor.textSecondary)
                    .padding(.horizontal, AppSpacing.xs)
                    .padding(.vertical, AppSpacing.xxs)
                    .background(AppSemanticColor.surfaceSecondary, in: Capsule())
                    .fixedSize()
                    .accessibilityLabel(L10n.tr("%lld servings", item.quantity))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            statusControl
                .fixedSize()
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var statusControl: some View {
        if canChangeStatus && item.status != .done && item.status != .cancelled {
            Button(action: onTap) {
                AppPill(title: item.status.title, tint: statusColor, background: statusBackground)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(statusActionLabel)
        } else {
            AppPill(title: item.status.title, tint: statusColor, background: statusBackground)
        }
    }

    private var statusActionLabel: String {
        switch item.status {
        case .waiting:
            return L10n.tr("Start cooking %@", item.dishName)
        case .cooking:
            return L10n.tr("Mark %@ done", item.dishName)
        case .done, .cancelled:
            return item.status.title
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .waiting: AppSemanticColor.infoForeground
        case .cooking: AppSemanticColor.warning
        case .done: AppSemanticColor.primary
        case .cancelled: AppSemanticColor.danger
        }
    }

    private var statusBackground: Color {
        switch item.status {
        case .waiting: AppSemanticColor.infoBackground
        case .cooking: AppSemanticColor.warningBackground
        case .done: AppSemanticColor.interactiveSecondary
        case .cancelled: AppSemanticColor.dangerBackground
        }
    }
}
