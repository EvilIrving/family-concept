import Foundation

// MARK: - Dishes Endpoints

extension APIEndpoints {
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
}

// MARK: - Request Bodies

struct CreateDishBody: Encodable {
    let name: String
    let category: String
    let ingredients: [String]?
}

struct UpdateDishBody: Encodable {
    let name: String?
    let category: String?
    let ingredients: [String]?
    let imageKey: String?

    enum CodingKeys: String, CodingKey {
        case name, category, ingredients
        case imageKey = "image_key"
    }
}
