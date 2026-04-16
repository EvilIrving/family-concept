import Testing
@testable import kitchen

@MainActor
struct kitchenTests {

    // MARK: - Model computed properties

    @Test func dishIngredientsParsesValidJSON() {
        let dish = Dish(
            id: "1", kitchenId: "k1", name: "番茄炒蛋", category: "家常",
            imageKey: nil, ingredientsJson: "[\"番茄\",\"鸡蛋\"]",
            createdByAccountId: "d1", createdAt: "", updatedAt: "", archivedAt: nil
        )
        #expect(dish.ingredients == ["番茄", "鸡蛋"])
    }

    @Test func dishIngredientsReturnsEmptyOnInvalidJSON() {
        let dish = Dish(
            id: "1", kitchenId: "k1", name: "test", category: "test",
            imageKey: nil, ingredientsJson: "not json",
            createdByAccountId: "d1", createdAt: "", updatedAt: "", archivedAt: nil
        )
        #expect(dish.ingredients == [])
    }

    @Test func dishIsArchivedWhenArchivedAtNonNil() {
        let archived = Dish(
            id: "1", kitchenId: "k1", name: "test", category: "test",
            imageKey: nil, ingredientsJson: "[]",
            createdByAccountId: "d1", createdAt: "", updatedAt: "", archivedAt: "2026-01-01"
        )
        let active = Dish(
            id: "2", kitchenId: "k1", name: "test", category: "test",
            imageKey: nil, ingredientsJson: "[]",
            createdByAccountId: "d1", createdAt: "", updatedAt: "", archivedAt: nil
        )
        #expect(archived.isArchived == true)
        #expect(active.isArchived == false)
    }

    @Test func itemStatusTitles() {
        #expect(ItemStatus.waiting.title == "待制作")
        #expect(ItemStatus.cooking.title == "制作中")
        #expect(ItemStatus.done.title == "已完成")
        #expect(ItemStatus.cancelled.title == "已取消")
    }

    @Test func kitchenRoleTitles() {
        #expect(KitchenRole.owner.title == "管理员")
        #expect(KitchenRole.admin.title == "副管理员")
        #expect(KitchenRole.member.title == "成员")
    }

    // MARK: - Cart operations (local, no API needed)

    @Test func cartQuantityStartsAtZero() {
        let store = AppStore()
        #expect(store.cartQuantity(for: "nonexistent") == 0)
    }

    @Test func addToCartIncrementsQuantity() {
        let store = AppStore()
        let dish = Dish(
            id: "d1", kitchenId: "k1", name: "番茄炒蛋", category: "家常",
            imageKey: nil, ingredientsJson: "[]",
            createdByAccountId: "dev1", createdAt: "", updatedAt: "", archivedAt: nil
        )

        store.addToCart(dish: dish)
        #expect(store.cartCount == 1)
        #expect(store.cartQuantity(for: "d1") == 1)

        store.addToCart(dish: dish)
        #expect(store.cartQuantity(for: "d1") == 2)
    }

    @Test func updateCartQuantityRemovesWhenZero() {
        let store = AppStore()
        let dish = Dish(
            id: "d1", kitchenId: "k1", name: "test", category: "test",
            imageKey: nil, ingredientsJson: "[]",
            createdByAccountId: "dev1", createdAt: "", updatedAt: "", archivedAt: nil
        )

        store.addToCart(dish: dish)
        #expect(store.cartQuantity(for: "d1") == 1)

        store.updateCartQuantity(dishID: "d1", delta: -1)
        #expect(store.cartQuantity(for: "d1") == 0)
        #expect(store.cartItems.isEmpty)
    }

    @Test func removeFromCartById() {
        let store = AppStore()
        let dish = Dish(
            id: "d1", kitchenId: "k1", name: "test", category: "test",
            imageKey: nil, ingredientsJson: "[]",
            createdByAccountId: "dev1", createdAt: "", updatedAt: "", archivedAt: nil
        )

        store.addToCart(dish: dish)
        let cartItemID = store.cartItems.first!.id
        store.removeFromCart(itemID: cartItemID)
        #expect(store.cartItems.isEmpty)
    }

    @Test func clearCartRemovesAll() {
        let store = AppStore()
        let d1 = Dish(id: "d1", kitchenId: "k1", name: "a", category: "b",
                       imageKey: nil, ingredientsJson: "[]", createdByAccountId: "dev1",
                       createdAt: "", updatedAt: "", archivedAt: nil)
        let d2 = Dish(id: "d2", kitchenId: "k1", name: "b", category: "b",
                       imageKey: nil, ingredientsJson: "[]", createdByAccountId: "dev1",
                       createdAt: "", updatedAt: "", archivedAt: nil)

        store.addToCart(dish: d1)
        store.addToCart(dish: d2)
        #expect(store.cartCount == 2)

        store.clearCart()
        #expect(store.cartItems.isEmpty)
    }

    // MARK: - Role computed properties

    @Test func rolePropertiesDefaultToNilWithoutKitchen() {
        let store = AppStore()
        #expect(store.currentRole == nil)
        #expect(store.isOwner == false)
        #expect(store.isAdmin == false)
        #expect(store.canManageDishes == false)
        #expect(store.canManageOrders == false)
    }

    @Test func groupedOrderItemsMergesSameDishAndStatus() {
        let dishes = [
            Dish(id: "d1", kitchenId: "k1", name: "宫保鸡丁", category: "热菜",
                 imageKey: nil, ingredientsJson: "[]", createdByAccountId: "a1",
                 createdAt: "", updatedAt: "", archivedAt: nil),
            Dish(id: "d2", kitchenId: "k1", name: "冬阴功汤", category: "汤",
                 imageKey: nil, ingredientsJson: "[]", createdByAccountId: "a1",
                 createdAt: "", updatedAt: "", archivedAt: nil)
        ]
        let items = [
            OrderItem(id: "i1", orderId: "o1", dishId: "d1", addedByAccountId: "a1", quantity: 1, status: .waiting, createdAt: "1", updatedAt: "1"),
            OrderItem(id: "i2", orderId: "o1", dishId: "d1", addedByAccountId: "a1", quantity: 2, status: .waiting, createdAt: "2", updatedAt: "2"),
            OrderItem(id: "i3", orderId: "o1", dishId: "d1", addedByAccountId: "a1", quantity: 1, status: .cooking, createdAt: "3", updatedAt: "3"),
            OrderItem(id: "i4", orderId: "o1", dishId: "d2", addedByAccountId: "a1", quantity: 1, status: .done, createdAt: "4", updatedAt: "4")
        ]

        let grouped = items.grouped(using: dishes)

        #expect(grouped.count == 3)
        #expect(grouped[0].dishName == "宫保鸡丁")
        #expect(grouped[0].status == .waiting)
        #expect(grouped[0].quantity == 3)
        #expect(grouped[0].itemIDs == ["i1", "i2"])
        #expect(grouped[1].status == .cooking)
        #expect(grouped[1].quantity == 1)
        #expect(grouped[2].dishName == "冬阴功汤")
    }

    @Test func orderQuantityCountsUseItemQuantity() {
        let store = AppStore()
        store.orderItems = [
            OrderItem(id: "i1", orderId: "o1", dishId: "d1", addedByAccountId: "a1", quantity: 3, status: .waiting, createdAt: "", updatedAt: ""),
            OrderItem(id: "i2", orderId: "o1", dishId: "d1", addedByAccountId: "a1", quantity: 1, status: .cooking, createdAt: "", updatedAt: ""),
            OrderItem(id: "i3", orderId: "o1", dishId: "d2", addedByAccountId: "a1", quantity: 2, status: .done, createdAt: "", updatedAt: ""),
            OrderItem(id: "i4", orderId: "o1", dishId: "d3", addedByAccountId: "a1", quantity: 5, status: .cancelled, createdAt: "", updatedAt: "")
        ]

        #expect(store.totalOrderQuantity == 6)
        #expect(store.quantity(for: .waiting) == 3)
        #expect(store.quantity(for: .cooking) == 1)
        #expect(store.quantity(for: .done) == 2)
    }

}
