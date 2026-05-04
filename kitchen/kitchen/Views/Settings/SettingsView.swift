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

            SettingsSection(title: L10n.tr("Preferences")) {
                PreferencesSection(
                    notificationsEnabled: $notificationsEnabled,
                    hapticsEnabled: $hapticsEnabled,
                    themeMode: $themeMode
                )
            }

            if store.hasKitchen {
                SettingsSection(title: L10n.tr("Membership")) {
                    SettingsMenuCard {
                        UpgradeMenuRow(
                            entitlement: store.entitlement,
                            canUpgrade: store.canUpgradeEntitlement,
                            onTap: { modalRouter.present(.upgrade) }
                        )
                    }
                }
            }

            SettingsSection(title: L10n.tr("Help & Feedback")) {
                SettingsMenuCard {
                    SettingsMenuRow(
                        title: L10n.tr("Feedback"),
                        showsDivider: false,
                        onTap: { modalRouter.present(.feedback) }
                    )
                    // TODO: when app 上架以后启用
                    // SettingsMenuRow(title: "给我们评分")
                    // SettingsMenuRow(title: "分享给家人", showsDivider: false)
                }
            }

            SettingsSection(title: L10n.tr("Account & Privacy")) {
                SettingsMenuCard {
                    SettingsMenuRow(
                        title: purchaseManager.isRestoring ? L10n.tr("Restoring purchases") : L10n.tr("Restore Purchases"),
                        isEnabled: purchaseManager.isRestoring == false,
                        onTap: { Task { await restorePurchases() } }
                    )
                    SettingsMenuRow(
                        title: isRedeemingCode ? L10n.tr("Opening redeem flow") : L10n.tr("Redeem Offer Code"),
                        isEnabled: isRedeemingCode == false,
                        onTap: { redeemCode() }
                    )
                    SettingsMenuRow(
                        title: L10n.tr("Privacy Policy"),
                        showsDivider: false,
                        url: privacyPolicyURL
                    )
                }
            }

            AppButton(title: signOutPendingConfirm ? L10n.tr("Confirm Sign Out") : L10n.tr("Sign Out"), role: .destructive) {
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
                feedbackRouter.show(.high(message: L10n.tr("Purchases restored"), systemImage: "checkmark.circle.fill"))
            } else {
                feedbackRouter.show(.low(message: L10n.tr("No purchases to restore"), systemImage: "info.circle"))
            }
        } catch {
            feedbackRouter.show(store.feedback(for: error))
        }
    }

    private func redeemCode() {
        isRedeemingCode = true
        purchaseManager.redeemCode()
        feedbackRouter.show(.low(message: L10n.tr("Redeem flow opened"), systemImage: "ticket"))
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
                        Text(L10n.tr("%lld / %lld used", Int64(entitlement.activeDishCount), Int64(limit)))
                            .font(AppTypography.caption)
                            .foregroundStyle(AppSemanticColor.textSecondary)
                    }
                }
                if entitlement.isUnlimited {
                    Text(L10n.tr("Unlimited dishes"))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppSemanticColor.textSecondary)
                }
            }
            Spacer()
            if canUpgrade {
                Text("Upgrade")
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
                Text("Coming later")
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
