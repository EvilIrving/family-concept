import Testing
@testable import kitchen

@MainActor
@Suite("AppStore 本地业务规则")
struct AppStoreLocalRulesTests {

    @Test("购物车初始数量为零")
    func cartQuantityStartsAtZero() {
        let store = AppStore()

        #expect(store.cartQuantity(for: "nonexistent") == 0)
    }

    @Test("添加同一道菜会累计购物车数量")
    func addToCartIncrementsQuantity() {
        let store = AppStore()
        let dish = makeDish(id: "d1", name: "番茄炒蛋")

        store.addToCart(dish: dish)
        store.addToCart(dish: dish)

        #expect(store.cartCount == 2)
        #expect(store.cartQuantity(for: "d1") == 2)
    }

    @Test("按 dishID 增加数量时会从 active dishes 新增购物车项")
    func updateCartQuantityByDishIDAddsActiveDish() {
        let store = AppStore()
        store.dishes = [makeDish(id: "d1", name: "小炒黄牛肉")]

        store.updateCartQuantity(dishID: "d1", delta: 1)

        #expect(store.cartItems.count == 1)
        #expect(store.cartItems.first?.dishName == "小炒黄牛肉")
        #expect(store.cartQuantity(for: "d1") == 1)
    }

    @Test("购物车数量减到零时移除条目")
    func updateCartQuantityRemovesWhenZero() {
        let store = AppStore()
        let dish = makeDish(id: "d1", name: "test")

        store.addToCart(dish: dish)
        store.updateCartQuantity(dishID: "d1", delta: -1)

        #expect(store.cartItems.isEmpty)
    }

    @Test("按 itemID 可以删除购物车条目")
    func removeFromCartById() {
        let store = AppStore()
        let dish = makeDish(id: "d1", name: "test")

        store.addToCart(dish: dish)
        let cartItemID = try! #require(store.cartItems.first?.id)
        store.removeFromCart(itemID: cartItemID)

        #expect(store.cartItems.isEmpty)
    }

    @Test("clearCart 会清空全部购物车项目")
    func clearCartRemovesAll() {
        let store = AppStore()

        store.addToCart(dish: makeDish(id: "d1", name: "a"))
        store.addToCart(dish: makeDish(id: "d2", name: "b"))
        store.clearCart()

        #expect(store.cartItems.isEmpty)
        #expect(store.cartCount == 0)
    }

    @Test("没有当前 kitchen 时角色相关能力为空")
    func rolePropertiesDefaultToNilWithoutKitchen() {
        let store = AppStore()

        #expect(store.currentRole == nil)
        #expect(store.isOwner == false)
        #expect(store.isAdmin == false)
        #expect(store.canManageDishes == false)
        #expect(store.canManageOrders == false)
    }

    @Test("当前账号对应 owner member 时开放管理能力")
    func rolePropertiesReflectCurrentMember() {
        let store = AppStore()
        store.currentAccount = Account(id: "a1", userName: "owner", nickName: "店长", createdAt: "")
        store.members = [
            Member(id: "m1", kitchenId: "k1", accountId: "a1", role: .owner, nickName: "店长")
        ]

        #expect(store.currentMember?.accountId == "a1")
        #expect(store.currentRole == .owner)
        #expect(store.isOwner)
        #expect(store.canManageDishes)
        #expect(store.canManageOrders)
    }

    @Test("当前账号对应 admin member 时具备管理能力但不是 owner")
    func rolePropertiesReflectAdminMember() {
        let store = AppStore()
        store.currentAccount = Account(id: "a1", userName: "admin", nickName: "副管理员", createdAt: "")
        store.members = [
            Member(id: "m1", kitchenId: "k1", accountId: "a1", role: .admin, nickName: "副管理员")
        ]

        #expect(store.currentRole == .admin)
        #expect(store.isOwner == false)
        #expect(store.isAdmin)
        #expect(store.canManageDishes)
        #expect(store.canManageOrders)
    }

    @Test("activeDishes 过滤已归档菜品并生成去重排序后的分类")
    func activeDishesAndCategoriesExcludeArchived() {
        let store = AppStore()
        store.dishes = [
            makeDish(id: "d1", name: "鱼香肉丝", category: "热菜"),
            makeDish(id: "d2", name: "红糖糍粑", category: "甜品"),
            makeDish(id: "d3", name: "旧菜", category: "热菜", archivedAt: "2026-04-01")
        ]

        #expect(store.activeDishes.map(\.id) == ["d1", "d2"])
        #expect(store.dishCategories == ["热菜", "甜品"])
    }

    @Test("groupedOrderItems 按 dish 和 status 聚合并保留首次出现顺序")
    func groupedOrderItemsMergesSameDishAndStatus() {
        let store = AppStore()
        store.dishes = [
            makeDish(id: "d1", name: "宫保鸡丁", category: "热菜"),
            makeDish(id: "d2", name: "冬阴功汤", category: "汤")
        ]
        store.orderItems = [
            makeItem(id: "i1", dishId: "d1", quantity: 1, status: .waiting, createdAt: "1"),
            makeItem(id: "i2", dishId: "d1", quantity: 2, status: .waiting, createdAt: "2"),
            makeItem(id: "i3", dishId: "d1", quantity: 1, status: .cooking, createdAt: "3"),
            makeItem(id: "i4", dishId: "d2", quantity: 1, status: .done, createdAt: "4")
        ]

        let grouped = store.groupedOrderItems

        #expect(grouped.count == 3)
        #expect(grouped[0].dishName == "宫保鸡丁")
        #expect(grouped[0].status == .waiting)
        #expect(grouped[0].quantity == 3)
        #expect(grouped[0].itemIDs == ["i1", "i2"])
        #expect(grouped[1].status == .cooking)
        #expect(grouped[2].dishName == "冬阴功汤")
    }

    @Test("取消项不会进入 groupedOrderItems")
    func groupedOrderItemsSkipsCancelledItems() {
        let store = AppStore()
        store.orderItems = [
            makeItem(id: "i1", dishId: "missing", quantity: 1, status: .cancelled, createdAt: "1"),
            makeItem(id: "i2", dishId: "missing", quantity: 2, status: .waiting, createdAt: "2")
        ]

        #expect(store.groupedOrderItems.count == 1)
        #expect(store.groupedOrderItems.first?.dishName == "未知菜品")
    }

    @Test("订单数量统计按 quantity 汇总并忽略取消项")
    func orderQuantityCountsUseItemQuantity() {
        let store = AppStore()
        store.orderItems = [
            makeItem(id: "i1", dishId: "d1", quantity: 3, status: .waiting),
            makeItem(id: "i2", dishId: "d1", quantity: 1, status: .cooking),
            makeItem(id: "i3", dishId: "d2", quantity: 2, status: .done),
            makeItem(id: "i4", dishId: "d3", quantity: 5, status: .cancelled)
        ]

        #expect(store.totalOrderQuantity == 6)
        #expect(store.quantity(for: .waiting) == 3)
        #expect(store.quantity(for: .cooking) == 1)
        #expect(store.quantity(for: .done) == 2)
        #expect(store.quantity(for: .cancelled) == 5)
    }

    @Test("title(for:) 返回条目当前状态文案")
    func titleReturnsCurrentStatusTitle() {
        let store = AppStore()
        store.orderItems = [
            makeItem(id: "i1", dishId: "d1", quantity: 1, status: .cooking)
        ]

        #expect(store.title(for: "i1") == "制作中")
        #expect(store.title(for: "missing") == "待制作")
    }

    @Test("member 也允许编辑 waiting 明细")
    func memberCanEditWaitingOrderItems() {
        let store = AppStore()
        store.currentAccount = Account(id: "a1", userName: "member", nickName: "成员", createdAt: "")
        store.members = [
            Member(id: "m1", kitchenId: "k1", accountId: "a1", role: .member, nickName: "成员")
        ]

        #expect(store.canEditWaitingOrderItems)
        #expect(store.canManageOrders == false)
    }

    @Test("只有 owner 和 admin 可以结束当前订单")
    func onlyPrivilegedMembersCanFinishCurrentOrder() {
        let store = AppStore()
        store.currentOrder = Order(id: "o1", kitchenId: "k1", status: .open, createdByAccountId: "a1", createdAt: "", finishedAt: nil)
        store.orderItems = [
            makeItem(id: "i1", dishId: "d1", quantity: 1, status: .waiting)
        ]

        store.currentAccount = Account(id: "a1", userName: "member", nickName: "成员", createdAt: "")
        store.members = [
            Member(id: "m1", kitchenId: "k1", accountId: "a1", role: .member, nickName: "成员")
        ]
        #expect(store.canFinishCurrentOrder == false)

        store.members = [
            Member(id: "m1", kitchenId: "k1", accountId: "a1", role: .admin, nickName: "副管理员")
        ]
        #expect(store.canFinishCurrentOrder)
    }

    private func makeDish(
        id: String,
        name: String,
        category: String = "家常",
        archivedAt: String? = nil
    ) -> Dish {
        Dish(
            id: id,
            kitchenId: "k1",
            name: name,
            category: category,
            imageKey: nil,
            ingredientsJson: "[]",
            createdByAccountId: "a1",
            createdAt: "",
            updatedAt: "",
            archivedAt: archivedAt
        )
    }

    private func makeItem(
        id: String,
        dishId: String,
        quantity: Int,
        status: ItemStatus,
        createdAt: String = ""
    ) -> OrderItem {
        OrderItem(
            id: id,
            orderId: "o1",
            dishId: dishId,
            addedByAccountId: "a1",
            quantity: quantity,
            status: status,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}
