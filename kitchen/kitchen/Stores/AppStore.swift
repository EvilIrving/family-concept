import Foundation
import Combine

@MainActor
final class AppStore: ObservableObject {
    @Published var currentDevice: Device?
    @Published var kitchen: Kitchen?
    @Published var members: [Member] = []
    @Published var dishes: [Dish] = []
    @Published var currentOrder: Order?
    @Published var orderItems: [OrderItem] = []
    @Published var cartItems: [CartItem] = []
    @Published var shoppingListItems: [ShoppingListItem] = []
    @Published var isLoading: Bool = false
    @Published var error: String?

    let apiClient = APIClient()

    let deviceId: String
    private(set) var storedDisplayName: String

    init() {
        if let stored = UserDefaults.standard.string(forKey: "deviceID") {
            deviceId = stored
        } else {
            let newID = UUID().uuidString
            UserDefaults.standard.set(newID, forKey: "deviceID")
            deviceId = newID
        }
        storedDisplayName = UserDefaults.standard.string(forKey: "displayName") ?? ""
    }

    // MARK: - Computed

    var currentMember: Member? {
        members.first { $0.deviceRefId == currentDevice?.id }
    }

    var currentRole: KitchenRole? {
        currentMember?.role
    }

    var isOwner: Bool { currentRole == .owner }
    var isAdmin: Bool { currentRole == .admin }
    var canManageDishes: Bool { isOwner || isAdmin }
    var canManageOrders: Bool { isOwner || isAdmin }

    var hasKitchen: Bool { kitchen != nil }

    var activeDishes: [Dish] {
        dishes.filter { $0.archivedAt == nil }
    }

    var dishCategories: [String] {
        Array(Set(activeDishes.map(\.category))).sorted()
    }

    var cartCount: Int {
        cartItems.reduce(0) { $0 + $1.quantity }
    }

    func cartQuantity(for dishID: String) -> Int {
        cartItems.first(where: { $0.dishID == dishID })?.quantity ?? 0
    }

    // MARK: - Data Loading

    func fetchAll() async {
        guard let kitchen else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            async let membersReq: [Member] = apiClient.fetchMembers(
                kitchenID: kitchen.id, deviceId: deviceId
            )
            async let dishesReq: [Dish] = apiClient.fetchDishes(
                kitchenID: kitchen.id, deviceId: deviceId
            )
            async let orderReq: APIClient.OpenOrderResponse? = apiClient.fetchOpenOrder(
                kitchenID: kitchen.id, deviceId: deviceId
            )

            let (fetchedMembers, fetchedDishes, fetchedOrder) = try await (membersReq, dishesReq, orderReq)
            self.members = fetchedMembers
            self.dishes = fetchedDishes

            if let order = fetchedOrder {
                self.currentOrder = Order(
                    id: order.id,
                    kitchenId: order.kitchenId,
                    status: order.status,
                    createdByDeviceId: order.createdByDeviceId,
                    createdAt: order.createdAt,
                    finishedAt: order.finishedAt
                )
                self.orderItems = order.items ?? []
            } else {
                self.currentOrder = nil
                self.orderItems = []
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func refreshOrderItems() async {
        guard let kitchen else { return }
        do {
            let result = try await apiClient.fetchOpenOrder(
                kitchenID: kitchen.id, deviceId: deviceId
            )
            if let order = result {
                self.currentOrder = Order(
                    id: order.id, kitchenId: order.kitchenId,
                    status: order.status, createdByDeviceId: order.createdByDeviceId,
                    createdAt: order.createdAt, finishedAt: order.finishedAt
                )
                self.orderItems = order.items ?? []
            } else {
                self.currentOrder = nil
                self.orderItems = []
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Onboarding

    func createKitchen(named name: String, displayName: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmedName.isEmpty else { return }

        storedDisplayName = trimmedName
        UserDefaults.standard.set(trimmedName, forKey: "displayName")

        do {
            let result = try await apiClient.onboardingComplete(
                mode: "create",
                deviceID: deviceId,
                displayName: trimmedName,
                kitchenName: trimmed
            )
            currentDevice = result.device
            kitchen = result.kitchen
            let m = result.member
            members = [Member(
                id: m.id, kitchenId: m.kitchenId, deviceRefId: m.deviceRefId,
                role: m.role, status: m.status, joinedAt: m.joinedAt,
                removedAt: m.removedAt, displayName: trimmedName
            )]
        } catch {
            self.error = error.localizedDescription
        }
    }

    func joinKitchen(inviteCode: String, displayName: String) async {
        let trimmedCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty, !trimmedName.isEmpty else { return }
        storedDisplayName = trimmedName
        UserDefaults.standard.set(trimmedName, forKey: "displayName")

        do {
            let result = try await apiClient.onboardingComplete(
                mode: "join",
                deviceID: deviceId,
                displayName: trimmedName,
                inviteCode: trimmedCode
            )
            currentDevice = result.device
            kitchen = result.kitchen
            let m = result.member
            members = [Member(
                id: m.id, kitchenId: m.kitchenId, deviceRefId: m.deviceRefId,
                role: m.role, status: m.status, joinedAt: m.joinedAt,
                removedAt: m.removedAt, displayName: trimmedName
            )]
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Kitchen

    func updateKitchenName(_ name: String) async {
        guard let kitchen else { return }
        do {
            let updated = try await apiClient.updateKitchen(
                id: kitchen.id, name: name, deviceId: deviceId
            )
            self.kitchen = updated
        } catch {
            self.error = error.localizedDescription
        }
    }

    func rotateInviteCode() async {
        guard let kitchen else { return }
        do {
            let result = try await apiClient.rotateInviteCode(
                kitchenID: kitchen.id, deviceId: deviceId
            )
            self.kitchen = Kitchen(
                id: kitchen.id, name: kitchen.name,
                ownerDeviceId: kitchen.ownerDeviceId,
                inviteCode: result.inviteCode,
                inviteCodeRotatedAt: kitchen.inviteCodeRotatedAt,
                createdAt: kitchen.createdAt
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Members

    func removeMember(deviceRefID: String) async {
        guard let kitchen else { return }
        do {
            _ = try await apiClient.removeMember(
                kitchenID: kitchen.id, deviceRefID: deviceRefID, deviceId: deviceId
            )
            members.removeAll { $0.deviceRefId == deviceRefID }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func leaveKitchen() async {
        guard let kitchen else { return }
        do {
            _ = try await apiClient.leaveKitchen(
                kitchenID: kitchen.id, deviceId: deviceId
            )
            self.kitchen = nil
            members = []
            dishes = []
            orderItems = []
            cartItems = []
            currentOrder = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Dishes

    func addDish(name: String, category: String, ingredients: [String]) async {
        guard let kitchen else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedCategory.isEmpty else { return }

        do {
            let dish = try await apiClient.createDish(
                kitchenID: kitchen.id,
                name: trimmedName,
                category: trimmedCategory,
                ingredients: ingredients,
                deviceId: deviceId
            )
            dishes.insert(dish, at: 0)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func archiveDish(id: String) async {
        do {
            _ = try await apiClient.archiveDish(id: id, deviceId: deviceId)
            dishes.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
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
        guard !cartItems.isEmpty else { return }

        do {
            // Ensure an open order exists
            if currentOrder == nil {
                let order = try await apiClient.createOrder(
                    kitchenID: kitchen!.id, deviceId: deviceId
                )
                currentOrder = order
            }

            let orderID = currentOrder!.id

            // Submit each cart item
            for item in cartItems {
                _ = try await apiClient.addOrderItem(
                    orderID: orderID,
                    dishID: item.dishID,
                    quantity: item.quantity,
                    deviceId: deviceId
                )
            }

            cartItems.removeAll()

            // Refresh order items from server
            await refreshOrderItems()
        } catch {
            self.error = error.localizedDescription
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
        case .done: next = .waiting
        case .cancelled: next = .waiting
        }

        do {
            let updated = try await apiClient.updateOrderItem(
                id: itemID, status: next, deviceId: deviceId
            )
            orderItems[index] = updated
        } catch {
            self.error = error.localizedDescription
        }
    }

    func title(for itemID: String) -> String {
        guard let item = orderItems.first(where: { $0.id == itemID }) else { return "待制作" }
        return item.status.title
    }

    func finishOrder() async {
        guard let order = currentOrder else { return }
        do {
            let finished = try await apiClient.finishOrder(id: order.id, deviceId: deviceId)
            currentOrder = nil
            orderItems = []
            _ = finished
        } catch {
            self.error = error.localizedDescription
        }
    }

    func fetchShoppingList() {
        guard currentOrder != nil else {
            shoppingListItems = []
            return
        }
        let activeItems = orderItems.filter { $0.status != .cancelled }
        var ingredientDishes: [String: Set<String>] = [:]
        for item in activeItems {
            guard let dish = dishes.first(where: { $0.id == item.dishId }) else { continue }
            for ingredient in dish.ingredients {
                ingredientDishes[ingredient, default: []].insert(dish.id)
            }
        }
        shoppingListItems = ingredientDishes
            .map { ShoppingListItem(ingredient: $0.key, dishCount: $0.value.count) }
            .sorted { $0.ingredient < $1.ingredient }
    }
}
