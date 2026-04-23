import Foundation
import Combine
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    // MARK: - Published State

    @Published var currentAccount: Account?
    @Published var kitchen: Kitchen? {
        didSet {
            guard oldValue?.id != kitchen?.id else { return }
            hasLoadedKitchenData = false
        }
    }
    @Published var members: [Member] = []
    @Published var dishes: [Dish] = []
    @Published var currentOrder: Order?
    @Published var orderItems: [OrderItem] = []
    @Published var orderHistory: [OrderHistoryEntry] = []
    @Published var selectedOrderDetail: OrderDetail?
    @Published var cartItems: [CartItem] = []
    @Published var shoppingListItems: [ShoppingListItem] = []
    @Published var isLoading: Bool = false
    @Published var isBootstrapping: Bool = false
    @Published var isSubmittingCart: Bool = false
    @Published private(set) var hasLoadedKitchenData: Bool = false
    @Published var error: String?
    @Published var menuFeedback: AppFeedback?
    @Published var ordersFeedback: AppFeedback?
    @Published var historyFeedback: AppFeedback?
    @Published var isLoadingOrderHistory: Bool = false
    @Published var colorScheme: ColorScheme?
    @Published var entitlement: KitchenEntitlement = .free()
    @Published var pendingEntitlementUpgrade: PendingEntitlementUpgrade?

    let apiClient = APIClient()
    /// StoreKit 交互层。App 入口注入，避免单测环境构造 StoreKit 会话。
    var purchaseManager: PurchaseManager?

    var authToken: String = ""
    var storedNickName: String = ""

    // MARK: - Initialization

    init() {
        if ProcessInfo.processInfo.arguments.contains("resetUITestSession") {
            Self.clearPersistedSession()
        }
        authToken = UserDefaults.standard.string(forKey: "authToken") ?? ""
        storedNickName = UserDefaults.standard.string(forKey: "nickName") ?? ""
        updateColorScheme()
    }

    // MARK: - Computed Properties

    var currentMember: Member? {
        members.first { $0.accountId == currentAccount?.id }
    }

    var currentRole: KitchenRole? {
        currentMember?.role
    }

    var isOwner: Bool { currentRole == .owner }
    var isAdmin: Bool { currentRole == .admin }
    var canManageDishes: Bool { isOwner || isAdmin }
    var canManageOrders: Bool { isOwner || isAdmin }
    var canEditWaitingOrderItems: Bool { canManageOrders }
    var canFinishCurrentOrder: Bool {
        canManageOrders && currentOrder != nil && orderItems.contains(where: { $0.status != .cancelled })
    }

    var hasKitchen: Bool { kitchen != nil }
    var isAuthenticated: Bool { !authToken.isEmpty && currentAccount != nil }
    var hasSeenOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenOnboarding") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenOnboarding") }
    }

    func completeOnboarding() {
        hasSeenOnboarding = true
    }

    static let categoryPriority: [String] = ["主食", "凉菜", "家常菜", "汤"]

    private static func categoryRank(_ category: String) -> Int {
        categoryPriority.firstIndex(of: category) ?? Int.max
    }

    private static func compareCategory(_ lhs: String, _ rhs: String) -> Bool {
        let lRank = categoryRank(lhs)
        let rRank = categoryRank(rhs)
        if lRank != rRank { return lRank < rRank }
        return lhs.localizedCompare(rhs) == .orderedAscending
    }

    var activeDishes: [Dish] {
        dishes
            .filter { $0.archivedAt == nil }
            .sorted { lhs, rhs in
                if lhs.category != rhs.category {
                    return Self.compareCategory(lhs.category, rhs.category)
                }
                return lhs.name.localizedCompare(rhs.name) == .orderedAscending
            }
    }

    var dishCategories: [String] {
        Array(Set(activeDishes.map(\.category)))
            .sorted { $0.localizedCompare($1) == .orderedAscending }
    }

    var cartCount: Int {
        cartItems.reduce(0) { $0 + $1.quantity }
    }

    var groupedOrderItems: [GroupedOrderItem] {
        orderItems.grouped(using: dishes)
    }

    var totalOrderQuantity: Int {
        orderItems
            .filter { $0.status != .cancelled }
            .reduce(0) { $0 + $1.quantity }
    }

    func quantity(for status: ItemStatus) -> Int {
        orderItems
            .filter { $0.status == status }
            .reduce(0) { $0 + $1.quantity }
    }

    func cartQuantity(for dishID: String) -> Int {
        cartItems.first(where: { $0.dishID == dishID })?.quantity ?? 0
    }

    // MARK: - Bootstrap

    func bootstrap() async {
        guard !authToken.isEmpty else { return }
        isBootstrapping = true
        defer { isBootstrapping = false }

        do {
            let me = try await apiClient.fetchMe(authToken: authToken)
            currentAccount = me.account
            storedNickName = me.account.nickName
            UserDefaults.standard.set(me.account.nickName, forKey: "nickName")

            if let lastKitchenID = UserDefaults.standard.string(forKey: "lastKitchenID") {
                let k = try await apiClient.fetchKitchen(id: lastKitchenID, authToken: authToken)
                kitchen = k
            }
        } catch APIError.unauthorized {
            clearSession()
        } catch {
            // Auth succeeded but kitchen restore failed — keep logged-in state
        }
    }

    // MARK: - Data Loading

    func fetchAll() async {
        guard let kitchen else { return }
        isLoading = true
        menuFeedback = nil
        ordersFeedback = nil
        defer {
            isLoading = false
            hasLoadedKitchenData = true
        }

        do {
            async let membersReq: [Member] = apiClient.fetchMembers(kitchenID: kitchen.id, authToken: authToken)
            async let dishesReq: [Dish] = apiClient.fetchDishes(kitchenID: kitchen.id, authToken: authToken)
            async let orderReq: APIClient.OpenOrderResponse? = apiClient.fetchOpenOrder(kitchenID: kitchen.id, authToken: authToken)

            let (fetchedMembers, fetchedDishes, fetchedOrder) = try await (membersReq, dishesReq, orderReq)
            self.members = fetchedMembers
            self.dishes = fetchedDishes
            Task { await refreshEntitlement() }

            if let order = fetchedOrder {
                self.currentOrder = Order(
                    id: order.id,
                    kitchenId: order.kitchenId,
                    status: order.status,
                    createdByAccountId: order.createdByAccountId,
                    createdAt: order.createdAt,
                    finishedAt: order.finishedAt
                )
                self.orderItems = order.items ?? []
            } else {
                self.currentOrder = nil
                self.orderItems = []
            }
        } catch APIError.unauthorized {
            clearSession()
        } catch {
            menuFeedback = feedback(for: error)
            ordersFeedback = feedback(for: error)
            consumeError(error)
        }
    }

    // MARK: - Theme Management

    func setThemeMode(_ mode: String) {
        UserDefaults.standard.set(mode, forKey: "themeMode")
        updateColorScheme()
    }

    private func updateColorScheme() {
        let themeMode = UserDefaults.standard.string(forKey: "themeMode") ?? "system"
        switch themeMode {
        case "light":
            colorScheme = .light
        case "dark":
            colorScheme = .dark
        default:
            colorScheme = nil
        }
    }

    private static func clearPersistedSession() {
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "accountID")
        UserDefaults.standard.removeObject(forKey: "nickName")
        UserDefaults.standard.removeObject(forKey: "lastKitchenID")
    }

    // MARK: - Private Helpers

    func consumeError(_ error: Error) {
        self.error = (error as? APIError)?.userMessage ?? error.localizedDescription
    }

    func feedback(for error: Error) -> AppFeedback {
        guard let apiError = error as? APIError else {
            return .generic(message: error.localizedDescription)
        }
        switch apiError {
        case .network:
            return .network()
        case .unauthorized:
            return .auth()
        case .invalidURL, .invalidResponse, .serverMessage, .decoding:
            return .generic(message: apiError.userMessage)
        }
    }

    func clearKitchenState() {
        hasLoadedKitchenData = false
        kitchen = nil
        members = []
        dishes = []
        menuFeedback = nil
        orderItems = []
        orderHistory = []
        selectedOrderDetail = nil
        cartItems = []
        currentOrder = nil
        entitlement = .free()
        pendingEntitlementUpgrade = nil
        UserDefaults.standard.removeObject(forKey: "lastKitchenID")
    }

    func applyOrderItemUpdate(_ updated: OrderItem) {
        if updated.status == .cancelled || updated.quantity <= 0 {
            orderItems.removeAll { $0.id == updated.id }
            return
        }
        if let idx = orderItems.firstIndex(where: { $0.id == updated.id }) {
            orderItems[idx] = updated
        } else {
            orderItems.append(updated)
        }
    }
}
