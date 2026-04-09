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

}
