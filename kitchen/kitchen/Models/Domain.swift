import Foundation

// MARK: - Enums

enum KitchenRole: String, Codable, CaseIterable, Equatable {
    case owner
    case admin
    case member

    var title: String {
        switch self {
        case .owner: "管理员"
        case .admin: "副管理员"
        case .member: "成员"
        }
    }
}

enum MemberStatus: String, Codable, Equatable {
    case active
    case removed
}

enum OrderStatus: String, Codable, Equatable {
    case open
    case finished
}

enum ItemStatus: String, Codable, CaseIterable, Equatable {
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

// MARK: - Device

struct Device: Identifiable, Codable, Equatable {
    let id: String
    let deviceId: String
    let displayName: String
    let createdAt: String
}

// MARK: - Kitchen

struct Kitchen: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let ownerDeviceId: String
    let inviteCode: String
    let inviteCodeRotatedAt: String
    let createdAt: String
}

// MARK: - Member

struct Member: Identifiable, Codable, Equatable {
    let id: String
    let kitchenId: String
    let deviceRefId: String
    let role: KitchenRole
    let status: MemberStatus
    let joinedAt: String
    let removedAt: String?
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id, kitchenId, deviceRefId, role, status, joinedAt, removedAt, displayName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kitchenId = try c.decode(String.self, forKey: .kitchenId)
        deviceRefId = try c.decode(String.self, forKey: .deviceRefId)
        role = try c.decode(KitchenRole.self, forKey: .role)
        status = try c.decode(MemberStatus.self, forKey: .status)
        joinedAt = try c.decode(String.self, forKey: .joinedAt)
        removedAt = try c.decodeIfPresent(String.self, forKey: .removedAt)
        displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
    }

    init(id: String, kitchenId: String, deviceRefId: String, role: KitchenRole, status: MemberStatus = .active, joinedAt: String = "", removedAt: String? = nil, displayName: String) {
        self.id = id
        self.kitchenId = kitchenId
        self.deviceRefId = deviceRefId
        self.role = role
        self.status = status
        self.joinedAt = joinedAt
        self.removedAt = removedAt
        self.displayName = displayName
    }
}

// MARK: - Dish

struct Dish: Identifiable, Codable, Equatable {
    let id: String
    let kitchenId: String
    let name: String
    let category: String
    let imageKey: String?
    let ingredientsJson: String
    let createdByDeviceId: String
    let createdAt: String
    let updatedAt: String
    let archivedAt: String?

    var ingredients: [String] {
        guard let data = ingredientsJson.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    var isArchived: Bool { archivedAt != nil }
}

// MARK: - Order

struct Order: Identifiable, Codable, Equatable {
    let id: String
    let kitchenId: String
    let status: OrderStatus
    let createdByDeviceId: String
    let createdAt: String
    let finishedAt: String?
}

// MARK: - OrderItem

struct OrderItem: Identifiable, Codable, Equatable {
    let id: String
    let orderId: String
    let dishId: String
    let addedByDeviceId: String
    let quantity: Int
    let status: ItemStatus
    let createdAt: String
    let updatedAt: String
}

// MARK: - CartItem (local only)

struct CartItem: Identifiable, Equatable {
    let id: String
    var dishID: String
    var dishName: String
    var quantity: Int
}

// MARK: - ShoppingListItem

struct ShoppingListItem: Identifiable, Equatable {
    let ingredient: String
    let dishCount: Int
    var id: String { ingredient }
}
