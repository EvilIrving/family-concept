import Foundation

// MARK: - APIClient Extensions: Dishes

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
            let fields = ["name": name, "category": category]

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

    // MARK: - Dish Images

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
            return try APIClient.decodeJSON(DishImageUploadResult.self, from: responseData)
        } catch {
            if let text = String(data: responseData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               text == "ok" {
                return DishImageUploadResult(ok: true, imageKey: fallbackImageKey)
            }
            throw uploadDecodeError(error, data: responseData)
        }
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
