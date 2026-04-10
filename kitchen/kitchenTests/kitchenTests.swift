//
//  kitchenTests.swift
//  kitchenTests
//
//  Created by Cain on 2026/4/9.
//

import Testing
@testable import kitchen

struct kitchenTests {

    @Test func addDishTrimsInputAndSplitsIngredients() async throws {
        let store = AppStore()

        store.addDish(name: "  蒜蓉西兰花 ", category: " 家常菜 ", ingredientsText: "西兰花、 蒜、盐")

        #expect(store.activeDishes.first?.name == "蒜蓉西兰花")
        #expect(store.activeDishes.first?.category == "家常菜")
        #expect(store.activeDishes.first?.ingredients == ["西兰花", "蒜", "盐"])
    }

    @Test func addToOrderAggregatesExistingDishQuantity() async throws {
        let store = AppStore()
        let dish = try #require(store.activeDishes.first)
        let originalCount = store.orderItems.count

        store.addToOrder(dish: dish)

        #expect(store.orderItems.count == originalCount)
        #expect(store.orderItems.first(where: { $0.dishID == dish.id })?.quantity == 3)
    }

    @Test func cycleStatusLoopsWaitingCookingDone() async throws {
        let store = AppStore()
        let itemID = try #require(store.orderItems.first?.id)

        store.cycleStatus(for: itemID)
        #expect(store.title(for: itemID) == "制作中")

        store.cycleStatus(for: itemID)
        #expect(store.title(for: itemID) == "已完成")

        store.cycleStatus(for: itemID)
        #expect(store.title(for: itemID) == "待制作")
    }

    @Test func submitCartAggregatesIntoExistingOrderItem() async throws {
        let store = AppStore()
        let dish = try #require(store.activeDishes.first)

        store.addToCart(dish: dish)
        store.submitCart()

        #expect(store.cartItems.isEmpty)
        #expect(store.orderItems.first(where: { $0.dishID == dish.id })?.quantity == 3)
    }

    @Test func dishCategoriesReturnsSortedDistinctValues() async throws {
        let store = AppStore()

        #expect(store.dishCategories == ["家常菜", "快手菜", "饮品"])
    }

    @Test func createKitchenSetsDisplayNameAndOwnerRole() async throws {
        let store = AppStore()
        store.createKitchen(named: "测试厨房", displayName: "小厨")

        let member = try #require(store.currentMember)
        #expect(member.displayName == "小厨")
        #expect(member.role == .owner)
        #expect(store.kitchen?.name == "测试厨房")
    }

    @Test func joinKitchenSetsDisplayNameAndMemberRole() async throws {
        let store = AppStore()
        store.joinKitchen(inviteCode: "ABC123", displayName: "小明")

        let member = try #require(store.currentMember)
        #expect(member.displayName == "小明")
        #expect(member.role == .member)
    }

    @Test func addDishBlockedForMemberRole() async throws {
        let store = AppStore()
        store.joinKitchen(inviteCode: "XYZ", displayName: "访客")
        let countBefore = store.activeDishes.count

        store.addDish(name: "新菜", category: "家常菜", ingredients: [])

        #expect(store.activeDishes.count == countBefore)
    }

    @Test func isOwnerReturnsTrueForOwnerFalseForMember() async throws {
        let store = AppStore()

        store.createKitchen(named: "厨房", displayName: "老板")
        #expect(store.isOwner == true)

        store.joinKitchen(inviteCode: "XYZ", displayName: "访客")
        #expect(store.isOwner == false)
    }

}
