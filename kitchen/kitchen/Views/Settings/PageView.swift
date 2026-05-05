import StoreKit
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @EnvironmentObject private var purchaseManager: PurchaseManager
    // TODO: 通知开关功能未实现，等接入 APNs / 本地通知后恢复。submitCart() 是新订单事件源，届时在那里触发厨师端通知。
    // @State private var notificationsEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("themeMode") private var themeMode = "system"
    @StateObject private var modalRouter = ModalRouter<SheetRoute>()
    @State private var isOfferCodeRedemptionPresented = false

    private let privacyPolicyURL = URL(string: "https://evilirving.github.io/family-concept")!

    var body: some View {
        AppScrollPage {
            EmptyView()
        } content: {
            if store.kitchen != nil {
                SettingsSection {
                    KitchenSummaryCard(onMemberTap: { member in
                        modalRouter.present(.member(MemberSheetToken(accountID: member.accountId)))
                    })
                }
            }

            if let kitchen = store.kitchen {
                SettingsSection(title: L10n.tr("Kitchen")) {
                    MenuCard {
                        InviteCodeMenuRow(inviteCode: kitchen.inviteCode, onCopy: { copyInviteCode(kitchen.inviteCode) })
                        MenuRow(
                            title: L10n.tr("Order History"),
                            showsDivider: false,
                            onTap: { presentOrderHistory() }
                        )
                    }
                }
            }

            SettingsSection(title: L10n.tr("Preferences")) {
                PreferencesSection(
                    // notificationsEnabled: $notificationsEnabled,
                    hapticsEnabled: $hapticsEnabled,
                    themeMode: $themeMode
                )
            }

            if store.hasKitchen {
                SettingsSection(title: L10n.tr("Membership")) {
                    MenuCard {
                        UpgradeMenuRow(
                            entitlement: store.entitlement,
                            canUpgrade: store.canUpgradeEntitlement,
                            onTap: { modalRouter.present(.upgrade) }
                        )
                        MenuRow(
                            title: purchaseManager.isRestoring ? L10n.tr("Restoring purchases") : L10n.tr("Restore Purchases"),
                            isEnabled: purchaseManager.isRestoring == false,
                            onTap: { Task { await restorePurchases() } }
                        )
                        MenuRow(
                            title: L10n.tr("Redeem Offer Code"),
                            showsDivider: false,
                            onTap: { isOfferCodeRedemptionPresented = true }
                        )
                    }
                }
            }

            SettingsSection(title: L10n.tr("Support & Legal")) {
                MenuCard {
                    MenuRow(
                        title: L10n.tr("Feedback"),
                        onTap: { modalRouter.present(.feedback) }
                    )
                    MenuRow(
                        title: L10n.tr("Privacy Policy"),
                        showsDivider: false,
                        url: privacyPolicyURL
                    )
                }
            }

            AppInlineConfirmButton(
                title: L10n.tr("Sign Out"),
                confirmTitle: L10n.tr("Confirm Sign Out")
            ) {
                await store.signOut()
            }
        }
        .sheet(item: modalRouteBinding, onDismiss: { modalRouter.handleDismissedCurrent() }) { route in
            switch route {
            case .member(let token):
                MemberManagementSheet(memberAccountID: token.accountID)
                    .environmentObject(store)
                    .environmentObject(feedbackRouter)
                    .presentationBackground(.clear)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
            case .upgrade:
                MembershipUpgradeSheet()
                    .environmentObject(store)
                    .environmentObject(purchaseManager)
                    .presentationDetents([.fraction(0.67)])
            case .feedback:
                FeedbackSheet()
                    .environmentObject(store)
                    .environmentObject(feedbackRouter)
                    .presentationDetents([.large])
            case .history:
                OrderHistorySheet()
                    .environmentObject(store)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
            }
        }
        .offerCodeRedemption(isPresented: $isOfferCodeRedemptionPresented) { result in
            switch result {
            case .success:
                feedbackRouter.show(.low(message: L10n.tr("Redeem flow opened"), systemImage: "ticket"))
            case .failure(let error):
                feedbackRouter.show(store.feedback(for: error))
            }
        }
    }

    private var modalRouteBinding: Binding<SheetRoute?> {
        Binding(
            get: { modalRouter.current },
            set: { route in
                if let route {
                    modalRouter.present(route)
                } else {
                    modalRouter.dismiss()
                }
            }
        )
    }

    private func restorePurchases() async {
        do {
            let restoredCount = try await purchaseManager.restore()
            if restoredCount > 0 {
                feedbackRouter.show(.high(message: L10n.tr("Purchases restored"), systemImage: "checkmark.circle.fill"))
            } else {
                feedbackRouter.show(.low(message: L10n.tr("No purchases to restore"), systemImage: "info.circle"))
            }
        } catch {
            feedbackRouter.show(store.feedback(for: error))
        }
    }

    private func copyInviteCode(_ inviteCode: String) {
        UIPasteboard.general.string = inviteCode
        feedbackRouter.show(AppFeedback.low(message: L10n.tr("Invite code copied")), placement: .centerToast)
    }

    private func presentOrderHistory() {
        modalRouter.present(.history)
        Task {
            await store.fetchOrderHistory()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppStore())
        .environmentObject(AppFeedbackRouter.shared)
        .environmentObject(PurchaseManager())
        .environmentObject(AppLanguageStore())
}
