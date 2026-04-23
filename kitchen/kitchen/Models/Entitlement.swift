import Foundation

/// 付费档位。当前只做一次性买断，无订阅。
enum PlanCode: String, Codable {
    case free
    case dishesFifty = "dishes_fifty"
    case dishesUnlimited = "dishes_unlimited"

    /// 菜品上限，nil 表示无限
    var dishLimit: Int? {
        switch self {
        case .free: return 10
        case .dishesFifty: return 50
        case .dishesUnlimited: return nil
        }
    }

    var displayName: String {
        switch self {
        case .free: return "免费档"
        case .dishesFifty: return "50 道菜"
        case .dishesUnlimited: return "无限道菜"
        }
    }
}

/// 付费商品定义 —— 与 App Store Connect 保持一致
enum PurchaseProduct: String, CaseIterable {
    case dishesFifty = "kitchen.dishes.fifty"
    case dishesUnlimited = "kitchen.dishes.unlimited"

    var plan: PlanCode {
        switch self {
        case .dishesFifty: return .dishesFifty
        case .dishesUnlimited: return .dishesUnlimited
        }
    }
}

/// 厨房当前权益快照，服务端为准
struct KitchenEntitlement: Codable, Equatable {
    let planCode: PlanCode
    let dishLimit: Int?
    let isUnlimited: Bool
    let activeDishCount: Int
    let storeProductId: String?
    let activatedAt: String?

    static func free(activeDishCount: Int = 0) -> KitchenEntitlement {
        KitchenEntitlement(
            planCode: .free,
            dishLimit: PlanCode.free.dishLimit,
            isUnlimited: false,
            activeDishCount: activeDishCount,
            storeProductId: nil,
            activatedAt: nil
        )
    }

    var remainingQuota: Int? {
        if isUnlimited { return nil }
        guard let limit = dishLimit else { return nil }
        return max(0, limit - activeDishCount)
    }

    var isAtLimit: Bool {
        if isUnlimited { return false }
        guard let limit = dishLimit else { return false }
        return activeDishCount >= limit
    }
}

/// 客户端本地过渡态：购买已完成但尚未完成服务端同步
struct PendingEntitlementUpgrade: Equatable {
    let productID: String
    let startedAt: Date
}
