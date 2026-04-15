import SwiftUI

enum MenuField {
    case name
    case customCategory
    case ingredient
    case search
}

struct AddDishDraft {
    var name = ""
    var selectedQuickCategory = "家常菜"
    var customCategory = ""
    var ingredientTags: [String] = []
    var ingredientInput = ""
    var validationMessage: String?

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var resolvedCategory: String {
        let custom = customCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        return selectedQuickCategory == "其他" ? custom : selectedQuickCategory
    }
}

enum MenuModalRoute: Identifiable {
    case addDish
    case cart
    case camera
    case crop(CropPresentation)

    var id: String {
        switch self {
        case .addDish:
            return "add-dish"
        case .cart:
            return "cart"
        case .camera:
            return "camera"
        case .crop(let presentation):
            return "crop-\(presentation.id.uuidString)"
        }
    }
}

struct CropPresentation: Identifiable {
    let id = UUID()
    let image: UIImage
}
