import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var notificationsEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("themeMode") private var themeMode = "system"
    @StateObject private var modalRouter = ModalRouter<SettingsModalRoute>()

    private let privacyPolicyURL = URL(string: "https://evilirving.github.io/family-concept")!

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

            if store.hasKitchen {
                SettingsSection(title: "套餐") {
                    SettingsMenuCard {
                        UpgradeMenuRow(
                            entitlement: store.entitlement,
                            canUpgrade: store.canUpgradeEntitlement,
                            onTap: { modalRouter.present(.upgrade) }
                        )
                    }
                }
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
                    SettingsMenuRow(
                        title: "恢复购买",
                        onTap: { Task { await purchaseManager.restore() } }
                    )
                    SettingsMenuRow(
                        title: "隐私政策",
                        showsDivider: false,
                        url: privacyPolicyURL
                    )
                }
            }

            AppButton(title: "退出登录", style: .destructive) {
                Task { await store.signOut() }
            }
        }
        .sheet(item: modalRouteBinding, onDismiss: { modalRouter.handleDismissedCurrent() }) { route in
            switch route {
            case .member(let token):
                MemberRoleSheet(memberAccountID: token.accountID)
                    .environmentObject(store)
                    .environmentObject(feedbackRouter)
                    .presentationBackground(.clear)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
            case .upgrade:
                UpgradeSheet()
                    .environmentObject(store)
                    .environmentObject(purchaseManager)
                    .presentationDetents([.large])
            }
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
        .environmentObject(AppFeedbackRouter.shared)
        .environmentObject(PurchaseManager())
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

private struct UpgradeMenuRow: View {
    let entitlement: KitchenEntitlement
    let canUpgrade: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(entitlement.planCode.displayName)
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppSemanticColor.textPrimary)
                        if !entitlement.isUnlimited, let limit = entitlement.dishLimit {
                            Text("已用 \(entitlement.activeDishCount) / \(limit) 道菜")
                                .font(AppTypography.caption)
                                .foregroundStyle(AppSemanticColor.textSecondary)
                        }
                    }
                    if entitlement.isUnlimited {
                        Text("菜品数量无上限")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppSemanticColor.textSecondary)
                    }
                }
                Spacer()
                if canUpgrade {
                    Text("升级")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppSemanticColor.textSecondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: AppIconSize.xs, weight: .semibold))
                    .foregroundStyle(AppSemanticColor.textTertiary)
            }
            .contentShape(Rectangle())
            .frame(minHeight: 52)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsMenuRow: View {
    let title: String
    var showsDivider: Bool = true
    var url: URL? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        if let url {
            Link(destination: url) {
                rowContent
            }
            .buttonStyle(.plain)
        } else {
            Button(action: { onTap?() }) {
                rowContent
            }
            .buttonStyle(.plain)
            .disabled(onTap == nil)
        }
    }

    private var rowContent: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textPrimary)
            Spacer()
            if url == nil, onTap == nil {
                Text("即将上线")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: AppIconSize.xs, weight: .semibold))
                .foregroundStyle(AppSemanticColor.textTertiary)
        }
        .contentShape(Rectangle())
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Divider()
                    .overlay(AppSemanticColor.border)
            }
        }
    }
}
