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
            signedTransaction: String
        ) -> Endpoint<EntitlementSyncResponse> {
            Endpoint(
                path: "/api/v1/kitchens/\(kitchenID)/iap/sync",
                method: "POST",
                body: SyncBody(
                    signedTransaction: signedTransaction
                ),
                requiresAuth: true
            )
        }
    }
}

// MARK: - Response Models

struct EntitlementResponse: Decodable {
    let status: EntitlementStatus
    let planCode: PlanCode
    let dishLimit: Int?
    let isUnlimited: Bool
    let activeDishCount: Int
    let storeProductId: String?
    let activatedAt: String?
    let originalTransactionId: String?
    let revokedAt: String?
    let revocationReason: String?
    let lastVerifiedAt: String?
}

struct EntitlementSyncResponse: Decodable {
    let status: EntitlementStatus
    let planCode: PlanCode
    let dishLimit: Int?
    let isUnlimited: Bool
    let activeDishCount: Int
    let storeProductId: String?
    let activatedAt: String?
    let originalTransactionId: String?
    let revokedAt: String?
    let revocationReason: String?
    let lastVerifiedAt: String?
}

private struct SyncBody: Encodable {
    let signedTransaction: String

    enum CodingKeys: String, CodingKey {
        case signedTransaction = "signed_transaction"
    }
}
