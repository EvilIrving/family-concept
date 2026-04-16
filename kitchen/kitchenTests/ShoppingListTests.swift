import Foundation
import Testing
@testable import kitchen

@MainActor
@Suite("采购清单聚合")
struct ShoppingListTests {

    @Test("fetchShoppingList 聚合同一食材对应的不同菜品并按食材排序")
    func fetchShoppingListAggregatesUniqueDishesPerIngredient() {
        let store = AppStore()
        store.currentOrder = Order(
            id: "o1",
            kitchenId: "k1",
            status: .open,
            createdByAccountId: "a1",
            createdAt: "",
            finishedAt: nil
        )
        store.dishes = [
            makeDish(id: "d1", name: "番茄炒蛋", ingredients: ["番茄", "鸡蛋", "葱"]),
            makeDish(id: "d2", name: "番茄牛腩", ingredients: ["番茄", "牛腩"]),
            makeDish(id: "d3", name: "宫保鸡丁", ingredients: ["鸡肉", "葱"])
        ]
        store.orderItems = [
            makeItem(id: "i1", dishId: "d1", quantity: 2, status: .waiting),
            makeItem(id: "i2", dishId: "d1", quantity: 1, status: .cooking),
            makeItem(id: "i3", dishId: "d2", quantity: 1, status: .done),
            makeItem(id: "i4", dishId: "d3", quantity: 1, status: .cancelled)
        ]

        store.fetchShoppingList()

        let ingredients = store.shoppingListItems.map(\.ingredient)
        #expect(ingredients == ingredients.sorted())
        #expect(Set(ingredients) == Set(["牛腩", "番茄", "鸡蛋", "葱"]))

        let byIngredient = Dictionary(uniqueKeysWithValues: store.shoppingListItems.map { ($0.ingredient, $0) })
        #expect(byIngredient["牛腩"]?.dishCount == 1)
        #expect(byIngredient["牛腩"]?.dishNames == ["番茄牛腩"])
        #expect(byIngredient["番茄"]?.dishCount == 2)
        #expect(byIngredient["番茄"]?.dishNames == ["番茄炒蛋", "番茄牛腩"])
        #expect(byIngredient["鸡蛋"]?.dishNames == ["番茄炒蛋"])
        #expect(byIngredient["葱"]?.dishNames == ["番茄炒蛋"])
    }

    @Test("fetchShoppingList 在没有当前订单时清空采购清单")
    func fetchShoppingListClearsItemsWithoutCurrentOrder() {
        let store = AppStore()
        store.shoppingListItems = [
            ShoppingListItem(ingredient: "番茄", dishCount: 1, dishNames: ["番茄炒蛋"])
        ]

        store.fetchShoppingList()

        #expect(store.shoppingListItems.isEmpty)
    }

    private func makeDish(id: String, name: String, ingredients: [String]) -> Dish {
        let jsonData = try! JSONEncoder().encode(ingredients)
        let json = String(decoding: jsonData, as: UTF8.self)

        return Dish(
            id: id,
            kitchenId: "k1",
            name: name,
            category: "家常",
            imageKey: nil,
            ingredientsJson: json,
            createdByAccountId: "a1",
            createdAt: "",
            updatedAt: "",
            archivedAt: nil
        )
    }

    private func makeItem(id: String, dishId: String, quantity: Int, status: ItemStatus) -> OrderItem {
        OrderItem(
            id: id,
            orderId: "o1",
            dishId: dishId,
            addedByAccountId: "a1",
            quantity: quantity,
            status: status,
            createdAt: "",
            updatedAt: ""
        )
    }
}
