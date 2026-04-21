import Foundation

enum MenuModalRoute: Identifiable, Equatable {
    case cart
    case addDish
    case editDish

    var id: Int {
        switch self {
        case .cart: return 0
        case .addDish: return 1
        case .editDish: return 2
        }
    }
}
