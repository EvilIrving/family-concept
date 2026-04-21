import Foundation

// MARK: - AppStore: Dishes Management Extension

extension AppStore {
    @discardableResult
    func addDish(name: String, category: String, ingredients: [String], imageFileURL: URL? = nil) async -> Dish? {
        guard let kitchen else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedCategory.isEmpty else { return nil }

        do {
            let dish = try await apiClient.createDish(
                kitchenID: kitchen.id,
                name: trimmedName,
                category: trimmedCategory,
                ingredients: ingredients,
                imageFileURL: imageFileURL,
                authToken: authToken
            )
            dishes.insert(dish, at: 0)
            return dish
        } catch {
            consumeError(error)
            return nil
        }
    }

    func uploadDishImage(dishID: String, fileURL: URL) async throws {
        let ticket = try await apiClient.requestDishImageUploadURL(dishID: dishID, authToken: authToken)
        let result = try await apiClient.uploadDishImage(
            uploadPath: ticket.uploadURL,
            fileURL: fileURL,
            contentType: ticket.contentType,
            fallbackImageKey: ticket.imageKey,
            authToken: authToken
        )
        if let idx = dishes.firstIndex(where: { $0.id == dishID }) {
            let d = dishes[idx]
            dishes[idx] = Dish(
                id: d.id,
                kitchenId: d.kitchenId,
                name: d.name,
                category: d.category,
                imageKey: result.imageKey,
                ingredientsJson: d.ingredientsJson,
                createdByAccountId: d.createdByAccountId,
                createdAt: d.createdAt,
                updatedAt: d.updatedAt,
                archivedAt: d.archivedAt
            )
        }
    }

    func archiveDish(id: String) async {
        do {
            _ = try await apiClient.archiveDish(id: id, authToken: authToken)
            dishes.removeAll { $0.id == id }
        } catch {
            consumeError(error)
        }
    }

    @discardableResult
    func updateDish(
        id: String,
        name: String,
        category: String,
        ingredients: [String],
        imageFileURL: URL? = nil
    ) async -> Dish? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedCategory.isEmpty else { return nil }

        do {
            var updated = try await apiClient.updateDish(
                id: id,
                name: trimmedName,
                category: trimmedCategory,
                ingredients: ingredients,
                authToken: authToken
            )

            if let imageFileURL {
                try await uploadDishImage(dishID: id, fileURL: imageFileURL)
                if let current = dishes.first(where: { $0.id == id }) {
                    updated = Dish(
                        id: updated.id,
                        kitchenId: updated.kitchenId,
                        name: updated.name,
                        category: updated.category,
                        imageKey: current.imageKey,
                        ingredientsJson: updated.ingredientsJson,
                        createdByAccountId: updated.createdByAccountId,
                        createdAt: updated.createdAt,
                        updatedAt: updated.updatedAt,
                        archivedAt: updated.archivedAt
                    )
                }
            }

            if let idx = dishes.firstIndex(where: { $0.id == id }) {
                dishes[idx] = updated
            }
            return updated
        } catch {
            consumeError(error)
            return nil
        }
    }

    func refreshDishes() async {
        guard let kitchen else { return }
        do {
            dishes = try await apiClient.fetchDishes(kitchenID: kitchen.id, authToken: authToken)
        } catch {
            consumeError(error)
        }
    }
}
