import SwiftUI

struct OrdersView: View {
    @EnvironmentObject private var store: AppStore
    @State private var toast: AppToastData?
    @State private var showShoppingList = false

    var body: some View {
        AppScrollPage {
            Text("订单")
                .font(AppTypography.pageTitle)
                .foregroundStyle(AppColor.textPrimary)
        } content: {
            HStack(spacing: AppSpacing.sm) {
                summaryCard(title: "待制作", value: store.orderItems.filter { $0.status == .waiting }.count, tint: AppColor.green800, background: AppColor.green100)
                summaryCard(title: "制作中", value: store.orderItems.filter { $0.status == .cooking }.count, tint: AppColor.warning, background: AppColor.warningSoft)
                summaryCard(title: "已完成", value: store.orderItems.filter { $0.status == .done }.count, tint: AppColor.info, background: AppColor.infoSoft)
            }

            AppCard {
                AppSectionHeader(eyebrow: "出餐", title: "当前出餐")
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
        .appToast($toast)
        .overlay(alignment: .bottomTrailing) {
            Button {
                showShoppingList = true
            } label: {
                Image(systemName: "list.clipboard")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColor.textOnBrand)
                    .frame(width: 56, height: 56)
                    .background(AppColor.green800, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            }
            .padding(.bottom, AppSpacing.md)
            .padding(.trailing, AppSpacing.md)
        }
        .sheet(isPresented: $showShoppingList) {
            ShoppingListSheet(items: store.shoppingList)
                .presentationDetents([.medium, .large])
        }
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

private struct ShoppingListSheet: View {
    let items: [(name: String, count: Int)]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    if items.isEmpty {
                        Text("暂无采购需求")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textSecondary)
                            .padding(.top, AppSpacing.xl)
                    } else {
                        AppCard {
                            AppSectionHeader(eyebrow: "采购", title: "采购清单")
                            ForEach(items, id: \.name) { ingredient in
                                HStack {
                                    Text(ingredient.name)
                                        .font(AppTypography.bodyStrong)
                                        .foregroundStyle(AppColor.textPrimary)
                                    Spacer()
                                    AppPill(title: "\(ingredient.count) 道菜", tint: AppColor.info, background: AppColor.infoSoft)
                                }
                                if ingredient.name != items.last?.name {
                                    Divider().overlay(AppColor.lineSoft)
                                }
                            }
                        }
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(AppColor.backgroundBase)
            .navigationTitle("采购清单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
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
                    Text("\(item.quantity) 份")
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
