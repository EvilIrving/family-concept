import SwiftUI

struct MenuCartSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AppSheetContainer(
            title: L10n.tr("Selected"),
            dismissTitle: L10n.tr("Close"),
            confirmTitle: L10n.tr("Place Order"),
            onDismiss: { dismiss() },
            onConfirm: {
                Task {
                    await store.submitCart()
                    guard store.error == nil else { return }
                    feedbackRouter.show(.low(message: L10n.tr("Order placed")))
                    dismiss()
                }
            },
            isConfirmDisabled: store.cartItems.isEmpty,
            isConfirmLoading: store.isSubmittingCart
        ) {
            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    if store.cartItems.isEmpty {
                        Text(L10n.tr("Your cart is empty"))
                            .font(AppTypography.body)
                            .foregroundStyle(AppSemanticColor.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, AppSpacing.xl)
                    } else {
                        AppCardList {
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
                                    .disabled(store.isSubmittingCart)
                                }
//                                if item.id != store.cartItems.last?.id {
//                                    Divider().overlay(AppSemanticColor.border)
//                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
