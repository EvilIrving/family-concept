import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var notificationsEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("themeMode") private var themeMode = "system"
    @StateObject private var modalRouter = ModalRouter<SettingsModalRoute>()
    @State private var signOutPendingConfirm = false

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

            SettingsSection(title: "偏好设置") {
                PreferencesSection(
                    notificationsEnabled: $notificationsEnabled,
                    hapticsEnabled: $hapticsEnabled,
                    themeMode: $themeMode
                )
            }

            if store.hasKitchen {
                SettingsSection(title: "会员套餐") {
                    SettingsMenuCard {
                        UpgradeMenuRow(
                            entitlement: store.entitlement,
                            canUpgrade: store.canUpgradeEntitlement,
                            onTap: { modalRouter.present(.upgrade) }
                        )
                    }
                }
            }

            SettingsSection(title: "帮助与反馈") {
                SettingsMenuCard {
                    SettingsMenuRow(
                        title: "意见反馈",
                        showsDivider: false,
                        onTap: { modalRouter.present(.feedback) }
                    )
                    // TODO: when app 上架以后启用
                    // SettingsMenuRow(title: "给我们评分")
                    // SettingsMenuRow(title: "分享给家人", showsDivider: false)
                }
            }

            SettingsSection(title: "账户与隐私") {
                SettingsMenuCard {
                    SettingsMenuRow(
                        title: "恢复购买",
                        onTap: { Task { await purchaseManager.restore() } }
                    )
                    SettingsMenuRow(
                        title: "兑换优惠码",
                        onTap: { purchaseManager.redeemCode() }
                    )
                    SettingsMenuRow(
                        title: "隐私说明",
                        showsDivider: false,
                        url: privacyPolicyURL
                    )
                }
            }

            AppButton(title: signOutPendingConfirm ? "确认退出" : "退出登录", role: .destructive) {
                if signOutPendingConfirm {
                    signOutPendingConfirm = false
                    Task { await store.signOut() }
                } else {
                    signOutPendingConfirm = true
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(3))
                        signOutPendingConfirm = false
                    }
                }
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
                    .presentationDetents([.fraction(0.67)])
            case .feedback:
                FeedbackSheet()
                    .environmentObject(store)
                    .environmentObject(feedbackRouter)
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
        .environmentObject(AppLanguageStore())
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
        HStack(spacing: AppSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entitlement.planCode.displayName)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppSemanticColor.textPrimary)
                    if !entitlement.isUnlimited, let limit = entitlement.dishLimit {
                        Text("已用 \(entitlement.activeDishCount) / \(limit) 道")
                            .font(AppTypography.caption)
                            .foregroundStyle(AppSemanticColor.textSecondary)
                    }
                }
                if entitlement.isUnlimited {
                    Text("不限菜品数量")
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
        .frame(minHeight: AppDimension.listRowMinHeight)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

private struct SettingsMenuRow: View {
    @Environment(\.openURL) private var openURL

    let title: String
    var showsDivider: Bool = true
    var url: URL? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        rowContent
            .contentShape(Rectangle())
            .onTapGesture {
                if let url {
                    openURL(url)
                } else {
                    onTap?()
                }
            }
    }

    private var rowContent: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textPrimary)
            Spacer()
            if url == nil, onTap == nil {
                Text("稍后推出")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.textSecondary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: AppIconSize.xs, weight: .semibold))
                .foregroundStyle(AppSemanticColor.textTertiary)
        }
        .frame(minHeight: AppDimension.listRowMinHeight)
        .overlay(alignment: .bottom) {
            if showsDivider {
                Divider()
                    .overlay(AppSemanticColor.border)
            }
        }
    }
}
