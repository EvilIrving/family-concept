import Foundation

/// Orders 页面路由枚举
enum OrdersModalRoute: Identifiable, Equatable {
    case shoppingList
    case history

    var id: String {
        switch self {
        case .shoppingList:
            return "shoppingList"
        case .history:
            return "history"
        }
    }
}
