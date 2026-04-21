import Foundation
import Combine
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var currentAccount: Account?
    @Published var kitchen: Kitchen?
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
    @Published var error: String?
    @Published var colorScheme: ColorScheme?

    let apiClient = APIClient()

    private(set) var authToken: String = ""
    private(set) var storedNickName: String = ""

    init() {
        authToken = UserDefaults.standard.string(forKey: "authToken") ?? ""
        storedNickName = UserDefaults.standard.string(forKey: "nickName") ?? ""
        updateColorScheme()
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

    private func consumeError(_ error: Error) {
        self.error = (error as? APIError)?.userMessage ?? error.localizedDescription
    }

    // MARK: - Computed

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
    var canEditWaitingOrderItems: Bool { currentMember != nil }

    var hasKitchen: Bool { kitchen != nil }
    var isAuthenticated: Bool { !authToken.isEmpty && currentAccount != nil }

    var activeDishes: [Dish] {
        dishes.filter { $0.archivedAt == nil }
    }

    var dishCategories: [String] {
        Array(Set(activeDishes.map(\.category))).sorted()
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
                // fetchAll is triggered by ContentView's task(id: kitchen?.id)
            }
        } catch APIError.unauthorized {
            clearSession()
        } catch {
            // auth/me succeeded but kitchen restore failed — keep logged-in state
            // kitchen remains nil, user stays in onboarding to join or create
        }
    }

    // MARK: - Data Loading

    func fetchAll() async {
        guard let kitchen else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let membersReq: [Member] = apiClient.fetchMembers(
                kitchenID: kitchen.id, authToken: authToken
            )
            async let dishesReq: [Dish] = apiClient.fetchDishes(
                kitchenID: kitchen.id, authToken: authToken
            )
            async let orderReq: APIClient.OpenOrderResponse? = apiClient.fetchOpenOrder(
                kitchenID: kitchen.id, authToken: authToken
            )

            let (fetchedMembers, fetchedDishes, fetchedOrder) = try await (membersReq, dishesReq, orderReq)
            self.members = fetchedMembers
            self.dishes = fetchedDishes

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
            consumeError(error)
        }
    }

    func refreshOrderItems() async {
        guard let kitchen else { return }
        do {
            let result = try await apiClient.fetchOpenOrder(
                kitchenID: kitchen.id, authToken: authToken
            )
            if let order = result {
                self.currentOrder = Order(
                    id: order.id, kitchenId: order.kitchenId,
                    status: order.status, createdByAccountId: order.createdByAccountId,
                    createdAt: order.createdAt, finishedAt: order.finishedAt
                )
                self.orderItems = order.items ?? []
            } else {
                self.currentOrder = nil
                self.orderItems = []
            }
        } catch {
            consumeError(error)
        }
    }

    // MARK: - Auth

    func login(userName: String, password: String, inviteCode: String = "", kitchenName: String = "") async {
        error = nil
        do {
            let response = try await apiClient.login(userName: userName, password: password)
            persistAuth(response.token, account: response.account)

            // Try to restore last kitchen
            if let lastKitchenID = UserDefaults.standard.string(forKey: "lastKitchenID"),
               let k = try? await apiClient.fetchKitchen(id: lastKitchenID, authToken: authToken) {
                kitchen = k
                return
            }

            // No restorable kitchen — try provided invite code or kitchen name
            await completeOnboarding(inviteCode: inviteCode, kitchenName: kitchenName)
        } catch {
            consumeError(error)
        }
    }

    func register(userName: String, password: String, nickName: String, inviteCode: String = "", kitchenName: String = "") async {
        error = nil
        do {
            let response = try await apiClient.register(
                userName: userName, password: password, nickName: nickName
            )
            persistAuth(response.token, account: response.account)
            await completeOnboarding(inviteCode: inviteCode, kitchenName: kitchenName)
        } catch {
            consumeError(error)
        }
    }

    func joinKitchen(inviteCode: String) async {
        error = nil
        await completeOnboarding(inviteCode: inviteCode, kitchenName: "")
    }

    func createKitchen(named name: String) async {
        error = nil
        await completeOnboarding(inviteCode: "", kitchenName: name)
    }

    func signOut() async {
        if !authToken.isEmpty {
            _ = try? await apiClient.logout(authToken: authToken)
        }
        clearSession()
    }

    // MARK: - Kitchen

    func updateKitchenName(_ name: String) async {
        guard let kitchen else { return }
        do {
            let updated = try await apiClient.updateKitchen(
                id: kitchen.id, name: name, authToken: authToken
            )
            self.kitchen = updated
        } catch {
            consumeError(error)
        }
    }

    func rotateInviteCode() async {
        guard let kitchen else { return }
        do {
            let result = try await apiClient.rotateInviteCode(
                kitchenID: kitchen.id, authToken: authToken
            )
            self.kitchen = Kitchen(
                id: kitchen.id, name: kitchen.name,
                ownerAccountId: kitchen.ownerAccountId,
                inviteCode: result.inviteCode,
                inviteCodeRotatedAt: kitchen.inviteCodeRotatedAt,
                createdAt: kitchen.createdAt
            )
        } catch {
            consumeError(error)
        }
    }

    // MARK: - Members

    func removeMember(accountID: String) async {
        guard let kitchen else { return }
        do {
            _ = try await apiClient.removeMember(
                kitchenID: kitchen.id, accountID: accountID, authToken: authToken
            )
            members.removeAll { $0.accountId == accountID }
        } catch {
            consumeError(error)
        }
    }

    func leaveKitchen() async {
        guard let kitchen else { return }
        do {
            _ = try await apiClient.leaveKitchen(
                kitchenID: kitchen.id, authToken: authToken
            )
            clearKitchenState()
        } catch {
            consumeError(error)
        }
    }

    // MARK: - Dishes

    @discardableResult
    func addDish(name: String, category: String, ingredients: [String], imageFileURL: URL? = nil) async -> Dish? {
        guard let kitchen else { return nil }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedCategory.isEmpty else { return nil }

        do {
            let dish = try await apiClient.createDish(
                kitchenID: kitchen.id,
                name: trimmedName,
                category: trimmedCategory,
                ingredients: ingredients,
                imageFileURL: imageFileURL,
                authToken: authToken
            )
            dishes.insert(dish, at: 0)
            return dish
        } catch {
            consumeError(error)
            return nil
        }
    }

    func uploadDishImage(dishID: String, fileURL: URL) async throws {
        let ticket = try await apiClient.requestDishImageUploadURL(dishID: dishID, authToken: authToken)
        let result = try await apiClient.uploadDishImage(
            uploadPath: ticket.uploadURL,
            fileURL: fileURL,
            contentType: ticket.contentType,
            fallbackImageKey: ticket.imageKey,
            authToken: authToken
        )
        if let idx = dishes.firstIndex(where: { $0.id == dishID }) {
            let d = dishes[idx]
            dishes[idx] = Dish(
                id: d.id, kitchenId: d.kitchenId, name: d.name, category: d.category,
                imageKey: result.imageKey, ingredientsJson: d.ingredientsJson,
                createdByAccountId: d.createdByAccountId, createdAt: d.createdAt,
                updatedAt: d.updatedAt, archivedAt: d.archivedAt
            )
        }
    }

    func archiveDish(id: String) async {
        do {
            _ = try await apiClient.archiveDish(id: id, authToken: authToken)
            dishes.removeAll { $0.id == id }
        } catch {
            consumeError(error)
        }
    }

    @discardableResult
    func updateDish(
        id: String,
        name: String,
        category: String,
        ingredients: [String],
        imageFileURL: URL? = nil
    ) async -> Dish? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedCategory.isEmpty else { return nil }

        do {
            var updated = try await apiClient.updateDish(
                id: id,
                name: trimmedName,
                category: trimmedCategory,
                ingredients: ingredients,
                authToken: authToken
            )

            if let imageFileURL {
                try await uploadDishImage(dishID: id, fileURL: imageFileURL)
                if let current = dishes.first(where: { $0.id == id }) {
                    updated = Dish(
                        id: updated.id,
                        kitchenId: updated.kitchenId,
                        name: updated.name,
                        category: updated.category,
                        imageKey: current.imageKey,
                        ingredientsJson: updated.ingredientsJson,
                        createdByAccountId: updated.createdByAccountId,
                        createdAt: updated.createdAt,
                        updatedAt: updated.updatedAt,
                        archivedAt: updated.archivedAt
                    )
                }
            }

            if let idx = dishes.firstIndex(where: { $0.id == id }) {
                dishes[idx] = updated
            }
            return updated
        } catch {
            consumeError(error)
            return nil
        }
    }

    // MARK: - Cart

    func addToCart(dish: Dish) {
        if let index = cartItems.firstIndex(where: { $0.dishID == dish.id }) {
            cartItems[index].quantity += 1
        } else {
            cartItems.insert(
                CartItem(id: UUID().uuidString, dishID: dish.id, dishName: dish.name, quantity: 1),
                at: 0
            )
        }
    }

    func updateCartQuantity(dishID: String, delta: Int) {
        guard let item = cartItems.first(where: { $0.dishID == dishID }) else {
            if delta > 0, let dish = activeDishes.first(where: { $0.id == dishID }) {
                addToCart(dish: dish)
            }
            return
        }
        updateCartQuantity(itemID: item.id, delta: delta)
    }

    func updateCartQuantity(itemID: String, delta: Int) {
        guard let index = cartItems.firstIndex(where: { $0.id == itemID }) else { return }
        let newQty = cartItems[index].quantity + delta
        if newQty <= 0 {
            cartItems.remove(at: index)
        } else {
            cartItems[index].quantity = newQty
        }
    }

    func removeFromCart(itemID: String) {
        cartItems.removeAll { $0.id == itemID }
    }

    func clearCart() {
        cartItems.removeAll()
    }

    func submitCart() async {
        guard !cartItems.isEmpty, !isSubmittingCart else { return }
        error = nil
        isSubmittingCart = true
        defer { isSubmittingCart = false }

        do {
            if currentOrder == nil {
                let order = try await apiClient.createOrder(
                    kitchenID: kitchen!.id, authToken: authToken
                )
                currentOrder = order
            }

            let orderID = currentOrder!.id

            for item in cartItems {
                _ = try await apiClient.addOrderItem(
                    orderID: orderID,
                    dishID: item.dishID,
                    quantity: item.quantity,
                    authToken: authToken
                )
            }

            cartItems.removeAll()
            await refreshOrderItems()
        } catch {
            consumeError(error)
        }
    }

    // MARK: - Orders

    func cycleStatus(for itemID: String) async {
        guard let index = orderItems.firstIndex(where: { $0.id == itemID }) else { return }
        let item = orderItems[index]
        let next: ItemStatus
        switch item.status {
        case .waiting: next = .cooking
        case .cooking: next = .done
        case .done, .cancelled: return
        }

        do {
            let updated = try await apiClient.updateOrderItem(
                id: itemID, status: next, authToken: authToken
            )
            orderItems[index] = updated
        } catch {
            consumeError(error)
        }
    }

    func cycleStatuses(for itemIDs: [String]) async {
        for itemID in itemIDs {
            await cycleStatus(for: itemID)
        }
    }

    @discardableResult
    func reduceWaitingItemQuantity(for groupedItem: GroupedOrderItem) async -> Bool {
        guard groupedItem.status == .waiting else { return false }
        guard let target = orderItems
            .filter({ groupedItem.itemIDs.contains($0.id) && $0.status == .waiting })
            .sorted(by: { $0.createdAt > $1.createdAt })
            .first else { return false }

        do {
            let updated = try await apiClient.updateOrderItem(
                id: target.id,
                quantity: target.quantity - 1,
                authToken: authToken
            )
            applyOrderItemUpdate(updated)
            return true
        } catch {
            consumeError(error)
            return false
        }
    }

    @discardableResult
    func cancelWaitingItems(for groupedItem: GroupedOrderItem) async -> Bool {
        guard groupedItem.status == .waiting else { return false }
        do {
            for itemID in groupedItem.itemIDs {
                let updated = try await apiClient.updateOrderItem(
                    id: itemID,
                    status: .cancelled,
                    authToken: authToken
                )
                applyOrderItemUpdate(updated)
            }
            return true
        } catch {
            consumeError(error)
            return false
        }
    }

    func title(for itemID: String) -> String {
        guard let item = orderItems.first(where: { $0.id == itemID }) else { return "待制作" }
        return item.status.title
    }

    @discardableResult
    func finishOrder() async -> Bool {
        guard let order = currentOrder else { return false }
        do {
            _ = try await apiClient.finishOrder(id: order.id, authToken: authToken)
            currentOrder = nil
            orderItems = []
            shoppingListItems = []
            orderHistory = []
            selectedOrderDetail = nil
            return true
        } catch {
            consumeError(error)
            return false
        }
    }

    func fetchOrderHistory() async {
        guard let kitchen else { return }
        do {
            let fetchedHistory = try await apiClient.fetchOrderHistory(
                kitchenID: kitchen.id,
                authToken: authToken
            )
            orderHistory = fetchedHistory.filter { $0.status == .finished && $0.finishedAt != nil }
        } catch {
            consumeError(error)
        }
    }

    @discardableResult
    func fetchOrderDetail(orderID: String) async -> OrderDetail? {
        do {
            let detail = try await apiClient.fetchOrderDetail(orderID: orderID, authToken: authToken)
            selectedOrderDetail = detail
            return detail
        } catch {
            consumeError(error)
            return nil
        }
    }

    func fetchShoppingList() {
        guard currentOrder != nil else {
            shoppingListItems = []
            return
        }
        let activeItems = orderItems.filter { $0.status != .cancelled }
        var ingredientDishes: [String: Set<String>] = [:]
        var ingredientDishNames: [String: Set<String>] = [:]
        for item in activeItems {
            guard let dish = dishes.first(where: { $0.id == item.dishId }) else { continue }
            for ingredient in dish.ingredients {
                ingredientDishes[ingredient, default: []].insert(dish.id)
                ingredientDishNames[ingredient, default: []].insert(dish.name)
            }
        }
        shoppingListItems = ingredientDishes
            .map { ingredient, dishIDs in
                ShoppingListItem(
                    ingredient: ingredient,
                    dishCount: dishIDs.count,
                    dishNames: ingredientDishNames[ingredient, default: []].sorted()
                )
            }
            .sorted { $0.ingredient < $1.ingredient }
    }

    // MARK: - Private Helpers

    private func completeOnboarding(inviteCode: String, kitchenName: String) async {
        let trimmedCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = kitchenName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCode.isEmpty || !trimmedName.isEmpty else { return }
        let mode = trimmedCode.isEmpty ? "create" : "join"

        do {
            let result = try await apiClient.onboardingComplete(
                mode: mode,
                authToken: authToken,
                inviteCode: trimmedCode.isEmpty ? nil : trimmedCode,
                kitchenName: trimmedName.isEmpty ? nil : trimmedName
            )
            kitchen = result.kitchen
            members = [result.member]
            UserDefaults.standard.set(result.kitchen.id, forKey: "lastKitchenID")
        } catch {
            consumeError(error)
        }
    }

    private func persistAuth(_ token: String, account: Account) {
        authToken = token
        currentAccount = account
        storedNickName = account.nickName
        UserDefaults.standard.set(token, forKey: "authToken")
        UserDefaults.standard.set(account.id, forKey: "accountID")
        UserDefaults.standard.set(account.nickName, forKey: "nickName")
    }

    private func clearKitchenState() {
        kitchen = nil
        members = []
        dishes = []
        orderItems = []
        orderHistory = []
        selectedOrderDetail = nil
        cartItems = []
        currentOrder = nil
        UserDefaults.standard.removeObject(forKey: "lastKitchenID")
    }

    func clearSession() {
        authToken = ""
        currentAccount = nil
        clearKitchenState()
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "accountID")
        UserDefaults.standard.removeObject(forKey: "nickName")
    }

    private func applyOrderItemUpdate(_ updated: OrderItem) {
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
