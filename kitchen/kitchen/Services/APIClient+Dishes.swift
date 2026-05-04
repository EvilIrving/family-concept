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

        enum CodingKeys: String, CodingKey {
            case uploadURL = "uploadUrl"
            case imageKey
            case method
            case contentType
        }
    }

    struct DishImageUploadResult: Decodable {
        let ok: Bool
        let imageKey: String
    }

    func requestDishImageUploadURL(dishID: String, authToken: String) async throws -> DishImageUploadTicket {
        try await request(
            APIEndpoints.DishImages.requestUploadURL(dishID: dishID),
            authToken: authToken,
            retryPolicy: .standard
        )
    }

    @discardableResult
    func uploadDishImage(
        uploadPath: String,
        method: String = "POST",
        fileURL: URL,
        contentType: String,
        fallbackImageKey: String,
        authToken: String
    ) async throws -> DishImageUploadResult {
        let data = try Data(contentsOf: fileURL)
        let responseData = try await uploadBinaryAllowingEmptyBody(
            uploadPath,
            method: method,
            data: data,
            contentType: contentType,
            authToken: authToken
        )

        guard let responseData else {
            return DishImageUploadResult(ok: true, imageKey: fallbackImageKey)
        }

        do {
            return try APIClient.decodeJSON(DishImageUploadResponse.self, from: responseData)
                .resolved(fallbackImageKey: fallbackImageKey)
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
            return .invalidResponse(L10n.tr("Empty API response"))
        }

        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return .invalidResponse(L10n.tr("Unexpected API response: %@", String(text.prefix(120))))
        }

        return .decoding(error)
    }
}

private struct DishImageUploadResponse: Decodable {
    let ok: Bool
    let imageKey: String?

    func resolved(fallbackImageKey: String) -> APIClient.DishImageUploadResult {
        APIClient.DishImageUploadResult(ok: ok, imageKey: imageKey ?? fallbackImageKey)
    }
}
