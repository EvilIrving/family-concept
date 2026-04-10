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
        switch role {
        case .owner:
            transferOwnership(to: memberID)
        case .member:
            guard let index = members.firstIndex(where: { $0.id == memberID }) else { return }
            members[index].role = .member
        }
    }

    /// 将指定成员设为管理员（owner）；本机当前若为管理员，则降为普通成员。
    func transferOwnership(to memberID: UUID) {
        guard isOwner, memberID != currentDeviceID else { return }
        guard let newOwnerIndex = members.firstIndex(where: { $0.id == memberID }),
              let oldOwnerIndex = members.firstIndex(where: { $0.id == currentDeviceID }) else { return }
        members[newOwnerIndex].role = .owner
        members[oldOwnerIndex].role = .member
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

    func cartQuantity(for dishID: UUID) -> Int {
        cartItems.first(where: { $0.dishID == dishID })?.quantity ?? 0
    }

    func addToCart(dish: Dish) {
        if let index = cartItems.firstIndex(where: { $0.dishID == dish.id }) {
            cartItems[index].quantity += 1
        } else {
            cartItems.insert(CartItem(id: UUID(), dishID: dish.id, dishName: dish.name, quantity: 1), at: 0)
        }
    }

    func updateCartQuantity(dishID: UUID, delta: Int) {
        guard let item = cartItems.first(where: { $0.dishID == dishID }) else {
            if delta > 0, let dish = activeDishes.first(where: { $0.id == dishID }) {
                addToCart(dish: dish)
            }
            return
        }
        updateCartQuantity(itemID: item.id, delta: delta)
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
            Member(id: UUID(), displayName: "妈妈", role: .member),
            Member(id: UUID(), displayName: "爸爸", role: .member),
            Member(id: UUID(), displayName: "奶奶", role: .member),
            Member(id: UUID(), displayName: "二宝", role: .member)
        ]
        dishes = [
            Dish(id: UUID(), name: "青椒小炒肉", category: "家常菜", ingredients: ["青椒", "猪肉", "蒜"], archivedAt: nil),
            Dish(id: UUID(), name: "番茄鸡蛋", category: "快手菜", ingredients: ["番茄", "鸡蛋", "葱"], archivedAt: nil),
            Dish(id: UUID(), name: "冰美式", category: "饮品", ingredients: ["咖啡豆", "冰块"], archivedAt: nil),
            Dish(id: UUID(), name: "酸辣土豆丝", category: "家常菜", ingredients: ["土豆", "干辣椒", "醋"], archivedAt: nil),
            Dish(id: UUID(), name: "蒜蓉西兰花", category: "家常菜", ingredients: ["西兰花", "蒜"], archivedAt: nil),
            Dish(id: UUID(), name: "红烧肉", category: "家常菜", ingredients: ["五花肉", "姜", "冰糖"], archivedAt: nil),
            Dish(id: UUID(), name: "清蒸鲈鱼", category: "海鲜", ingredients: ["鲈鱼", "葱", "姜"], archivedAt: nil),
            Dish(id: UUID(), name: "麻婆豆腐", category: "川菜", ingredients: ["豆腐", "牛肉末", "花椒"], archivedAt: nil),
            Dish(id: UUID(), name: "宫保鸡丁", category: "川菜", ingredients: ["鸡胸肉", "花生", "干辣椒"], archivedAt: nil),
            Dish(id: UUID(), name: "白切鸡", category: "粤菜", ingredients: ["鸡", "姜", "葱"], archivedAt: nil),
            Dish(id: UUID(), name: "蛋炒饭", category: "主食", ingredients: ["米饭", "鸡蛋", "葱"], archivedAt: nil),
            Dish(id: UUID(), name: "紫菜蛋花汤", category: "汤羹", ingredients: ["紫菜", "鸡蛋", "香油"], archivedAt: nil),
            Dish(id: UUID(), name: "凉拌黄瓜", category: "凉菜", ingredients: ["黄瓜", "蒜", "醋"], archivedAt: nil),
            Dish(id: UUID(), name: "糖醋排骨", category: "家常菜", ingredients: ["排骨", "醋", "糖"], archivedAt: nil),
            Dish(id: UUID(), name: "可乐鸡翅", category: "家常菜", ingredients: ["鸡翅", "可乐", "姜"], archivedAt: nil),
            Dish(id: UUID(), name: "香菇青菜", category: "素菜", ingredients: ["香菇", "青菜", "蒜"], archivedAt: nil),
            Dish(id: UUID(), name: "葱油饼", category: "主食", ingredients: ["面粉", "葱", "油"], archivedAt: nil),
            Dish(id: UUID(), name: "芒果西米露", category: "甜品", ingredients: ["芒果", "西米", "椰奶"], archivedAt: nil),
            Dish(id: UUID(), name: "柠檬蜂蜜水", category: "饮品", ingredients: ["柠檬", "蜂蜜", "水"], archivedAt: nil),
            Dish(id: UUID(), name: "干煸四季豆", category: "家常菜", ingredients: ["四季豆", "肉末", "干辣椒"], archivedAt: nil)
        ]
        orderItems = [
            OrderItem(id: UUID(), dishID: dishes[0].id, dishName: dishes[0].name, quantity: 2, status: .waiting),
            OrderItem(id: UUID(), dishID: dishes[1].id, dishName: dishes[1].name, quantity: 1, status: .cooking),
            OrderItem(id: UUID(), dishID: dishes[3].id, dishName: dishes[3].name, quantity: 3, status: .waiting),
            OrderItem(id: UUID(), dishID: dishes[6].id, dishName: dishes[6].name, quantity: 1, status: .done),
            OrderItem(id: UUID(), dishID: dishes[7].id, dishName: dishes[7].name, quantity: 2, status: .cooking),
            OrderItem(id: UUID(), dishID: dishes[10].id, dishName: dishes[10].name, quantity: 4, status: .waiting),
            OrderItem(id: UUID(), dishID: dishes[12].id, dishName: dishes[12].name, quantity: 1, status: .done),
            OrderItem(id: UUID(), dishID: dishes[15].id, dishName: dishes[15].name, quantity: 2, status: .waiting)
        ]
        cartItems = [
            CartItem(id: UUID(), dishID: dishes[4].id, dishName: dishes[4].name, quantity: 2),
            CartItem(id: UUID(), dishID: dishes[8].id, dishName: dishes[8].name, quantity: 1),
            CartItem(id: UUID(), dishID: dishes[11].id, dishName: dishes[11].name, quantity: 1),
            CartItem(id: UUID(), dishID: dishes[18].id, dishName: dishes[18].name, quantity: 3)
        ]
    }
}
