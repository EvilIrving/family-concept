import SwiftUI

/// 历史订单详情 Sheet 组件
struct OrderHistoryDetailSheet: View {
    let orderID: String
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AppSheetContainer(
            title: L10n.tr("Order Details"),
            dismissTitle: L10n.tr("Close"),
            onDismiss: { dismiss() }
        ) {
            AppLoadingBlock(
                phase: detailPhase,
                skeletonView: { OrderHistoryDetailSkeleton() },
                content: { detail in
                    detailBody(detail)
                },
                onRetry: { Task { _ = await store.fetchOrderDetail(orderID: orderID) } }
            )
        }
    }

    @ViewBuilder
    private func detailBody(_ detail: OrderDetail) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    AppPill(
                        title: L10n.tr("%lld dishes total", totalDishCount(detail)),
                        tint: AppSemanticColor.primary,
                        background: AppSemanticColor.interactiveSecondary
                    )
                    Text(displayOrderDate(detail.finishedAt) ?? L10n.tr("Wrapped meals"))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppSemanticColor.textSecondary)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, AppSpacing.sm)

                VStack(spacing: .zero) {
                    ForEach(detail.items) { item in
                        OrderHistoryDetailRow(item: item, dishName: dishName(for: item.dishId))
                            .padding(.vertical, AppSpacing.md)
                        if item.id != detail.items.last?.id {
                            Divider()
                                .overlay(AppSemanticColor.border)
                        }
                    }
                }
            }
            .padding(.top, AppSpacing.xs)
        }
    }

    private var detailPhase: LoadingPhase<OrderDetail> {
        if let detail = store.selectedOrderDetail {
            if store.isLoadingOrderDetail {
                return .refreshing(detail, label: L10n.tr("Refreshing history"))
            }
            return .success(detail)
        }
        if let feedback = store.orderDetailFeedback {
            return .failure(feedback, retainedValue: nil)
        }
        if store.isLoadingOrderDetail {
            return .initialLoading(label: L10n.tr("Loading history"))
        }
        return .failure(.empty(kind: .noData, title: L10n.tr("No order details to show")), retainedValue: nil)
    }

    private func dishName(for dishID: String) -> String {
        store.dishes.first(where: { $0.id == dishID })?.name ?? L10n.tr("Unknown dish")
    }

    private func totalDishCount(_ detail: OrderDetail) -> Int {
        detail.items.reduce(0) { $0 + $1.quantity }
    }
}

/// 历史详情 Token
struct HistoryDetailToken: Identifiable {
    let orderID: String
    var id: String { orderID }
}

private struct OrderHistoryDetailSkeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.xs) {
                    SkeletonPrimitive(cornerRadius: AppRadius.pill)
                        .frame(width: 80, height: 22)
                    SkeletonPrimitive(cornerRadius: AppRadius.sm)
                        .frame(width: 96, height: 14)
                    Spacer()
                }
                .padding(.vertical, AppSpacing.sm)

                VStack(spacing: .zero) {
                    ForEach(0..<5, id: \.self) { index in
                        OrderHistoryDetailRowSkeleton()
                            .padding(.vertical, AppSpacing.md)
                        if index < 4 {
                            Divider().overlay(AppSemanticColor.border)
                        }
                    }
                }
            }
            .padding(.top, AppSpacing.xs)
        }
        .scrollDisabled(true)
        .accessibilityHidden(true)
    }
}

private struct OrderHistoryDetailRowSkeleton: View {
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            SkeletonPrimitive(cornerRadius: AppRadius.sm)
                .frame(width: 120, height: 16)
            SkeletonPrimitive(cornerRadius: AppRadius.sm)
                .frame(width: 32, height: 12)
            Spacer()
            SkeletonPrimitive(cornerRadius: AppRadius.pill)
                .frame(width: 56, height: 22)
        }
    }
}

// MARK: - Date Helper

func displayOrderDate(_ raw: String?) -> String? {
    guard let raw else { return nil }

    let isoParser = ISO8601DateFormatter()
    if let date = isoParser.date(from: raw) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: AppLanguage.resolved().rawValue)
        formatter.setLocalizedDateFormatFromTemplate("MdHm")
        return formatter.string(from: date)
    }

    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.timeZone = TimeZone(secondsFromGMT: 0)
    parser.dateFormat = "yyyy-MM-dd HH:mm:ss"
    if let date = parser.date(from: raw) {
        let output = DateFormatter()
        output.locale = Locale(identifier: AppLanguage.resolved().rawValue)
        output.timeZone = .current
        output.setLocalizedDateFormatFromTemplate("MdHm")
        return output.string(from: date)
    }

    return nil
}
