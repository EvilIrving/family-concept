import Foundation

/// `Endpoint` is a pure request descriptor.
/// It must not grow execution policy responsibilities such as retry, caching,
/// mock payloads, decode strategy, or analytics behavior.
struct Endpoint<Response: Decodable> {
    let path: String
    let method: String
    let headers: [String: String]
    let queryItems: [URLQueryItem]
    let body: Encodable?
    let requiresAuth: Bool

    init(
        path: String,
        method: String = "GET",
        headers: [String: String] = [:],
        queryItems: [URLQueryItem] = [],
        body: Encodable? = nil,
        requiresAuth: Bool = false
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
        self.requiresAuth = requiresAuth
    }
}

enum APIEndpoints {
    enum Auth {
        static func register(userName: String, password: String, nickName: String) -> Endpoint<AuthResponse> {
            Endpoint(
                path: "/api/v1/auth/register",
                method: "POST",
                body: [
                    "user_name": userName,
                    "password": password,
                    "nick_name": nickName
                ]
            )
        }

        static func login(userName: String, password: String) -> Endpoint<AuthResponse> {
            Endpoint(
                path: "/api/v1/auth/login",
                method: "POST",
                body: [
                    "user_name": userName,
                    "password": password
                ]
            )
        }

        static func logout() -> Endpoint<OKResult> {
            Endpoint(path: "/api/v1/auth/logout", method: "POST", requiresAuth: true)
        }

        static func fetchMe() -> Endpoint<AuthMeResponse> {
            Endpoint(path: "/api/v1/auth/me", requiresAuth: true)
        }
    }

    enum Onboarding {
        static func complete(
            mode: String,
            nickName: String? = nil,
            inviteCode: String? = nil,
            kitchenName: String? = nil
        ) -> Endpoint<APIClient.OnboardingResponse> {
            var body: [String: String] = ["mode": mode]
            if let nickName { body["nick_name"] = nickName }
            if let inviteCode { body["invite_code"] = inviteCode }
            if let kitchenName { body["kitchen_name"] = kitchenName }

            return Endpoint(
                path: "/api/v1/onboarding/complete",
                method: "POST",
                body: body,
                requiresAuth: true
            )
        }
    }

    enum Kitchens {
        static func fetch(id: String) -> Endpoint<Kitchen> {
            Endpoint(path: "/api/v1/kitchens/\(id)", requiresAuth: true)
        }

        static func update(id: String, name: String) -> Endpoint<Kitchen> {
            Endpoint(
                path: "/api/v1/kitchens/\(id)",
                method: "PATCH",
                body: ["name": name],
                requiresAuth: true
            )
        }

        static func rotateInviteCode(kitchenID: String) -> Endpoint<APIClient.InviteCodeResult> {
            Endpoint(
                path: "/api/v1/kitchens/\(kitchenID)/rotate_invite",
                method: "POST",
                requiresAuth: true
            )
        }
    }

    enum Members {
        static func fetch(kitchenID: String) -> Endpoint<[Member]> {
            Endpoint(path: "/api/v1/kitchens/\(kitchenID)/members", requiresAuth: true)
        }

        static func remove(kitchenID: String, accountID: String) -> Endpoint<OKResult> {
            Endpoint(
                path: "/api/v1/kitchens/\(kitchenID)/members/\(accountID)",
                method: "DELETE",
                requiresAuth: true
            )
        }

        static func leave(kitchenID: String) -> Endpoint<OKResult> {
            Endpoint(
                path: "/api/v1/kitchens/\(kitchenID)/leave",
                method: "POST",
                requiresAuth: true
            )
        }
    }

    enum Dishes {
        static func fetch(kitchenID: String) -> Endpoint<[Dish]> {
            Endpoint(path: "/api/v1/kitchens/\(kitchenID)/dishes", requiresAuth: true)
        }

        static func create(kitchenID: String, name: String, category: String, ingredients: [String]? = nil) -> Endpoint<Dish> {
            Endpoint(
                path: "/api/v1/kitchens/\(kitchenID)/dishes",
                method: "POST",
                body: CreateDishBody(name: name, category: category, ingredients: ingredients),
                requiresAuth: true
            )
        }

        static func update(
            id: String,
            name: String? = nil,
            category: String? = nil,
            ingredients: [String]? = nil,
            imageKey: String? = nil
        ) -> Endpoint<Dish> {
            Endpoint(
                path: "/api/v1/dishes/\(id)",
                method: "PATCH",
                body: UpdateDishBody(name: name, category: category, ingredients: ingredients, imageKey: imageKey),
                requiresAuth: true
            )
        }

        static func archive(id: String) -> Endpoint<OKResult> {
            Endpoint(path: "/api/v1/dishes/\(id)", method: "DELETE", requiresAuth: true)
        }
    }

    enum DishImages {
        static func requestUploadURL(dishID: String) -> Endpoint<APIClient.DishImageUploadTicket> {
            Endpoint(
                path: "/api/v1/dishes/\(dishID)/image_upload_url",
                method: "POST",
                requiresAuth: true
            )
        }
    }

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

// MARK: - Auth

extension APIClient {
    func register(userName: String, password: String, nickName: String) async throws -> AuthResponse {
        try await request(APIEndpoints.Auth.register(userName: userName, password: password, nickName: nickName))
    }

    func login(userName: String, password: String) async throws -> AuthResponse {
        try await request(APIEndpoints.Auth.login(userName: userName, password: password))
    }

    func logout(authToken: String) async throws -> OKResult {
        try await request(APIEndpoints.Auth.logout(), authToken: authToken)
    }

    func fetchMe(authToken: String) async throws -> AuthMeResponse {
        try await request(APIEndpoints.Auth.fetchMe(), authToken: authToken)
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
        try await request(
            APIEndpoints.Onboarding.complete(
                mode: mode,
                nickName: nickName,
                inviteCode: inviteCode,
                kitchenName: kitchenName
            ),
            authToken: authToken
        )
    }
}

// MARK: - Kitchens

extension APIClient {
    struct InviteCodeResult: Decodable {
        let inviteCode: String
    }

    func fetchKitchen(id: String, authToken: String) async throws -> Kitchen {
        try await request(APIEndpoints.Kitchens.fetch(id: id), authToken: authToken)
    }

    func updateKitchen(id: String, name: String, authToken: String) async throws -> Kitchen {
        try await request(APIEndpoints.Kitchens.update(id: id, name: name), authToken: authToken)
    }

    func rotateInviteCode(kitchenID: String, authToken: String) async throws -> InviteCodeResult {
        try await request(APIEndpoints.Kitchens.rotateInviteCode(kitchenID: kitchenID), authToken: authToken)
    }
}

// MARK: - Members

extension APIClient {
    func fetchMembers(kitchenID: String, authToken: String) async throws -> [Member] {
        try await request(APIEndpoints.Members.fetch(kitchenID: kitchenID), authToken: authToken)
    }

    func removeMember(kitchenID: String, accountID: String, authToken: String) async throws -> OKResult {
        try await request(
            APIEndpoints.Members.remove(kitchenID: kitchenID, accountID: accountID),
            authToken: authToken
        )
    }

    func leaveKitchen(kitchenID: String, authToken: String) async throws -> OKResult {
        try await request(APIEndpoints.Members.leave(kitchenID: kitchenID), authToken: authToken)
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
        try await request(APIEndpoints.Dishes.fetch(kitchenID: kitchenID), authToken: authToken)
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
            APIEndpoints.Dishes.create(
                kitchenID: kitchenID,
                name: name,
                category: category,
                ingredients: ingredients
            ),
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
            APIEndpoints.Dishes.update(
                id: id,
                name: name,
                category: category,
                ingredients: ingredients,
                imageKey: imageKey
            ),
            authToken: authToken
        )
    }

    func archiveDish(id: String, authToken: String) async throws -> OKResult {
        try await request(APIEndpoints.Dishes.archive(id: id), authToken: authToken)
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
        try await request(APIEndpoints.DishImages.requestUploadURL(dishID: dishID), authToken: authToken)
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

// MARK: - Shared Decodable

struct OKResult: Decodable {
    let ok: Bool
}
