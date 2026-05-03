import SwiftUI

/// 历史订单列表 Sheet 组件
struct OrderHistorySheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOrderID: String?

    var body: some View {
        AppSheetContainer(
            title: L10n.tr("历史订单"),
            dismissTitle: L10n.tr("关闭"),
            onDismiss: { dismiss() }
        ) {
            AppLoadingBlock(
                phase: historyPhase,
                content: { orders in
                    historyList(orders)
                },
                onRetry: { Task { await store.fetchOrderHistory() } }
            )
        }
        .sheet(item: historyDetailBinding, onDismiss: { store.selectedOrderDetail = nil }) { _ in
            OrderHistoryDetailSheet()
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
                        Task {
                            if await store.fetchOrderDetail(orderID: order.id) != nil {
                                selectedOrderID = order.id
                            }
                        }
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            AppPill(title: L10n.tr("%lld 道菜", order.itemCount), tint: AppSemanticColor.primary, background: AppSemanticColor.interactiveSecondary)
                            Text(orderTitle(order))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppSemanticColor.textSecondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: AppIconSize.xs, weight: .semibold))
                                .foregroundStyle(AppSemanticColor.textTertiary)
                        }
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
        displayOrderDate(order.finishedAt) ?? L10n.tr("已收好的这一顿")
    }

    private var historyPhase: LoadingPhase<[OrderHistoryEntry]> {
        if store.isLoadingOrderHistory && !store.orderHistory.isEmpty {
            return .refreshing(store.orderHistory, label: L10n.tr("刷新历史"))
        }
        if let feedback = store.historyFeedback {
            return .failure(feedback, retainedValue: store.orderHistory.isEmpty ? nil : store.orderHistory)
        }
        if store.isLoadingOrderHistory && store.orderHistory.isEmpty {
            return .initialLoading(label: L10n.tr("加载历史"))
        }
        if store.orderHistory.isEmpty {
            return .failure(.empty(kind: .noData, title: L10n.tr("还没有历史记录")), retainedValue: nil)
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
