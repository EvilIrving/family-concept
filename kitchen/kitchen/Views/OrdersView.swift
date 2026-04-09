import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var store: AppStore
    @State private var toast: AppToastData?

    var body: some View {
        AppScrollPage {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("订单")
                    .font(AppTypography.pageTitle)
                    .foregroundStyle(AppColor.textPrimary)
                Text("状态切换和采购信息都在同一页完成。")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
        } content: {
            HStack(spacing: AppSpacing.sm) {
                summaryCard(title: "待制作", value: store.orderItems.filter { $0.status == .waiting }.count, tint: AppColor.green800, background: AppColor.green100)
                summaryCard(title: "制作中", value: store.orderItems.filter { $0.status == .cooking }.count, tint: AppColor.warning, background: AppColor.warningSoft)
                summaryCard(title: "已完成", value: store.orderItems.filter { $0.status == .done }.count, tint: AppColor.info, background: AppColor.infoSoft)
            }

            AppCard {
                AppSectionHeader(eyebrow: "出餐", title: "当前出餐", detail: "点按行项目即可切换状态。")
                ForEach(store.orderItems) { item in
                    OrderItemRow(item: item) {
                        store.cycleStatus(for: item.id)
                        toast = AppToastData(message: "\(item.dishName) 已切换为\(store.title(for: item.id))")
                    }
                    if item.id != store.orderItems.last?.id {
                        Divider()
                            .overlay(AppColor.lineSoft)
                    }
                }
            }

            AppCard {
                AppSectionHeader(eyebrow: "采购", title: "采购清单", detail: "基于当前订单自动汇总。")
                ForEach(store.shoppingList, id: \.name) { ingredient in
                    HStack {
                        Text(ingredient.name)
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppColor.textPrimary)
                        Spacer()
                        AppPill(title: "\(ingredient.count) 道菜", tint: AppColor.info, background: AppColor.infoSoft)
                    }
                }
            }
        }
        .appToast($toast)
    }

    private func summaryCard(title: String, value: Int, tint: Color, background: Color) -> some View {
        AppCard(padding: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.micro)
                .foregroundStyle(AppColor.textSecondary)
            Text("\(value)")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(tint)
            RoundedRectangle(cornerRadius: AppRadius.pill, style: .continuous)
                .fill(background)
                .frame(height: 8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OrderItemRow: View {
    let item: OrderItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.sm) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(item.dishName)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("\(item.quantity) 份 · \(item.addedBy)")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer()

                AppPill(title: item.status.title, tint: statusColor, background: statusBackground)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch item.status {
        case .waiting: AppColor.green800
        case .cooking: AppColor.warning
        case .done: AppColor.info
        case .cancelled: AppColor.danger
        }
    }

    private var statusBackground: Color {
        switch item.status {
        case .waiting: AppColor.green100
        case .cooking: AppColor.warningSoft
        case .done: AppColor.infoSoft
        case .cancelled: AppColor.dangerSoft
        }
    }
}
