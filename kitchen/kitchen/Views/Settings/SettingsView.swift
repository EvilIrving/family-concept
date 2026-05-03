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
    @State private var isRedeemingCode = false

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

            SettingsSection(title: L10n.tr("偏好设置")) {
                PreferencesSection(
                    notificationsEnabled: $notificationsEnabled,
                    hapticsEnabled: $hapticsEnabled,
                    themeMode: $themeMode
                )
            }

            if store.hasKitchen {
                SettingsSection(title: L10n.tr("会员套餐")) {
                    SettingsMenuCard {
                        UpgradeMenuRow(
                            entitlement: store.entitlement,
                            canUpgrade: store.canUpgradeEntitlement,
                            onTap: { modalRouter.present(.upgrade) }
                        )
                    }
                }
            }

            SettingsSection(title: L10n.tr("帮助与反馈")) {
                SettingsMenuCard {
                    SettingsMenuRow(
                        title: L10n.tr("意见反馈"),
                        showsDivider: false,
                        onTap: { modalRouter.present(.feedback) }
                    )
                    // TODO: when app 上架以后启用
                    // SettingsMenuRow(title: "给我们评分")
                    // SettingsMenuRow(title: "分享给家人", showsDivider: false)
                }
            }

            SettingsSection(title: L10n.tr("账户与隐私")) {
                SettingsMenuCard {
                    SettingsMenuRow(
                        title: purchaseManager.isRestoring ? L10n.tr("正在恢复购买") : L10n.tr("恢复购买"),
                        isEnabled: purchaseManager.isRestoring == false,
                        onTap: { Task { await restorePurchases() } }
                    )
                    SettingsMenuRow(
                        title: isRedeemingCode ? L10n.tr("正在打开兑换入口") : L10n.tr("兑换优惠码"),
                        isEnabled: isRedeemingCode == false,
                        onTap: { redeemCode() }
                    )
                    SettingsMenuRow(
                        title: L10n.tr("隐私说明"),
                        showsDivider: false,
                        url: privacyPolicyURL
                    )
                }
            }

            AppButton(title: signOutPendingConfirm ? L10n.tr("确认退出") : L10n.tr("退出登录"), role: .destructive) {
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

    private func restorePurchases() async {
        do {
            let restoredCount = try await purchaseManager.restore()
            if restoredCount > 0 {
                feedbackRouter.show(.high(message: L10n.tr("购买已恢复"), systemImage: "checkmark.circle.fill"))
            } else {
                feedbackRouter.show(.low(message: L10n.tr("没有可恢复的购买"), systemImage: "info.circle"))
            }
        } catch {
            feedbackRouter.show(store.feedback(for: error))
        }
    }

    private func redeemCode() {
        isRedeemingCode = true
        purchaseManager.redeemCode()
        feedbackRouter.show(.low(message: L10n.tr("已打开兑换入口"), systemImage: "ticket"))
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            isRedeemingCode = false
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
                        Text(L10n.tr("已用 %lld / %lld 道", Int64(entitlement.activeDishCount), Int64(limit)))
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
    var isEnabled: Bool = true
    var url: URL? = nil
    var onTap: (() -> Void)? = nil

    var body: some View {
        rowContent
            .contentShape(Rectangle())
            .onTapGesture {
                guard isEnabled else { return }
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
                .foregroundStyle(isEnabled ? AppSemanticColor.textPrimary : AppSemanticColor.textTertiary)
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
