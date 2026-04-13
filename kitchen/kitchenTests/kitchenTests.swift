import Testing
@testable import kitchen

struct kitchenTests {

    // MARK: - Model computed properties

    @Test func dishIngredientsParsesValidJSON() {
        let dish = Dish(
            id: "1", kitchenId: "k1", name: "番茄炒蛋", category: "家常",
            imageKey: nil, ingredientsJson: "[\"番茄\",\"鸡蛋\"]",
            createdByDeviceId: "d1", createdAt: "", updatedAt: "", archivedAt: nil
        )
        #expect(dish.ingredients == ["番茄", "鸡蛋"])
    }

    @Test func dishIngredientsReturnsEmptyOnInvalidJSON() {
        let dish = Dish(
            id: "1", kitchenId: "k1", name: "test", category: "test",
            imageKey: nil, ingredientsJson: "not json",
            createdByDeviceId: "d1", createdAt: "", updatedAt: "", archivedAt: nil
        )
        #expect(dish.ingredients == [])
    }

    @Test func dishIsArchivedWhenArchivedAtNonNil() {
        let archived = Dish(
            id: "1", kitchenId: "k1", name: "test", category: "test",
            imageKey: nil, ingredientsJson: "[]",
            createdByDeviceId: "d1", createdAt: "", updatedAt: "", archivedAt: "2026-01-01"
        )
        let active = Dish(
            id: "2", kitchenId: "k1", name: "test", category: "test",
            imageKey: nil, ingredientsJson: "[]",
            createdByDeviceId: "d1", createdAt: "", updatedAt: "", archivedAt: nil
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
            createdByDeviceId: "dev1", createdAt: "", updatedAt: "", archivedAt: nil
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
            createdByDeviceId: "dev1", createdAt: "", updatedAt: "", archivedAt: nil
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
            createdByDeviceId: "dev1", createdAt: "", updatedAt: "", archivedAt: nil
        )

        store.addToCart(dish: dish)
        let cartItemID = store.cartItems.first!.id
        store.removeFromCart(itemID: cartItemID)
        #expect(store.cartItems.isEmpty)
    }

    @Test func clearCartRemovesAll() {
        let store = AppStore()
        let d1 = Dish(id: "d1", kitchenId: "k1", name: "a", category: "b",
                       imageKey: nil, ingredientsJson: "[]", createdByDeviceId: "dev1",
                       createdAt: "", updatedAt: "", archivedAt: nil)
        let d2 = Dish(id: "d2", kitchenId: "k1", name: "b", category: "b",
                       imageKey: nil, ingredientsJson: "[]", createdByDeviceId: "dev1",
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

}
