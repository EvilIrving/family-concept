import Combine
import Foundation
import StoreKit

/// 负责 StoreKit 2 的购买、恢复与监听逻辑。
/// 不直接修改 AppStore 状态：所有权益变化由 AppStore 通过拉取服务端 entitlement 完成。
@MainActor
final class PurchaseManager: ObservableObject {

    // MARK: - Published State

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoadingProducts: Bool = false
    @Published private(set) var isPurchasing: Bool = false

    // MARK: - Callbacks

    /// 当任何已验证交易到达（购买成功、恢复、跨设备同步），通知上层去同步服务端。
    var onTransactionVerified: ((String, String) async -> Void)?

    // MARK: - Lifecycle

    private var updatesTask: Task<Void, Never>?

    init() {
        startObservingTransactions()
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let ids = PurchaseProduct.allCases.map(\.rawValue)
            let loaded = try await Product.products(for: ids)
            self.products = loaded.sorted { lhs, rhs in
                lhs.price < rhs.price
            }
        } catch {
            #if DEBUG
            print("PurchaseManager: loadProducts failed \(error)")
            #endif
        }
    }

    func product(for code: PurchaseProduct) -> Product? {
        products.first { $0.id == code.rawValue }
    }

    // MARK: - Purchase

    enum PurchaseOutcome {
        case success(signedTransaction: String)
        case userCancelled
        case pending
        case verificationFailed
    }

    func purchase(_ product: Product, appAccountToken: UUID) async throws -> PurchaseOutcome {
        isPurchasing = true
        defer { isPurchasing = false }

        var options: Set<Product.PurchaseOption> = []
        options.insert(.appAccountToken(appAccountToken))

        let result = try await product.purchase(options: options)

        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                return .verificationFailed
            }
            let payload = PurchaseOutcome.success(signedTransaction: verification.jwsRepresentation)
            await transaction.finish()
            return payload
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            return .verificationFailed
        }
    }

    // MARK: - Restore

    func restore() async {
        // StoreKit 2 的推荐做法：遍历 Transaction.currentEntitlements
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result {
                await onTransactionVerified?(tx.productID, result.jwsRepresentation)
            }
        }
    }

    // MARK: - Transaction Observer

    private func startObservingTransactions() {
        updatesTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let tx) = result {
                    await self?.onTransactionVerified?(tx.productID, result.jwsRepresentation)
                    await tx.finish()
                }
            }
        }
    }
}
