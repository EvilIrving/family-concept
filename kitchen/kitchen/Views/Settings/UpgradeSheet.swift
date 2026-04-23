import SwiftUI
import StoreKit

struct UpgradeSheet: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var isPurchasing = false
    @State private var localError: String?

    var body: some View {
        AppScrollPage {
            Text("升级菜品套餐")
                .font(AppTypography.pageTitle)
                .foregroundStyle(AppSemanticColor.textPrimary)
                .padding(.horizontal, AppSpacing.md)
        } content: {
            currentPlanCard
            productsList
            if let localError {
                Text(localError)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.textSecondary)
                    .padding(.horizontal, AppSpacing.md)
            }
            AppButton(title: "恢复购买", style: .secondary) {
                Task { await purchaseManager.restore() }
            }
        }
        .task {
            if purchaseManager.products.isEmpty {
                await purchaseManager.loadProducts()
            }
        }
    }

    private var currentPlanCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("当前套餐")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.textSecondary)
                Text(store.entitlement.planCode.displayName)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppSemanticColor.textPrimary)
                if !store.entitlement.isUnlimited, let limit = store.entitlement.dishLimit {
                    Text("已用 \(store.entitlement.activeDishCount) / \(limit)")
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppSemanticColor.textSecondary)
                }
                if store.pendingEntitlementUpgrade != nil {
                    Text("购买已完成，正在同步权限…")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppSemanticColor.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var productsList: some View {
        VStack(spacing: AppSpacing.md) {
            ForEach(PurchaseProduct.allCases, id: \.rawValue) { code in
                productRow(for: code)
            }
        }
    }

    private func productRow(for code: PurchaseProduct) -> some View {
        let product = purchaseManager.product(for: code)
        let alreadyOwned = store.entitlement.planCode == code.plan
            || store.entitlement.planCode == .dishesUnlimited

        return AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Text(code.plan.displayName)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppSemanticColor.textPrimary)
                    Spacer()
                    if let product {
                        Text(product.displayPrice)
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppSemanticColor.textPrimary)
                    }
                }
                if let description = product?.description, !description.isEmpty {
                    Text(description)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppSemanticColor.textSecondary)
                }
                AppButton(
                    title: alreadyOwned ? "已拥有" : (isPurchasing ? "购买中…" : "购买"),
                    style: alreadyOwned ? .secondary : .primary,
                    phase: isPurchasing ? .initialLoading(label: "购买中…") : .idle
                ) {
                    guard let product, !alreadyOwned, !isPurchasing else { return }
                    Task { await buy(product) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func buy(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        localError = nil
        do {
            let token = UUID()
            let outcome = try await purchaseManager.purchase(product, appAccountToken: token)
            switch outcome {
            case .success(let productID, let txID, let accountToken):
                await store.applyVerifiedTransaction(
                    productID: productID,
                    originalTransactionID: txID,
                    appAccountToken: accountToken
                )
                dismiss()
            case .userCancelled:
                break
            case .pending:
                localError = "购买待家长同意或等待处理"
            case .verificationFailed:
                localError = "交易验证失败，请稍后重试"
            }
        } catch {
            localError = error.localizedDescription
        }
    }
}
