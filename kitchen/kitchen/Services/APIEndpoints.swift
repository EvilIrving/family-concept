import Foundation

// MARK: - Auth

extension APIClient {
    func register(userName: String, password: String, nickName: String) async throws -> AuthResponse {
        try await request(
            "/api/v1/auth/register",
            method: "POST",
            body: ["user_name": userName, "password": password, "nick_name": nickName]
        )
    }

    func login(userName: String, password: String) async throws -> AuthResponse {
        try await request(
            "/api/v1/auth/login",
            method: "POST",
            body: ["user_name": userName, "password": password]
        )
    }

    func logout(authToken: String) async throws -> OKResult {
        try await request(
            "/api/v1/auth/logout",
            method: "POST",
            authToken: authToken
        )
    }

    func fetchMe(authToken: String) async throws -> AuthMeResponse {
        try await request("/api/v1/auth/me", authToken: authToken)
    }
}

// MARK: - Onboarding

extension APIClient {
    struct OnboardingResponse: Decodable {
        let account: Account
        let kitchen: Kitchen
        let member: Member
    }

    func onboardingComplete(
        mode: String,
        authToken: String,
        nickName: String? = nil,
        inviteCode: String? = nil,
        kitchenName: String? = nil
    ) async throws -> OnboardingResponse {
        var body: [String: String] = ["mode": mode]
        if let nickName { body["nick_name"] = nickName }
        if let inviteCode { body["invite_code"] = inviteCode }
        if let kitchenName { body["kitchen_name"] = kitchenName }

        return try await request(
            "/api/v1/onboarding/complete",
            method: "POST",
            body: body,
            authToken: authToken
        )
    }
}

// MARK: - Kitchens

extension APIClient {
    func fetchKitchen(id: String, authToken: String) async throws -> Kitchen {
        try await request("/api/v1/kitchens/\(id)", authToken: authToken)
    }

    func updateKitchen(id: String, name: String, authToken: String) async throws -> Kitchen {
        try await request(
            "/api/v1/kitchens/\(id)",
            method: "PATCH",
            body: ["name": name],
            authToken: authToken
        )
    }

    func rotateInviteCode(kitchenID: String, authToken: String) async throws -> InviteCodeResult {
        try await request(
            "/api/v1/kitchens/\(kitchenID)/rotate_invite",
            method: "POST",
            authToken: authToken
        )
    }

    struct InviteCodeResult: Decodable {
        let inviteCode: String
    }
}

// MARK: - Members

extension APIClient {
    func fetchMembers(kitchenID: String, authToken: String) async throws -> [Member] {
        try await request("/api/v1/kitchens/\(kitchenID)/members", authToken: authToken)
    }

    func removeMember(kitchenID: String, accountID: String, authToken: String) async throws -> OKResult {
        try await request(
            "/api/v1/kitchens/\(kitchenID)/members/\(accountID)",
            method: "DELETE",
            authToken: authToken
        )
    }

    func leaveKitchen(kitchenID: String, authToken: String) async throws -> OKResult {
        try await request(
            "/api/v1/kitchens/\(kitchenID)/leave",
            method: "POST",
            authToken: authToken
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
    func fetchDishes(kitchenID: String, authToken: String) async throws -> [Dish] {
        try await request("/api/v1/kitchens/\(kitchenID)/dishes", authToken: authToken)
    }

    func createDish(
        kitchenID: String,
        name: String,
        category: String,
        ingredients: [String]? = nil,
        imageFileURL: URL? = nil,
        authToken: String
    ) async throws -> Dish {
        if let imageFileURL {
            let fileData = try Data(contentsOf: imageFileURL)
            let fields = [
                "name": name,
                "category": category
            ]

            return try await requestMultipart(
                "/api/v1/kitchens/\(kitchenID)/dishes",
                method: "POST",
                fields: fields,
                repeatedFields: ingredients.map { ["ingredients[]": $0] } ?? [:],
                fileField: "image",
                fileName: "dish.png",
                fileData: fileData,
                fileContentType: DishImageSpec.mimeType,
                authToken: authToken
            )
        }

        return try await request(
            "/api/v1/kitchens/\(kitchenID)/dishes",
            method: "POST",
            body: CreateDishBody(name: name, category: category, ingredients: ingredients),
            authToken: authToken
        )
    }

    func updateDish(
        id: String,
        name: String? = nil,
        category: String? = nil,
        ingredients: [String]? = nil,
        imageKey: String? = nil,
        authToken: String
    ) async throws -> Dish {
        try await request(
            "/api/v1/dishes/\(id)",
            method: "PATCH",
            body: UpdateDishBody(name: name, category: category, ingredients: ingredients, imageKey: imageKey),
            authToken: authToken
        )
    }

    func archiveDish(id: String, authToken: String) async throws -> OKResult {
        try await request(
            "/api/v1/dishes/\(id)",
            method: "DELETE",
            authToken: authToken
        )
    }
}

// MARK: - Dish Images

extension APIClient {
    struct DishImageUploadTicket: Decodable {
        let uploadURL: String
        let imageKey: String
        let method: String
        let contentType: String
    }

    struct DishImageUploadResult: Decodable {
        let ok: Bool
        let imageKey: String
    }

    func requestDishImageUploadURL(dishID: String, authToken: String) async throws -> DishImageUploadTicket {
        try await request(
            "/api/v1/dishes/\(dishID)/image_upload_url",
            method: "POST",
            authToken: authToken
        )
    }

    @discardableResult
    func uploadDishImage(
        uploadPath: String,
        fileURL: URL,
        contentType: String,
        fallbackImageKey: String,
        authToken: String
    ) async throws -> DishImageUploadResult {
        let data = try Data(contentsOf: fileURL)
        let responseData = try await uploadBinaryAllowingEmptyBody(
            uploadPath,
            data: data,
            contentType: contentType,
            authToken: authToken
        )

        guard let responseData else {
            return DishImageUploadResult(ok: true, imageKey: fallbackImageKey)
        }

        do {
            return try uploadDecoder.decode(DishImageUploadResult.self, from: responseData)
        } catch {
            if let text = String(data: responseData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               text == "ok" {
                return DishImageUploadResult(ok: true, imageKey: fallbackImageKey)
            }
            throw uploadDecodeError(error, data: responseData)
        }
    }

    private var uploadDecoder: JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    private func uploadDecodeError(_ error: Error, data: Data) -> APIError {
        if data.isEmpty {
            return .invalidResponse("接口返回为空")
        }

        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return .invalidResponse("接口返回格式异常：\(String(text.prefix(120)))")
        }

        return .decoding(error)
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
        let createdByAccountId: String
        let createdAt: String
        let finishedAt: String?
        let items: [OrderItem]?
    }

    func fetchOpenOrder(kitchenID: String, authToken: String) async throws -> OpenOrderResponse? {
        let result: OpenOrderResponse? = try await request(
            "/api/v1/kitchens/\(kitchenID)/orders/open",
            authToken: authToken
        )
        return result
    }

    func fetchOrderHistory(kitchenID: String, authToken: String) async throws -> [OrderHistoryEntry] {
        try await request(
            "/api/v1/kitchens/\(kitchenID)/orders/history",
            authToken: authToken
        )
    }

    func fetchOrderDetail(orderID: String, authToken: String) async throws -> OrderDetail {
        try await request(
            "/api/v1/orders/\(orderID)",
            authToken: authToken
        )
    }

    func createOrder(kitchenID: String, authToken: String) async throws -> Order {
        try await request(
            "/api/v1/kitchens/\(kitchenID)/orders",
            method: "POST",
            authToken: authToken
        )
    }

    func addOrderItem(orderID: String, dishID: String, quantity: Int = 1, authToken: String) async throws -> OrderItem {
        try await request(
            "/api/v1/orders/\(orderID)/items",
            method: "POST",
            body: AddOrderItemBody(dishID: dishID, quantity: quantity),
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
            "/api/v1/order_items/\(id)",
            method: "PATCH",
            body: UpdateOrderItemBody(status: status?.rawValue, quantity: quantity),
            authToken: authToken
        )
    }

    func finishOrder(id: String, authToken: String) async throws -> Order {
        try await request(
            "/api/v1/orders/\(id)/finish",
            method: "POST",
            authToken: authToken
        )
    }
}

// MARK: - Shared Decodable

struct OKResult: Decodable {
    let ok: Bool
}
