import Foundation

/// Orders 页面路由枚举
enum OrdersModalRoute: Identifiable, Equatable {
    case shoppingList

    var id: String {
        switch self {
        case .shoppingList:
            return "shoppingList"
        }
    }
}
