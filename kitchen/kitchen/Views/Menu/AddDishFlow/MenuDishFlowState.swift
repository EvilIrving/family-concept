import Foundation
import SwiftUI

enum MenuDishFlowItem: Identifiable {
    case add
    case edit(String, AddDishDraft)

    var id: String {
        switch self {
        case .add:
            return "add-dish-flow"
        case .edit(let dishID, _):
            return "edit-dish-flow-\(dishID)"
        }
    }

    var isAdd: Bool {
        if case .add = self { return true }
        return false
    }

    var isEdit: Bool {
        !isAdd
    }

    var title: String {
        isAdd ? L10n.tr("Add Dish") : L10n.tr("Edit Dish")
    }

    var initialDraft: AddDishDraft {
        switch self {
        case .add:
            return AddDishDraft()
        case .edit(_, let draft):
            return draft
        }
    }
}

enum MenuDishFlowResult {
    case added(String)
    case updated(String)
    case deleted(String)
}

enum MenuDishFlowRoute: Hashable {
    case camera(UUID)
    case crop(CropRoute)
}

struct CropRoute: Hashable {
    let id: UUID
    let image: UIImage
    let source: CropImageSource

    static func == (lhs: CropRoute, rhs: CropRoute) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum CropImageSource {
    case camera
    case photoLibrary
}
