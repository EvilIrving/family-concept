import Foundation

// MARK: - Onboarding

extension APIClient {
    struct OnboardingResponse: Decodable {
        let device: Device
        let kitchen: Kitchen
        let member: Member
    }

    func onboardingComplete(
        mode: String,
        deviceID: String,
        displayName: String,
        kitchenName: String? = nil,
        inviteCode: String? = nil
    ) async throws -> OnboardingResponse {
        var body: [String: String] = [
            "mode": mode,
            "device_id": deviceID,
            "display_name": displayName,
        ]
        if let kitchenName { body["kitchen_name"] = kitchenName }
        if let inviteCode { body["invite_code"] = inviteCode }

        return try await request(
            "/api/v1/onboarding/complete",
            method: "POST",
            body: body
        )
    }
}

// MARK: - Devices

extension APIClient {
    func registerDevice(deviceID: String, displayName: String) async throws -> Device {
        try await request(
            "/api/v1/devices/register",
            method: "POST",
            body: ["device_id": deviceID, "display_name": displayName]
        )
    }

    func fetchDevice(byDeviceID deviceID: String) async throws -> Device {
        try await request("/api/v1/devices/by-device/\(deviceID)")
    }
}

// MARK: - Kitchens

extension APIClient {
    func fetchKitchen(id: String, deviceId: String) async throws -> Kitchen {
        try await request("/api/v1/kitchens/\(id)", deviceId: deviceId)
    }

    func createKitchen(name: String, deviceId: String) async throws -> Kitchen {
        try await request(
            "/api/v1/kitchens",
            method: "POST",
            body: ["name": name],
            deviceId: deviceId
        )
    }

    func updateKitchen(id: String, name: String, deviceId: String) async throws -> Kitchen {
        try await request(
            "/api/v1/kitchens/\(id)",
            method: "PATCH",
            body: ["name": name],
            deviceId: deviceId
        )
    }

    func rotateInviteCode(kitchenID: String, deviceId: String) async throws -> InviteCodeResult {
        try await request(
            "/api/v1/kitchens/\(kitchenID)/rotate_invite",
            method: "POST",
            deviceId: deviceId
        )
    }

    func joinKitchen(inviteCode: String, deviceId: String) async throws -> JoinResult {
        try await request(
            "/api/v1/kitchens/join",
            method: "POST",
            body: ["invite_code": inviteCode],
            deviceId: deviceId
        )
    }

    struct InviteCodeResult: Decodable {
        let inviteCode: String
    }

    struct JoinResult: Decodable {
        let kitchen: Kitchen
        let member: Member
    }
}

// MARK: - Members

extension APIClient {
    func fetchMembers(kitchenID: String, deviceId: String) async throws -> [Member] {
        try await request("/api/v1/kitchens/\(kitchenID)/members", deviceId: deviceId)
    }

    func removeMember(kitchenID: String, deviceRefID: String, deviceId: String) async throws -> OKResult {
        try await request(
            "/api/v1/kitchens/\(kitchenID)/members/\(deviceRefID)",
            method: "DELETE",
            deviceId: deviceId
        )
    }

    func leaveKitchen(kitchenID: String, deviceId: String) async throws -> OKResult {
        try await request(
            "/api/v1/kitchens/\(kitchenID)/leave",
            method: "POST",
            deviceId: deviceId
        )
    }
}

// MARK: - Dishes

private struct CreateDishBody: Encodable {
    let name: String
    let category: String
    let ingredients: [String]?
}

private struct UpdateDishBody: Encodable {
    let name: String?
    let category: String?
    let ingredients: [String]?
    let imageKey: String?

    enum CodingKeys: String, CodingKey {
        case name, category, ingredients
        case imageKey = "image_key"
    }
}

extension APIClient {
    func fetchDishes(kitchenID: String, deviceId: String) async throws -> [Dish] {
        try await request("/api/v1/kitchens/\(kitchenID)/dishes", deviceId: deviceId)
    }

    func createDish(
        kitchenID: String,
        name: String,
        category: String,
        ingredients: [String]? = nil,
        deviceId: String
    ) async throws -> Dish {
        try await request(
            "/api/v1/kitchens/\(kitchenID)/dishes",
            method: "POST",
            body: CreateDishBody(name: name, category: category, ingredients: ingredients),
            deviceId: deviceId
        )
    }

    func updateDish(
        id: String,
        name: String? = nil,
        category: String? = nil,
        ingredients: [String]? = nil,
        imageKey: String? = nil,
        deviceId: String
    ) async throws -> Dish {
        try await request(
            "/api/v1/dishes/\(id)",
            method: "PATCH",
            body: UpdateDishBody(name: name, category: category, ingredients: ingredients, imageKey: imageKey),
            deviceId: deviceId
        )
    }

    func archiveDish(id: String, deviceId: String) async throws -> OKResult {
        try await request(
            "/api/v1/dishes/\(id)",
            method: "DELETE",
            deviceId: deviceId
        )
    }
}

// MARK: - Orders

private struct AddOrderItemBody: Encodable {
    let dishID: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case dishID = "dish_id"
        case quantity
    }
}

private struct UpdateOrderItemBody: Encodable {
    let status: String?
    let quantity: Int?
}

extension APIClient {
    struct OpenOrderResponse: Decodable {
        let id: String
        let kitchenId: String
        let status: OrderStatus
        let createdByDeviceId: String
        let createdAt: String
        let finishedAt: String?
        let items: [OrderItem]?
    }

    func fetchOpenOrder(kitchenID: String, deviceId: String) async throws -> OpenOrderResponse? {
        let result: OpenOrderResponse? = try await request(
            "/api/v1/kitchens/\(kitchenID)/orders/open",
            deviceId: deviceId
        )
        return result
    }

    func createOrder(kitchenID: String, deviceId: String) async throws -> Order {
        try await request(
            "/api/v1/kitchens/\(kitchenID)/orders",
            method: "POST",
            deviceId: deviceId
        )
    }

    func addOrderItem(orderID: String, dishID: String, quantity: Int = 1, deviceId: String) async throws -> OrderItem {
        try await request(
            "/api/v1/orders/\(orderID)/items",
            method: "POST",
            body: AddOrderItemBody(dishID: dishID, quantity: quantity),
            deviceId: deviceId
        )
    }

    func updateOrderItem(
        id: String,
        status: ItemStatus? = nil,
        quantity: Int? = nil,
        deviceId: String
    ) async throws -> OrderItem {
        try await request(
            "/api/v1/order_items/\(id)",
            method: "PATCH",
            body: UpdateOrderItemBody(status: status?.rawValue, quantity: quantity),
            deviceId: deviceId
        )
    }

    func finishOrder(id: String, deviceId: String) async throws -> Order {
        try await request(
            "/api/v1/orders/\(id)/finish",
            method: "POST",
            deviceId: deviceId
        )
    }
}

// MARK: - Shopping List

extension APIClient {
    func fetchShoppingList(orderID: String, deviceId: String) async throws -> [ShoppingListItem] {
        try await request("/api/v1/orders/\(orderID)/shopping_list", deviceId: deviceId)
    }
}

// MARK: - Shared Decodable

struct OKResult: Decodable {
    let ok: Bool
}
