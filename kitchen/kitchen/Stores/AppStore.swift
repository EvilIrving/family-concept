import Foundation
import Combine

final class AppStore: ObservableObject {
    @Published var currentUser = UserProfile(id: UUID(), name: "Cain", role: .owner)
    @Published var kitchen: KitchenInfo?
    @Published var dishes: [Dish] = []
    @Published var orderItems: [OrderItem] = []

    init() {
        seedDemoData()
    }

    var hasKitchen: Bool {
        kitchen != nil
    }

    var activeDishes: [Dish] {
        dishes.filter { $0.archivedAt == nil }
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

    func joinKitchen(inviteCode: String) {
        guard !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        kitchen = KitchenInfo(name: "家宴厨房", inviteCode: inviteCode.uppercased())
    }

    func createKitchen(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        kitchen = KitchenInfo(name: trimmed, inviteCode: "QH8M2")
    }

    func addDish(name: String, category: String, ingredientsText: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let ingredients = ingredientsText
            .split(separator: "、")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !trimmedName.isEmpty, !trimmedCategory.isEmpty else { return }
        dishes.insert(
            Dish(id: UUID(), name: trimmedName, category: trimmedCategory, ingredients: ingredients, archivedAt: nil),
            at: 0
        )
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
                    status: .waiting,
                    addedBy: currentUser.name
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
        dishes = [
            Dish(id: UUID(), name: "青椒小炒肉", category: "家常菜", ingredients: ["青椒", "猪肉", "蒜"], archivedAt: nil),
            Dish(id: UUID(), name: "番茄鸡蛋", category: "快手菜", ingredients: ["番茄", "鸡蛋", "葱"], archivedAt: nil),
            Dish(id: UUID(), name: "冰美式", category: "饮品", ingredients: ["咖啡豆", "冰块"], archivedAt: nil)
        ]
        orderItems = [
            OrderItem(id: UUID(), dishID: dishes[0].id, dishName: dishes[0].name, quantity: 2, status: .waiting, addedBy: "Cain"),
            OrderItem(id: UUID(), dishID: dishes[1].id, dishName: dishes[1].name, quantity: 1, status: .cooking, addedBy: "Mia")
        ]
    }
}
