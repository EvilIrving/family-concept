import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var store: AppStore
    @State private var toast: AppToastData?
    @State private var showShoppingList = false

    var body: some View {
        AppScrollPage {
            EmptyView()
        } content: {
            AppCard {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                        Text("当前出餐")
                            .font(AppTypography.sectionTitle)
                            .foregroundStyle(AppColor.textPrimary)
                        Text("\(store.orderItems.count) 道")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                        Spacer()
                        Button("采购清单") {
                            showShoppingList = true
                        }
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppColor.green800)
                    }

                    HStack(spacing: AppSpacing.xs) {
                        statusPill(title: "待制作", value: waitingCount, tint: AppColor.info, background: AppColor.infoSoft)
                        statusPill(title: "制作中", value: cookingCount, tint: AppColor.warning, background: AppColor.warningSoft)
                        statusPill(title: "已完成", value: doneCount, tint: AppColor.green800, background: AppColor.green100)
                    }
                }
            }

            AppCard {
                if store.orderItems.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("还没有出餐内容")
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppColor.textPrimary)
                        Text("菜单页提交后，这里会直接显示当前订单。")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                } else {
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
            }
        }
        .appToast($toast)
        .sheet(isPresented: $showShoppingList) {
            ShoppingListSheet(items: store.shoppingList)
        }
    }

    private var waitingCount: Int {
        store.orderItems.filter { $0.status == .waiting }.count
    }

    private var cookingCount: Int {
        store.orderItems.filter { $0.status == .cooking }.count
    }

    private var doneCount: Int {
        store.orderItems.filter { $0.status == .done }.count
    }

    private func statusPill(title: String, value: Int, tint: Color, background: Color) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppTypography.micro)
                .foregroundStyle(tint)
            Text("\(value)")
                .font(AppTypography.bodyStrong)
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
        .background(background, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }
}

private struct ShoppingListSheet: View {
    let items: [(name: String, count: Int)]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AppSheetContainer(
            title: "采购清单",
            subtitle: items.isEmpty ? nil : "按当前订单聚合",
            dismissTitle: "关闭",
            confirmTitle: "完成",
            onDismiss: { dismiss() },
            onConfirm: { dismiss() }
        ) {
            ScrollView(showsIndicators: false) {
                if items.isEmpty {
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("暂无采购需求")
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppColor.textPrimary)
                        Text("有新订单后，这里会自动汇总食材。")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, AppSpacing.xs)
                } else {
                    AppCard {
                        ForEach(items, id: \.name) { ingredient in
                            HStack(spacing: AppSpacing.sm) {
                                Text(ingredient.name)
                                    .font(AppTypography.bodyStrong)
                                    .foregroundStyle(AppColor.textPrimary)
                                Spacer()
                                AppPill(title: "\(ingredient.count) 道菜", tint: AppColor.info, background: AppColor.infoSoft)
                            }
                            if ingredient.name != items.last?.name {
                                Divider()
                                    .overlay(AppColor.lineSoft)
                            }
                        }
                    }
                    .padding(.top, AppSpacing.xs)
                }
            }
        }
        .presentationBackground(.clear)
    }
}

private struct OrderItemRow: View {
    let item: OrderItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.sm) {
                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                    .fill(statusBackground)
                    .frame(width: 42, height: 42)
                    .overlay {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 10, height: 10)
                    }

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(item.dishName)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("\(item.quantity) 份")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer()

                AppPill(title: item.status.title, tint: statusColor, background: statusBackground)
            }
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statusColor: Color {
        switch item.status {
        case .waiting: AppColor.info
        case .cooking: AppColor.warning
        case .done: AppColor.green800
        case .cancelled: AppColor.danger
        }
    }

    private var statusBackground: Color {
        switch item.status {
        case .waiting: AppColor.infoSoft
        case .cooking: AppColor.warningSoft
        case .done: AppColor.green100
        case .cancelled: AppColor.dangerSoft
        }
    }
}

#Preview {
    OrdersView()
        .environmentObject(AppStore())
}
