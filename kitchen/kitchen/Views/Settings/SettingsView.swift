import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @State private var notificationsEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("themeMode") private var themeMode = "system"
    @StateObject private var modalRouter = ModalRouter<SettingsModalRoute>()

    var body: some View {
        AppScrollPage {
            EmptyView()
        } content: {
            if store.kitchen != nil {
                KitchenInfoCard(onMemberTap: { member in
                    modalRouter.present(.member(MemberSheetToken(accountID: member.accountId)))
                })
            }

            PreferencesSection(
                notificationsEnabled: $notificationsEnabled,
                hapticsEnabled: $hapticsEnabled,
                themeMode: $themeMode
            )

            AppButton(title: "退出登录", style: .destructive) {
                Task { await store.signOut() }
            }
        }
        .sheet(item: modalRouteBinding, onDismiss: { modalRouter.handleDismissedCurrent() }) { route in
            MemberRoleSheet(memberAccountID: route.token.accountID)
                .environmentObject(store)
                .presentationBackground(.clear)
                .presentationDetents([.fraction(0.25)])
                .presentationDragIndicator(.hidden)
        }
    }

    private var modalRouteBinding: Binding<SettingsModalRoute?> {
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
}

#Preview {
    SettingsView()
        .environmentObject(AppStore())
}
