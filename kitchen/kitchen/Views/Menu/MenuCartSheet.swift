import SwiftUI

struct MenuCartSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AppSheetContainer(
            title: "已选菜品",
            dismissTitle: "关闭",
            confirmTitle: "下单",
            onDismiss: { dismiss() },
            onConfirm: {
                Task {
                    await store.submitCart()
                    guard store.error == nil else { return }
                    feedbackRouter.show(.high(message: "已下单"))
                    dismiss()
                }
            },
            isConfirmDisabled: store.cartItems.isEmpty,
            isConfirmLoading: store.isSubmittingCart
        ) {
            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    if store.cartItems.isEmpty {
                        Text("购物车是空的")
                            .font(AppTypography.body)
                            .foregroundStyle(AppSemanticColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppSpacing.xl)
                    } else {
                        AppCard {
                            ForEach(store.cartItems) { item in
                                HStack(spacing: AppSpacing.sm) {
                                    Text(item.dishName)
                                        .font(AppTypography.bodyStrong)
                                        .foregroundStyle(AppSemanticColor.textPrimary)
                                    Spacer()
                                    HStack(spacing: AppSpacing.xs) {
                                        AppIconActionButton(systemImage: "minus", tone: .neutral) {
                                            store.updateCartQuantity(itemID: item.id, delta: -1)
                                        }
                                        Text("\(item.quantity)")
                                            .font(AppTypography.bodyStrong)
                                            .foregroundStyle(AppSemanticColor.textPrimary)
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
                                    Divider().overlay(AppSemanticColor.border)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
