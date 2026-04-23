import SwiftUI

enum MenuField: Hashable {
    case name
    case customCategory
    case ingredient
    case search
}

struct AddDishDraft {
    var editingDishID: String?
    var name = ""
    var selectedQuickCategory = "家常菜"
    var customCategory = ""
    var ingredientTags: [String] = []
    var ingredientInput = ""
    var hasTriedSubmit = false
    var validationTrigger = 0
    var invalidName = false
    var invalidCategory = false
    var invalidIngredients = false
    var invalidImage = false
    var nameError: String?
    var categoryError: String?
    var ingredientError: String?
    var imageError: String?

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var resolvedCategory: String {
        let custom = customCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        return selectedQuickCategory == "自定义" ? custom : selectedQuickCategory
    }

    var hasIngredients: Bool {
        !ingredientTags.isEmpty || !ingredientInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasCategory: Bool {
        if selectedQuickCategory == "自定义" {
            return !resolvedCategory.isEmpty
        }
        return !selectedQuickCategory.isEmpty
    }

    mutating func resetValidation() {
        invalidName = false
        invalidCategory = false
        invalidIngredients = false
        invalidImage = false
        nameError = nil
        categoryError = nil
        ingredientError = nil
        imageError = nil
    }

    static func editing(_ dish: Dish, quickCategories: [String]) -> AddDishDraft {
        var draft = AddDishDraft()
        draft.editingDishID = dish.id
        draft.name = dish.name
        draft.ingredientTags = dish.ingredients
        if quickCategories.contains(dish.category) {
            draft.selectedQuickCategory = dish.category
        } else {
            draft.selectedQuickCategory = "自定义"
            draft.customCategory = dish.category
        }
        return draft
    }
}
