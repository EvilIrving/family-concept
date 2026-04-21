import Foundation

// MARK: - Orders Endpoints

extension APIEndpoints {
    enum Orders {
        static func fetchOpen(kitchenID: String) -> Endpoint<APIClient.OpenOrderResponse?> {
            Endpoint(path: "/api/v1/kitchens/\(kitchenID)/orders/open", requiresAuth: true)
        }

        static func fetchHistory(kitchenID: String) -> Endpoint<[OrderHistoryEntry]> {
            Endpoint(path: "/api/v1/kitchens/\(kitchenID)/orders/history", requiresAuth: true)
        }

        static func fetchDetail(orderID: String) -> Endpoint<OrderDetail> {
            Endpoint(path: "/api/v1/orders/\(orderID)", requiresAuth: true)
        }

        static func create(kitchenID: String) -> Endpoint<Order> {
            Endpoint(
                path: "/api/v1/kitchens/\(kitchenID)/orders",
                method: "POST",
                requiresAuth: true
            )
        }

        static func addItem(orderID: String, dishID: String, quantity: Int) -> Endpoint<OrderItem> {
            Endpoint(
                path: "/api/v1/orders/\(orderID)/items",
                method: "POST",
                body: AddOrderItemBody(dishID: dishID, quantity: quantity),
                requiresAuth: true
            )
        }

        static func updateItem(id: String, status: ItemStatus? = nil, quantity: Int? = nil) -> Endpoint<OrderItem> {
            Endpoint(
                path: "/api/v1/order_items/\(id)",
                method: "PATCH",
                body: UpdateOrderItemBody(status: status?.rawValue, quantity: quantity),
                requiresAuth: true
            )
        }

        static func removeItem(id: String) -> Endpoint<OKResult> {
            Endpoint(path: "/api/v1/order_items/\(id)", method: "DELETE", requiresAuth: true)
        }

        static func finish(id: String) -> Endpoint<Order> {
            Endpoint(path: "/api/v1/orders/\(id)/finish", method: "POST", requiresAuth: true)
        }
    }
}

// MARK: - Request Bodies

struct AddOrderItemBody: Encodable {
    let dishID: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case dishID = "dish_id"
        case quantity
    }
}

struct UpdateOrderItemBody: Encodable {
    let status: String?
    let quantity: Int?
}

// MARK: - Shared Response Types

struct OKResult: Decodable {
    let ok: Bool
}
