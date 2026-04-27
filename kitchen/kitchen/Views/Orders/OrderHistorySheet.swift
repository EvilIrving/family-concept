import SwiftUI

/// 历史订单列表 Sheet 组件
struct OrderHistorySheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedOrderID: String?

    var body: some View {
        AppSheetContainer(
            title: "历史订单",
            dismissTitle: "关闭",
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
            VStack(spacing: AppSpacing.sm) {
                ForEach(orders) { order in
                    AppRowButton(action: {
                        Task {
                            if await store.fetchOrderDetail(orderID: order.id) != nil {
                                selectedOrderID = order.id
                            }
                        }
                    }) {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack(alignment: .firstTextBaseline) {
                                AppPill(title: "\(order.itemCount) 道菜", tint: AppSemanticColor.primary, background: AppSemanticColor.interactiveSecondary)
                                Text(orderTitle(order))
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppSemanticColor.textSecondary)
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, AppSpacing.md)
                        .overlay(alignment: .bottom) {
                            if order.id != orders.last?.id {
                                Divider()
                                    .overlay(AppSemanticColor.border)
                            }
                        }
                    }
                }
            }
            .padding(.top, AppSpacing.xs)
        }
    }

    private func orderTitle(_ order: OrderHistoryEntry) -> String {
        displayOrderDate(order.finishedAt) ?? "已收好的这一顿"
    }

    private var historyPhase: LoadingPhase<[OrderHistoryEntry]> {
        if store.isLoadingOrderHistory && !store.orderHistory.isEmpty {
            return .refreshing(store.orderHistory, label: "刷新历史")
        }
        if let feedback = store.historyFeedback {
            return .failure(feedback, retainedValue: store.orderHistory.isEmpty ? nil : store.orderHistory)
        }
        if store.isLoadingOrderHistory && store.orderHistory.isEmpty {
            return .initialLoading(label: "加载历史")
        }
        if store.orderHistory.isEmpty {
            return .failure(.empty(kind: .noData, title: "还没有历史记录"), retainedValue: nil)
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
