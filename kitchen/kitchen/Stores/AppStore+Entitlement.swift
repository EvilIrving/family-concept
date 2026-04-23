import Foundation

// MARK: - AppStore: Entitlement / IAP

extension AppStore {

    // MARK: Derived access

    var currentDishLimit: Int? {
        entitlement.isUnlimited ? nil : entitlement.dishLimit
    }

    var isDishLimitReached: Bool {
        // 购买完成但同步未回来时，乐观放行
        if pendingEntitlementUpgrade != nil { return false }
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
            self.entitlement = KitchenEntitlement(
                planCode: resp.planCode,
                dishLimit: resp.dishLimit,
                isUnlimited: resp.isUnlimited,
                activeDishCount: resp.activeDishCount,
                storeProductId: resp.storeProductId,
                activatedAt: resp.activatedAt
            )
            // 同步后清除过渡态（如果服务端已反映升级）
            if let pending = pendingEntitlementUpgrade,
               resp.storeProductId == pending.productID {
                self.pendingEntitlementUpgrade = nil
            }
        } catch APIError.unauthorized {
            clearSession()
        } catch {
            consumeError(error)
        }
    }

    // MARK: Sync after purchase

    /// 购买成功后调用。保留 pending 过渡态直到服务端确认。
    func applyVerifiedTransaction(
        productID: String,
        originalTransactionID: String,
        appAccountToken: String?
    ) async {
        guard let kitchen else { return }
        pendingEntitlementUpgrade = PendingEntitlementUpgrade(
            productID: productID,
            startedAt: Date()
        )
        do {
            _ = try await apiClient.syncIAPTransaction(
                kitchenID: kitchen.id,
                productID: productID,
                originalTransactionID: originalTransactionID,
                appAccountToken: appAccountToken,
                authToken: authToken
            )
            await refreshEntitlement()
        } catch {
            // 保留 pending 状态，用户可手动重试（恢复购买）
            consumeError(error)
        }
    }
}
