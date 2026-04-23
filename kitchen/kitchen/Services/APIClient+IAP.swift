import Foundation

extension APIClient {
    func fetchEntitlement(kitchenID: String, authToken: String) async throws -> EntitlementResponse {
        try await request(APIEndpoints.IAP.fetchEntitlement(kitchenID: kitchenID), authToken: authToken)
    }

    func syncIAPTransaction(
        kitchenID: String,
        productID: String,
        originalTransactionID: String,
        appAccountToken: String?,
        authToken: String
    ) async throws -> EntitlementSyncResponse {
        try await request(
            APIEndpoints.IAP.sync(
                kitchenID: kitchenID,
                productID: productID,
                originalTransactionID: originalTransactionID,
                appAccountToken: appAccountToken
            ),
            authToken: authToken
        )
    }
}
