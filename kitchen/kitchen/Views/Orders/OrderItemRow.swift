import SwiftUI

/// 订单项行组件
struct OrderItemRow: View {
    let item: GroupedOrderItem
    let canManage: Bool
    let canEditWaiting: Bool
    let onTap: () -> Void
    let onReduce: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Button(action: onTap) {
                HStack(spacing: AppSpacing.sm) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: AppDimension.statusDot, height: AppDimension.statusDot)

                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                            Text(item.dishName)
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(AppSemanticColor.textPrimary)
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Text("\(item.quantity) 份")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppSemanticColor.textSecondary)
                                .fixedSize()
                        }
                    }

                    Spacer()

                    AppPill(title: item.status.title, tint: statusColor, background: statusBackground)
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canManage)

            if canEditWaiting && item.status == .waiting {
                HStack(spacing: AppSpacing.xxs) {
                    AppIconActionButton(systemImage: "minus", tone: .neutral, action: onReduce)
                    AppIconActionButton(systemImage: "xmark", tone: .danger, action: onCancel)
                }
            }
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
