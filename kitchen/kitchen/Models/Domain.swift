import Foundation

enum KitchenRole: String, CaseIterable, Identifiable {
    case owner
    case admin
    case member

    var id: String { rawValue }

    var title: String {
        switch self {
        case .owner: "店主"
        case .admin: "协作"
        case .member: "成员"
        }
    }
}

enum OrderItemStatus: String, CaseIterable, Identifiable {
    case waiting
    case cooking
    case done
    case cancelled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .waiting: "待制作"
        case .cooking: "制作中"
        case .done: "已完成"
        case .cancelled: "已取消"
        }
    }
}

struct UserProfile: Identifiable, Equatable {
    let id: UUID
    var name: String
    var role: KitchenRole
}

struct Dish: Identifiable, Equatable {
    let id: UUID
    var name: String
    var category: String
    var ingredients: [String]
    var archivedAt: Date?
}

struct OrderItem: Identifiable, Equatable {
    let id: UUID
    var dishID: UUID
    var dishName: String
    var quantity: Int
    var status: OrderItemStatus
    var addedBy: String
}

struct KitchenInfo: Equatable {
    var name: String
    var inviteCode: String
}
