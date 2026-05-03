import SwiftUI
import StoreKit

struct UpgradeSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var didFailLoadingProducts = false
    @State private var localError: String?
    @State private var selectedProductCode: PurchaseProduct = .dishesUnlimited

    var body: some View {
        AppSheetContainer(title: nil, dismissTitle: L10n.tr("关闭"), onDismiss: { dismiss() }) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    statusMessage
                    productsList
                    productLoadingMessage
                    planComparison
                    if let localError {
                        Text(localError)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppSemanticColor.textSecondary)
                    }
                    AppButton(
                        title: continueTitle,
                        role: isContinueAvailable ? .primary : .secondary,
                        phase: isPurchasing ? .initialLoading(label: L10n.tr("购买中…")) : .idle
                    ) {
                        continueTapped()
                    }
                }
                .padding(.bottom, AppSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .overlay {
            if isPurchasing {
                purchaseOverlay
            }
        }
        .interactiveDismissDisabled(isPurchasing)
        .task {
            selectedProductCode = defaultSelectedProductCode
            if purchaseManager.products.isEmpty {
                await loadProducts()
            }
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        if store.pendingEntitlementUpgrade != nil {
            inlineMessage(L10n.tr("购买已完成，正在同步权限…"))
        } else if store.entitlement.status == .pendingVerificationFailed {
            inlineMessage(L10n.tr("同步失败，当前展示的是上次已确认的权益，可稍后在设置中恢复购买。"))
        } else if store.entitlement.status == .revoked {
            inlineMessage(L10n.tr("该权益已被撤销，当前不可用。"))
        }
    }

    private func inlineMessage(_ message: String) -> some View {
        Text(message)
            .font(AppTypography.caption)
            .foregroundStyle(AppSemanticColor.textSecondary)
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppSemanticColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    @ViewBuilder
    private var productLoadingMessage: some View {
        if didFailLoadingProducts {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("商品信息加载失败，请稍后重试。")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.textSecondary)
                AppLinkButton(title: L10n.tr("重试")) {
                    Task { await loadProducts() }
                }
                .disabled(purchaseManager.isLoadingProducts)
            }
            .padding(AppSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppSemanticColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        }
    }

    private var purchaseOverlay: some View {
        ZStack {
            AppSemanticColor.surface.opacity(0.86)
                .ignoresSafeArea()
            AppLoadingIndicator(label: L10n.tr("购买处理中"), tone: .primary)
                .padding(AppSpacing.md)
                .background(AppSemanticColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                        .stroke(AppSemanticColor.border, lineWidth: AppBorderWidth.hairline)
                }
        }
    }

    private var productsList: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            ForEach(PurchaseProduct.allCases, id: \.rawValue) { code in
                productOption(for: code)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func productOption(for code: PurchaseProduct) -> some View {
        let product = purchaseManager.product(for: code)
        let isSelected = selectedProductCode == code
        let isCurrent = isCurrentPlan(code.plan)
        let isSelectable = isPlanSelectable(code.plan)

        return AppRowButton(action: {
            guard isSelectable else { return }
            selectedProductCode = code
        }, accessory: .none) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .top, spacing: AppSpacing.xs) {
                    Image(systemName: isSelected && isSelectable ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: AppIconSize.lg, weight: .semibold))
                        .foregroundStyle(isSelected && isSelectable ? AppSemanticColor.primary : AppSemanticColor.textTertiary)

                    Spacer(minLength: AppSpacing.xs)

                    if code == .dishesUnlimited {
                        Text("推荐")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppSemanticColor.primary)
                            .padding(.horizontal, AppSpacing.xs)
                            .padding(.vertical, AppSpacing.xxs)
                            .background(AppSemanticColor.interactiveSecondary, in: Capsule())
                    }
                }

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(planTitle(for: code))
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppSemanticColor.textPrimary)
                    Text(planSubtitle(for: code))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppSemanticColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppSpacing.xs)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(priceTitle(for: code, product: product))
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(isCurrent ? AppSemanticColor.textSecondary : AppSemanticColor.textPrimary)
                    if isCurrent {
                        Text("当前")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppSemanticColor.textSecondary)
                    }
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
            .background(isSelected && isSelectable ? AppSemanticColor.interactiveSecondary : AppSemanticColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .stroke(isSelected && isSelectable ? AppSemanticColor.primary : AppSemanticColor.border, lineWidth: isSelected && isSelectable ? AppBorderWidth.strong : AppBorderWidth.hairline)
            }
        }
        .disabled(!isSelectable)
        .accessibilityAddTraits(isSelected && isSelectable ? .isSelected : [])
    }

    private var planComparison: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("可保存菜品数量对比")
                .font(AppTypography.cardTitle)
                .foregroundStyle(AppSemanticColor.textPrimary)
            HStack(spacing: AppSpacing.sm) {
                dishLimitItem(title: L10n.tr("免费"), value: L10n.tr("10 道"), isEmphasized: false)
                dishLimitItem(title: "Essentials", value: L10n.tr("50 道"), isEmphasized: true)
                dishLimitItem(title: "Unlimited", value: L10n.tr("不限量"), isEmphasized: true)
            }
        }
        .padding(AppSpacing.md)
        .background(AppSemanticColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .stroke(AppSemanticColor.border, lineWidth: AppBorderWidth.hairline)
        }
    }

    private func dishLimitItem(title: String, value: String, isEmphasized: Bool) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppSemanticColor.textSecondary)
            Text(value)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(isEmphasized ? AppSemanticColor.primary : AppSemanticColor.textPrimary)
        }
        .padding(AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppSemanticColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
    }

    private var selectedProduct: Product? {
        purchaseManager.product(for: selectedProductCode)
    }

    private var defaultSelectedProductCode: PurchaseProduct {
        switch store.entitlement.planCode {
        case .free:
            return .dishesUnlimited
        case .dishesFifty, .dishesUnlimited:
            return .dishesUnlimited
        }
    }

    private var isContinueAvailable: Bool {
        store.entitlement.planCode == .free && selectedProduct != nil
    }

    private var continueTitle: String {
        switch store.entitlement.planCode {
        case .free:
            return L10n.tr("继续")
        case .dishesFifty:
            return L10n.tr("即将支持")
        case .dishesUnlimited:
            return L10n.tr("您已经是 ∞")
        }
    }

    private func isCurrentPlan(_ plan: PlanCode) -> Bool {
        store.entitlement.planCode == plan
    }

    private func isPlanSelectable(_ plan: PlanCode) -> Bool {
        switch store.entitlement.planCode {
        case .free:
            return plan != .free
        case .dishesFifty:
            return false
        case .dishesUnlimited:
            return false
        }
    }

    private func priceTitle(for code: PurchaseProduct, product: Product?) -> String {
        if isCurrentPlan(code.plan) {
            return L10n.tr("当前")
        }
        if store.entitlement.planCode == .dishesFifty && code == .dishesUnlimited {
            return L10n.tr("即将支持")
        }
        if didFailLoadingProducts && product == nil {
            return L10n.tr("加载失败")
        }
        return product?.displayPrice ?? L10n.tr("价格加载中")
    }

    private func planTitle(for code: PurchaseProduct) -> String {
        switch code {
        case .dishesFifty:
            return "Essentials"
        case .dishesUnlimited:
            return "Unlimited"
        }
    }

    private func planSubtitle(for code: PurchaseProduct) -> String {
        switch code {
        case .dishesFifty:
            return L10n.tr("适合刚开始整理家庭菜单")
        case .dishesUnlimited:
            if store.entitlement.planCode == .dishesFifty {
                return L10n.tr("Essentials 升级即将支持")
            }
            return L10n.tr("适合长期记录全部菜谱")
        }
    }

    private func continueTapped() {
        guard !isPurchasing else { return }
        guard isContinueAvailable else {
            localError = unavailableContinueMessage
            return
        }
        guard let product = selectedProduct else {
            localError = L10n.tr("商品信息尚未加载完成，请稍后重试")
            return
        }
        Task { await buy(product) }
    }

    private var unavailableContinueMessage: String {
        switch store.entitlement.planCode {
        case .free:
            return didFailLoadingProducts ? L10n.tr("商品信息加载失败，请重试后继续") : L10n.tr("商品信息尚未加载完成，请稍后重试")
        case .dishesFifty:
            return L10n.tr("Essentials 升级到 Unlimited 即将支持。")
        case .dishesUnlimited:
            return L10n.tr("当前已经是 Unlimited，无需重复购买。")
        }
    }

    private func loadProducts() async {
        didFailLoadingProducts = false
        await purchaseManager.loadProducts()
        didFailLoadingProducts = purchaseManager.products.isEmpty
    }

    private func buy(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        localError = nil
        do {
            guard let accountID = store.currentAccount?.id,
                  let kitchenID = store.kitchen?.id,
                  let token = AppAccountTokenBuilder.build(accountID: accountID, kitchenID: kitchenID)
            else {
                localError = L10n.tr("账户信息不完整，无法发起购买")
                return
            }
            let outcome = try await purchaseManager.purchase(product, appAccountToken: token)
            switch outcome {
            case .success(let signedTransaction):
                await store.applyVerifiedTransaction(signedTransaction: signedTransaction, productID: product.id)
                dismiss()
            case .userCancelled:
                break
            case .pending:
                localError = L10n.tr("购买待家长同意或等待处理")
            case .verificationFailed:
                localError = L10n.tr("交易验证失败，请稍后重试")
            }
        } catch {
            localError = error.localizedDescription
        }
    }
}
