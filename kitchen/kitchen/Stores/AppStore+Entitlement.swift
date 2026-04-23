import Foundation

// MARK: - AppStore: Entitlement / IAP

extension AppStore {

    // MARK: Derived access

    var currentDishLimit: Int? {
        entitlement.isUnlimited ? nil : entitlement.dishLimit
    }

    var isDishLimitReached: Bool {
        if shouldTrustPendingEntitlementUpgrade { return false }
        return entitlement.isAtLimit
    }

    var canUpgradeEntitlement: Bool {
        canManageDishes && entitlement.planCode != .dishesUnlimited
    }

    // MARK: Refresh

    func refreshEntitlement() async {
        guard let kitchen else { return }
        do {
            let resp = try await apiClient.fetchEntitlement(kitchenID: kitchen.id, authToken: authToken)
            self.entitlement = entitlement(from: resp)
            clearPendingUpgradeIfSettled()
        } catch APIError.unauthorized {
            clearSession()
        } catch {
            consumeError(error)
        }
    }

    // MARK: Sync after purchase

    /// 购买成功后调用。保留 pending 过渡态直到服务端确认。
    func applyVerifiedTransaction(signedTransaction: String, productID: String) async {
        guard let kitchen else { return }
        pendingEntitlementUpgrade = PendingEntitlementUpgrade(
            productID: productID,
            startedAt: Date()
        )
        do {
            let response = try await apiClient.syncIAPTransaction(
                kitchenID: kitchen.id,
                signedTransaction: signedTransaction,
                authToken: authToken
            )
            entitlement = entitlement(from: response)
            clearPendingUpgradeIfSettled()
        } catch {
            consumeError(error)
        }
    }

    private var shouldTrustPendingEntitlementUpgrade: Bool {
        guard let pendingEntitlementUpgrade else { return false }
        if entitlement.status == .revoked { return false }
        if entitlement.status == .active && entitlement.storeProductId == pendingEntitlementUpgrade.productID {
            return false
        }
        return Date().timeIntervalSince(pendingEntitlementUpgrade.startedAt) < 120
    }

    private func clearPendingUpgradeIfSettled() {
        guard let pending = pendingEntitlementUpgrade else { return }
        if entitlement.status == .active, entitlement.storeProductId == pending.productID {
            pendingEntitlementUpgrade = nil
            return
        }
        if entitlement.status == .revoked {
            pendingEntitlementUpgrade = nil
            return
        }
        if entitlement.status == .notFound,
           Date().timeIntervalSince(pending.startedAt) >= 120 {
            pendingEntitlementUpgrade = nil
        }
    }

    private func entitlement(from response: EntitlementResponse) -> KitchenEntitlement {
        KitchenEntitlement(
            status: response.status,
            planCode: response.planCode,
            dishLimit: response.dishLimit,
            isUnlimited: response.isUnlimited,
            activeDishCount: response.activeDishCount,
            storeProductId: response.storeProductId,
            activatedAt: response.activatedAt,
            originalTransactionId: response.originalTransactionId,
            revokedAt: response.revokedAt,
            revocationReason: response.revocationReason,
            lastVerifiedAt: response.lastVerifiedAt
        )
    }

    private func entitlement(from response: EntitlementSyncResponse) -> KitchenEntitlement {
        KitchenEntitlement(
            status: response.status,
            planCode: response.planCode,
            dishLimit: response.dishLimit,
            isUnlimited: response.isUnlimited,
            activeDishCount: response.activeDishCount,
            storeProductId: response.storeProductId,
            activatedAt: response.activatedAt,
            originalTransactionId: response.originalTransactionId,
            revokedAt: response.revokedAt,
            revocationReason: response.revocationReason,
            lastVerifiedAt: response.lastVerifiedAt
        )
    }
}
