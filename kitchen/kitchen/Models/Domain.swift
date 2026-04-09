import Foundation

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
}

struct CartItem: Identifiable, Equatable {
    let id: UUID
    var dishID: UUID
    var dishName: String
    var quantity: Int
}

struct KitchenInfo: Equatable {
    var name: String
    var inviteCode: String
}

enum MemberRole: String, Equatable {
    case owner
    case member

    var title: String {
        switch self {
        case .owner: "管理员"
        case .member: "成员"
        }
    }
}

struct Member: Identifiable, Equatable {
    let id: UUID  // 设备 ID
    var displayName: String
    var role: MemberRole
}
