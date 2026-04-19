import SwiftUI

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
            set: { token in
                selectedOrderID = token?.orderID
            }
        )
    }
}

struct OrderHistoryDetailSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AppSheetContainer(
            title: "历史订单详情",
            dismissTitle: "关闭",
            onDismiss: { dismiss() }
        ) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.sm) {
                    if let detail = store.selectedOrderDetail {
                        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                            AppPill(
                                title: "共 \(totalDishCount(detail)) 道菜",
                                tint: AppSemanticColor.primary,
                                background: AppSemanticColor.interactiveSecondary
                            )
                            Text(displayOrderDate(detail.finishedAt) ?? "已收好的这一顿")
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
                    } else {
                        Text("没有可展示的历史详情")
                            .font(AppTypography.body)
                            .foregroundStyle(AppSemanticColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, AppSpacing.lg)
                    }
                }
                .padding(.top, AppSpacing.xs)
            }
        }
    }

    private func dishName(for dishID: String) -> String {
        store.dishes.first(where: { $0.id == dishID })?.name ?? "未知菜品"
    }

    private func totalDishCount(_ detail: OrderDetail) -> Int {
        detail.items.reduce(0) { $0 + $1.quantity }
    }
}

private struct OrderHistoryDetailRow: View {
    let item: OrderItem
    let dishName: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(dishName)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppSemanticColor.textPrimary)
                Text(quantityText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.textSecondary)
            }
            Spacer()
            AppPill(title: item.status.title, tint: statusColor, background: statusBackground)
        }
    }

    private var quantityText: String {
        "×\(item.quantity)"
    }

    private var statusColor: Color {
        switch item.status {
        case .waiting:
            return AppSemanticColor.infoForeground
        case .cooking:
            return AppSemanticColor.warning
        case .done:
            return AppSemanticColor.primary
        case .cancelled:
            return AppSemanticColor.textSecondary
        }
    }

    private var statusBackground: Color {
        switch item.status {
        case .waiting:
            return AppSemanticColor.infoBackground
        case .cooking:
            return AppSemanticColor.warningBackground
        case .done:
            return AppSemanticColor.interactiveSecondary
        case .cancelled:
            return AppSemanticColor.surfaceSecondary
        }
    }
}

private struct HistoryDetailToken: Identifiable {
    let orderID: String
    var id: String { orderID }
}

private func displayOrderDate(_ raw: String?) -> String? {
    guard let raw else { return nil }

    let isoParser = ISO8601DateFormatter()
    if let date = isoParser.date(from: raw) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 HH:mm"
        return formatter.string(from: date)
    }

    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.timeZone = TimeZone(secondsFromGMT: 0)
    parser.dateFormat = "yyyy-MM-dd HH:mm:ss"
    if let date = parser.date(from: raw) {
        let output = DateFormatter()
        output.locale = Locale(identifier: "zh_CN")
        output.timeZone = .current
        output.dateFormat = "M月d日 HH:mm"
        return output.string(from: date)
    }

    return nil
}
