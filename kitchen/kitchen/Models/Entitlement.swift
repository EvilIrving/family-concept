import Foundation
import CryptoKit

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
        case .free: return L10n.tr("Free Tier")
        case .dishesFifty: return L10n.tr("50 dishes total")
        case .dishesUnlimited: return L10n.tr("Infinite dishes")
        }
    }
}

enum EntitlementStatus: String, Codable {
    case active
    case revoked
    case pendingVerificationFailed = "pending_verification_failed"
    case notFound = "not_found"
}

/// 付费商品定义 —— 与 App Store Connect 保持一致
enum PurchaseProduct: String, CaseIterable {
    case dishesFifty = "kitchen.dishes.essentials"
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
    let status: EntitlementStatus
    let planCode: PlanCode
    let dishLimit: Int?
    let isUnlimited: Bool
    let activeDishCount: Int
    let storeProductId: String?
    let activatedAt: String?
    let originalTransactionId: String?
    let revokedAt: String?
    let revocationReason: String?
    let lastVerifiedAt: String?

    static func free(activeDishCount: Int = 0) -> KitchenEntitlement {
        KitchenEntitlement(
            status: .notFound,
            planCode: .free,
            dishLimit: PlanCode.free.dishLimit,
            isUnlimited: false,
            activeDishCount: activeDishCount,
            storeProductId: nil,
            activatedAt: nil,
            originalTransactionId: nil,
            revokedAt: nil,
            revocationReason: nil,
            lastVerifiedAt: nil
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

enum AppAccountTokenBuilder {
    static func build(accountID: String, kitchenID: String) -> UUID? {
        let seed = Data("kitchen-iap:\(accountID):\(kitchenID)".utf8)
        let digest = Array(SHA256.hash(data: seed).prefix(16))
        guard digest.count == 16 else { return nil }

        var bytes = digest
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        let hex = bytes.map { String(format: "%02x", $0) }.joined()
        let part1 = String(hex.prefix(8))
        let part2 = String(hex.dropFirst(8).prefix(4))
        let part3 = String(hex.dropFirst(12).prefix(4))
        let part4 = String(hex.dropFirst(16).prefix(4))
        let part5 = String(hex.dropFirst(20).prefix(12))
        let uuidString = "\(part1)-\(part2)-\(part3)-\(part4)-\(part5)"
        return UUID(uuidString: uuidString)
    }
}
