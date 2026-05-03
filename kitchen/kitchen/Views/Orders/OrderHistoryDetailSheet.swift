import SwiftUI

/// 历史订单详情 Sheet 组件
struct OrderHistoryDetailSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AppSheetContainer(
            title: L10n.tr("历史订单详情"),
            dismissTitle: L10n.tr("关闭"),
            onDismiss: { dismiss() }
        ) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.sm) {
                    if let detail = store.selectedOrderDetail {
                        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                            AppPill(
                                title: L10n.tr("共 %lld 道菜", totalDishCount(detail)),
                                tint: AppSemanticColor.primary,
                                background: AppSemanticColor.interactiveSecondary
                            )
                            Text(displayOrderDate(detail.finishedAt) ?? L10n.tr("已收好的这一顿"))
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
                        Text(L10n.tr("没有可展示的历史详情"))
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
        store.dishes.first(where: { $0.id == dishID })?.name ?? L10n.tr("未知菜品")
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
