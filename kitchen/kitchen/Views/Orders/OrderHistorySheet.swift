import SwiftUI

/// 历史订单列表 Sheet 组件
struct OrderHistorySheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOrderID: String?

    var body: some View {
        AppSheetContainer(
            title: L10n.tr("Order History"),
            dismissTitle: L10n.tr("Close"),
            onDismiss: { dismiss() }
        ) {
            AppLoadingBlock(
                phase: historyPhase,
                skeletonView: { OrderHistoryListSkeleton() },
                content: { orders in
                    historyList(orders)
                },
                onRetry: { Task { await store.fetchOrderHistory() } }
            )
        }
        .sheet(item: historyDetailBinding, onDismiss: { store.selectedOrderDetail = nil }) { token in
            OrderHistoryDetailSheet(orderID: token.orderID)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }

    @ViewBuilder
    private func historyList(_ orders: [OrderHistoryEntry]) -> some View {
        ScrollView(showsIndicators: false) {
            AppCardList {
                ForEach(orders) { order in
                    Button {
                        selectedOrderID = order.id
                        Task { _ = await store.fetchOrderDetail(orderID: order.id) }
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            AppPill(title: L10n.tr("%lld dishes", order.itemCount), tint: AppSemanticColor.primary, background: AppSemanticColor.interactiveSecondary)
                            Text(orderTitle(order))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppSemanticColor.textSecondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: AppIconSize.xs, weight: .semibold))
                                .foregroundStyle(AppSemanticColor.textTertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if order.id != orders.last?.id {
                        Divider().overlay(AppSemanticColor.border)
                    }
                }
            }
        }
    }

    private func orderTitle(_ order: OrderHistoryEntry) -> String {
        displayOrderDate(order.finishedAt) ?? L10n.tr("Wrapped meals")
    }

    private var historyPhase: LoadingPhase<[OrderHistoryEntry]> {
        if store.isLoadingOrderHistory && !store.orderHistory.isEmpty {
            return .refreshing(store.orderHistory, label: L10n.tr("Refreshing history"))
        }
        if let feedback = store.historyFeedback {
            return .failure(feedback, retainedValue: store.orderHistory.isEmpty ? nil : store.orderHistory)
        }
        if store.isLoadingOrderHistory && store.orderHistory.isEmpty {
            return .initialLoading(label: L10n.tr("Loading history"))
        }
        if store.orderHistory.isEmpty {
            return .failure(.empty(kind: .noData, title: L10n.tr("No history yet")), retainedValue: nil)
        }
        return .success(store.orderHistory)
    }

    private var historyDetailBinding: Binding<HistoryDetailToken?> {
        Binding(
            get: {
                guard let selectedOrderID else { return nil }
                return HistoryDetailToken(orderID: selectedOrderID)
            },
            set: { token in selectedOrderID = token?.orderID }
        )
    }
}

private struct OrderHistoryListSkeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            AppCardList {
                VStack(spacing: .zero) {
                    ForEach(0..<5, id: \.self) { index in
                        OrderHistoryRowSkeleton()
                            .padding(.vertical, AppSpacing.xs)
                        if index < 4 {
                            Divider().overlay(AppSemanticColor.border)
                        }
                    }
                }
            }
        }
        .scrollDisabled(true)
        .accessibilityHidden(true)
    }
}

private struct OrderHistoryRowSkeleton: View {
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            SkeletonPrimitive(cornerRadius: AppRadius.pill)
                .frame(width: 64, height: 22)
            SkeletonPrimitive(cornerRadius: AppRadius.sm)
                .frame(width: 96, height: 14)
            Spacer()
            SkeletonPrimitive(cornerRadius: AppRadius.sm)
                .frame(width: 10, height: 14)
        }
    }
}
