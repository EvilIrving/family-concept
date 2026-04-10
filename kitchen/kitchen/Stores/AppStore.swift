import Foundation
import Combine

final class AppStore: ObservableObject {
    @Published var kitchen: KitchenInfo?
    @Published var dishes: [Dish] = []
    @Published var orderItems: [OrderItem] = []
    @Published var cartItems: [CartItem] = []
    @Published var members: [Member] = []

    let currentDeviceID: UUID
    private(set) var storedDisplayName: String

    init() {
        if let stored = UserDefaults.standard.string(forKey: "deviceID"),
           let uuid = UUID(uuidString: stored) {
            currentDeviceID = uuid
        } else {
            let newID = UUID()
            UserDefaults.standard.set(newID.uuidString, forKey: "deviceID")
            currentDeviceID = newID
        }
        storedDisplayName = UserDefaults.standard.string(forKey: "displayName") ?? "本机"
        seedDemoData()
    }

    var currentMember: Member? {
        members.first { $0.id == currentDeviceID }
    }

    var isOwner: Bool {
        currentMember?.role == .owner
    }

    var hasKitchen: Bool {
        kitchen != nil
    }

    var activeDishes: [Dish] {
        dishes.filter { $0.archivedAt == nil }
    }

    var dishCategories: [String] {
        Array(Set(activeDishes.map(\.category))).sorted()
    }

    var shoppingList: [(name: String, count: Int)] {
        let dishMap = Dictionary(uniqueKeysWithValues: activeDishes.map { ($0.id, $0) })
        var counts: [String: Int] = [:]
        for item in orderItems where item.status != .cancelled {
            guard let dish = dishMap[item.dishID] else { continue }
            for ingredient in Set(dish.ingredients) {
                counts[ingredient, default: 0] += item.quantity
            }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.name < $1.name }
    }

    func joinKitchen(inviteCode: String, displayName: String) {
        let trimmedCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty, !trimmedName.isEmpty else { return }
        storedDisplayName = trimmedName
        UserDefaults.standard.set(trimmedName, forKey: "displayName")
        kitchen = KitchenInfo(name: "家宴厨房", inviteCode: trimmedCode.uppercased())
        if let index = members.firstIndex(where: { $0.id == currentDeviceID }) {
            members[index].displayName = trimmedName
            members[index].role = .member
        } else {
            members.append(Member(id: currentDeviceID, displayName: trimmedName, role: .member))
        }
    }

    func createKitchen(named name: String, displayName: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmedName.isEmpty else { return }
        storedDisplayName = trimmedName
        UserDefaults.standard.set(trimmedName, forKey: "displayName")
        kitchen = KitchenInfo(name: trimmed, inviteCode: "QH8M2")
        members = [Member(id: currentDeviceID, displayName: trimmedName, role: .owner)]
    }

    func updateRole(memberID: UUID, to role: MemberRole) {
        guard isOwner, memberID != currentDeviceID else { return }
        guard let index = members.firstIndex(where: { $0.id == memberID }) else { return }
        members[index].role = role
    }

    func updateDisplayName(memberID: UUID, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = members.firstIndex(where: { $0.id == memberID }) else { return }
        members[index].displayName = trimmed
    }

    func addDish(name: String, category: String, ingredients: [String]) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isOwner, !trimmedName.isEmpty, !trimmedCategory.isEmpty else { return }
        dishes.insert(
            Dish(id: UUID(), name: trimmedName, category: trimmedCategory, ingredients: ingredients, archivedAt: nil),
            at: 0
        )
    }

    func addDish(name: String, category: String, ingredientsText: String) {
        let ingredients = ingredientsText
            .split(whereSeparator: { ["、", ",", " "].contains(String($0)) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        addDish(name: name, category: category, ingredients: ingredients)
    }

    var cartCount: Int {
        cartItems.reduce(0) { $0 + $1.quantity }
    }

    func addToCart(dish: Dish) {
        if let index = cartItems.firstIndex(where: { $0.dishID == dish.id }) {
            cartItems[index].quantity += 1
        } else {
            cartItems.insert(CartItem(id: UUID(), dishID: dish.id, dishName: dish.name, quantity: 1), at: 0)
        }
    }

    func updateCartQuantity(itemID: UUID, delta: Int) {
        guard let index = cartItems.firstIndex(where: { $0.id == itemID }) else { return }
        let newQty = cartItems[index].quantity + delta
        if newQty <= 0 {
            cartItems.remove(at: index)
        } else {
            cartItems[index].quantity = newQty
        }
    }

    func removeFromCart(itemID: UUID) {
        cartItems.removeAll { $0.id == itemID }
    }

    func clearCart() {
        cartItems.removeAll()
    }

    func submitCart() {
        for item in cartItems {
            if let index = orderItems.firstIndex(where: { $0.dishID == item.dishID && $0.status != .cancelled }) {
                orderItems[index].quantity += item.quantity
            } else {
                orderItems.insert(
                    OrderItem(id: UUID(), dishID: item.dishID, dishName: item.dishName, quantity: item.quantity, status: .waiting),
                    at: 0
                )
            }
        }
        cartItems.removeAll()
    }

    func addToOrder(dish: Dish) {
        if let index = orderItems.firstIndex(where: { $0.dishID == dish.id && $0.status != .cancelled }) {
            orderItems[index].quantity += 1
        } else {
            orderItems.insert(
                OrderItem(
                    id: UUID(),
                    dishID: dish.id,
                    dishName: dish.name,
                    quantity: 1,
                    status: .waiting
                ),
                at: 0
            )
        }
    }

    func cycleStatus(for itemID: UUID) {
        guard let index = orderItems.firstIndex(where: { $0.id == itemID }) else { return }
        switch orderItems[index].status {
        case .waiting:
            orderItems[index].status = .cooking
        case .cooking:
            orderItems[index].status = .done
        case .done:
            orderItems[index].status = .waiting
        case .cancelled:
            orderItems[index].status = .waiting
        }
    }

    func title(for itemID: UUID) -> String {
        guard let item = orderItems.first(where: { $0.id == itemID }) else { return "待制作" }
        return item.status.title
    }

    private func seedDemoData() {
        kitchen = KitchenInfo(name: "家宴厨房", inviteCode: "QH8M2")
        members = [
            Member(id: currentDeviceID, displayName: storedDisplayName, role: .owner),
            Member(id: UUID(), displayName: "小明", role: .member),
            Member(id: UUID(), displayName: "妈妈", role: .member)
        ]
        dishes = [
            Dish(id: UUID(), name: "青椒小炒肉", category: "家常菜", ingredients: ["青椒", "猪肉", "蒜"], archivedAt: nil),
            Dish(id: UUID(), name: "番茄鸡蛋", category: "快手菜", ingredients: ["番茄", "鸡蛋", "葱"], archivedAt: nil),
            Dish(id: UUID(), name: "冰美式", category: "饮品", ingredients: ["咖啡豆", "冰块"], archivedAt: nil)
        ]
        orderItems = [
            OrderItem(id: UUID(), dishID: dishes[0].id, dishName: dishes[0].name, quantity: 2, status: .waiting),
            OrderItem(id: UUID(), dishID: dishes[1].id, dishName: dishes[1].name, quantity: 1, status: .cooking)
        ]
    }
}
