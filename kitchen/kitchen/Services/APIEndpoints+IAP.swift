import Foundation

// MARK: - IAP / Entitlement Endpoints

extension APIEndpoints {
    enum IAP {
        static func fetchEntitlement(kitchenID: String) -> Endpoint<EntitlementResponse> {
            Endpoint(
                path: "/api/v1/kitchens/\(kitchenID)/entitlement",
                requiresAuth: true
            )
        }

        static func sync(
            kitchenID: String,
            productID: String,
            originalTransactionID: String,
            appAccountToken: String?
        ) -> Endpoint<EntitlementSyncResponse> {
            Endpoint(
                path: "/api/v1/kitchens/\(kitchenID)/iap/sync",
                method: "POST",
                body: SyncBody(
                    productId: productID,
                    originalTransactionId: originalTransactionID,
                    appAccountToken: appAccountToken
                ),
                requiresAuth: true
            )
        }
    }
}

// MARK: - Response Models

struct EntitlementResponse: Decodable {
    let planCode: PlanCode
    let dishLimit: Int?
    let isUnlimited: Bool
    let activeDishCount: Int
    let storeProductId: String?
    let activatedAt: String?
}

struct EntitlementSyncResponse: Decodable {
    let planCode: PlanCode
    let dishLimit: Int?
    let isUnlimited: Bool
    let storeProductId: String?
    let activatedAt: String?
}

private struct SyncBody: Encodable {
    let productId: String
    let originalTransactionId: String
    let appAccountToken: String?

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case originalTransactionId = "original_transaction_id"
        case appAccountToken = "app_account_token"
    }
}
