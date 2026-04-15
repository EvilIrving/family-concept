import SwiftUI

struct MenuCartSheet: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var toast: AppToastData?

    var body: some View {
        AppSheetContainer(
            title: "购物车",
            dismissTitle: "关闭",
            confirmTitle: "提交下单",
            onDismiss: { dismiss() },
            onConfirm: {
                Task {
                    await store.submitCart()
                    toast = AppToastData(message: "已下单")
                    dismiss()
                }
            }
        ) {
            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    if store.cartItems.isEmpty {
                        Text("购物车是空的")
                            .font(AppTypography.body)
                            .foregroundStyle(AppColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppSpacing.xl)
                    } else {
                        AppCard {
                            ForEach(store.cartItems) { item in
                                HStack(spacing: AppSpacing.sm) {
                                    Text(item.dishName)
                                        .font(AppTypography.bodyStrong)
                                        .foregroundStyle(AppColor.textPrimary)
                                    Spacer()
                                    HStack(spacing: AppSpacing.xs) {
                                        AppIconActionButton(systemImage: "minus", tone: .neutral) {
                                            store.updateCartQuantity(itemID: item.id, delta: -1)
                                        }
                                        Text("\(item.quantity)")
                                            .font(AppTypography.bodyStrong)
                                            .foregroundStyle(AppColor.textPrimary)
                                            .frame(minWidth: 24, alignment: .center)
                                        AppIconActionButton(systemImage: "plus", tone: .brand) {
                                            store.updateCartQuantity(itemID: item.id, delta: 1)
                                        }
                                        AppIconActionButton(systemImage: "xmark", tone: .danger) {
                                            store.removeFromCart(itemID: item.id)
                                        }
                                    }
                                }
                                if item.id != store.cartItems.last?.id {
                                    Divider().overlay(AppColor.lineSoft)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .appToast($toast)
    }
}
