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
            AppLoadingBlock(phase: historyPhase) { orders in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(orders) { order in
                            Button {
                                Task {
                                    if await store.fetchOrderDetail(orderID: order.id) != nil {
                                        selectedOrderID = order.id
                                    }
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                    HStack(alignment: .firstTextBaseline) {
                                        AppPill(title: "\(order.itemCount) 道菜", tint: AppSemanticColor.primary, background: AppSemanticColor.interactiveSecondary)
                                        Text(orderTitle(order))
                                            .font(AppTypography.caption)
                                            .foregroundStyle(AppSemanticColor.textSecondary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: AppIconSize.xs, weight: .semibold))
                                            .foregroundStyle(AppSemanticColor.textTertiary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, AppSpacing.md)
                                .contentShape(Rectangle())
                                .overlay(alignment: .bottom) {
                                    if order.id != store.orderHistory.last?.id {
                                        Divider()
                                            .overlay(AppSemanticColor.border)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, AppSpacing.xs)
                }
            }
        }
        .sheet(item: historyDetailBinding, onDismiss: { store.selectedOrderDetail = nil }) { _ in
            OrderHistoryDetailSheet()
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
        }
    }

    private func orderTitle(_ order: OrderHistoryEntry) -> String {
        displayOrderDate(order.finishedAt) ?? "已收好的这一顿"
    }

    private var historyPhase: LoadingPhase<[OrderHistoryEntry]> {
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
