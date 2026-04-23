import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var notificationsEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("themeMode") private var themeMode = "system"
    @StateObject private var modalRouter = ModalRouter<SettingsModalRoute>()

    var body: some View {
        AppScrollPage {
            EmptyView()
        } content: {
            if store.kitchen != nil {
                SettingsSection {
                    KitchenInfoCard(onMemberTap: { member in
                        modalRouter.present(.member(MemberSheetToken(accountID: member.accountId)))
                    })
                }
            }

            SettingsSection(title: "偏好") {
                PreferencesSection(
                    notificationsEnabled: $notificationsEnabled,
                    hapticsEnabled: $hapticsEnabled,
                    themeMode: $themeMode
                )
            }

            SettingsSection(title: "支持与建议") {
                SettingsMenuCard {
                    SettingsMenuRow(title: "联系我们提交需求")
                    SettingsMenuRow(title: "评分与支持")
                    SettingsMenuRow(title: "分享", showsDivider: false)
                }
            }

            SettingsSection(title: "其他") {
                SettingsMenuCard {
                    SettingsMenuRow(title: "恢复购买")
                    SettingsMenuRow(title: "隐私政策", showsDivider: false)
                }
            }

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

private struct SettingsSection<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if let title {
                Text(title)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppSemanticColor.textPrimary)
                    .padding(.horizontal, AppSpacing.xs)
            }
            content
        }
    }
}

private struct SettingsMenuCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        AppCard {
            VStack(spacing: 0) {
                content
            }
        }
    }
}

private struct SettingsMenuRow: View {
    let title: String
    var showsDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppSemanticColor.textPrimary)
                Spacer()
                Text("即将上线")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: AppIconSize.xs, weight: .semibold))
                    .foregroundStyle(AppSemanticColor.textTertiary)
            }
            .frame(minHeight: 52)
        }
        .overlay(alignment: .bottom) {
            if showsDivider {
                Divider()
                    .overlay(AppSemanticColor.border)
            }
        }
    }
}
