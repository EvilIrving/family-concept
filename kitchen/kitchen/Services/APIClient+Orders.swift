import Foundation

// MARK: - APIClient Extensions: Orders

extension APIClient {
    struct OpenOrderResponse: Decodable {
        let id: String
        let kitchenId: String
        let status: OrderStatus
        let createdByAccountId: String
        let createdAt: String
        let finishedAt: String?
        let items: [OrderItem]?
    }

    func fetchOpenOrder(kitchenID: String, authToken: String) async throws -> OpenOrderResponse? {
        try await request(APIEndpoints.Orders.fetchOpen(kitchenID: kitchenID), authToken: authToken)
    }

    func fetchOrderHistory(kitchenID: String, authToken: String) async throws -> [OrderHistoryEntry] {
        try await request(APIEndpoints.Orders.fetchHistory(kitchenID: kitchenID), authToken: authToken)
    }

    func fetchOrderDetail(orderID: String, authToken: String) async throws -> OrderDetail {
        try await request(APIEndpoints.Orders.fetchDetail(orderID: orderID), authToken: authToken)
    }

    func createOrder(kitchenID: String, authToken: String) async throws -> Order {
        try await request(APIEndpoints.Orders.create(kitchenID: kitchenID), authToken: authToken)
    }

    func addOrderItem(orderID: String, dishID: String, quantity: Int = 1, authToken: String) async throws -> OrderItem {
        try await request(
            APIEndpoints.Orders.addItem(orderID: orderID, dishID: dishID, quantity: quantity),
            authToken: authToken
        )
    }

    func updateOrderItem(
        id: String,
        status: ItemStatus? = nil,
        quantity: Int? = nil,
        authToken: String
    ) async throws -> OrderItem {
        try await request(
            APIEndpoints.Orders.updateItem(id: id, status: status, quantity: quantity),
            authToken: authToken
        )
    }

    func removeOrderItem(id: String, authToken: String) async throws -> OKResult {
        try await request(APIEndpoints.Orders.removeItem(id: id), authToken: authToken)
    }

    func finishOrder(id: String, authToken: String) async throws -> Order {
        try await request(APIEndpoints.Orders.finish(id: id), authToken: authToken)
    }
}
