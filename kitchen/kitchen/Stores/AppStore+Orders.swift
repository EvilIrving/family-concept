import Foundation

// MARK: - AppStore: Orders Management Extension

extension AppStore {
    func refreshOrderItems() async {
        guard let kitchen else { return }
        ordersFeedback = nil
        do {
            let result = try await apiClient.fetchOpenOrder(kitchenID: kitchen.id, authToken: authToken)
            if let order = result {
                self.currentOrder = Order(
                    id: order.id,
                    kitchenId: order.kitchenId,
                    status: order.status,
                    createdByAccountId: order.createdByAccountId,
                    createdAt: order.createdAt,
                    finishedAt: order.finishedAt
                )
                self.orderItems = order.items ?? []
            } else {
                self.currentOrder = nil
                self.orderItems = []
            }
        } catch {
            ordersFeedback = feedback(for: error)
            consumeError(error)
        }
    }

    func cycleStatus(for itemID: String) async {
        guard let index = orderItems.firstIndex(where: { $0.id == itemID }) else { return }
        let item = orderItems[index]
        let next: ItemStatus
        switch item.status {
        case .waiting: next = .cooking
        case .cooking: next = .done
        case .done, .cancelled: return
        }

        do {
            let updated = try await apiClient.updateOrderItem(id: itemID, status: next, authToken: authToken)
            orderItems[index] = updated
        } catch {
            consumeError(error)
        }
    }

    func cycleStatuses(for itemIDs: [String]) async {
        for itemID in itemIDs {
            await cycleStatus(for: itemID)
        }
    }

    @discardableResult
    func reduceWaitingItemQuantity(for groupedItem: GroupedOrderItem) async -> Bool {
        guard groupedItem.status == .waiting else { return false }
        guard let target = orderItems
            .filter({ groupedItem.itemIDs.contains($0.id) && $0.status == .waiting })
            .sorted(by: { $0.createdAt > $1.createdAt })
            .first else { return false }

        do {
            let updated: OrderItem
            if target.quantity <= 1 {
                updated = try await apiClient.updateOrderItem(id: target.id, status: .cancelled, authToken: authToken)
            } else {
                updated = try await apiClient.updateOrderItem(id: target.id, quantity: target.quantity - 1, authToken: authToken)
            }
            applyOrderItemUpdate(updated)
            return true
        } catch {
            consumeError(error)
            return false
        }
    }

    @discardableResult
    func cancelWaitingItems(for groupedItem: GroupedOrderItem) async -> Bool {
        guard groupedItem.status == .waiting else { return false }
        do {
            for itemID in groupedItem.itemIDs {
                let updated = try await apiClient.updateOrderItem(id: itemID, status: .cancelled, authToken: authToken)
                applyOrderItemUpdate(updated)
            }
            return true
        } catch {
            consumeError(error)
            return false
        }
    }

    func title(for itemID: String) -> String {
        guard let item = orderItems.first(where: { $0.id == itemID }) else { return L10n.tr("待制作") }
        return item.status.title
    }

    @discardableResult
    func finishOrder() async -> Bool {
        guard let order = currentOrder else { return false }
        do {
            _ = try await apiClient.finishOrder(id: order.id, authToken: authToken)
            currentOrder = nil
            orderItems = []
            shoppingListItems = []
            orderHistory = []
            selectedOrderDetail = nil
            return true
        } catch {
            consumeError(error)
            return false
        }
    }

    func fetchOrderHistory() async {
        guard let kitchen else { return }
        isLoadingOrderHistory = true
        historyFeedback = nil
        defer { isLoadingOrderHistory = false }
        do {
            let fetchedHistory = try await apiClient.fetchOrderHistory(kitchenID: kitchen.id, authToken: authToken)
            orderHistory = fetchedHistory.filter { $0.status == .finished && $0.finishedAt != nil }
        } catch {
            historyFeedback = feedback(for: error)
            consumeError(error)
        }
    }

    @discardableResult
    func fetchOrderDetail(orderID: String) async -> OrderDetail? {
        do {
            let detail = try await apiClient.fetchOrderDetail(orderID: orderID, authToken: authToken)
            selectedOrderDetail = detail
            return detail
        } catch {
            consumeError(error)
            return nil
        }
    }

    func fetchShoppingList() {
        guard currentOrder != nil else {
            shoppingListItems = []
            return
        }
        let activeItems = orderItems.filter { $0.status != .cancelled }
        var ingredientDishes: [String: Set<String>] = [:]
        var ingredientDishNames: [String: Set<String>] = [:]
        for item in activeItems {
            guard let dish = dishes.first(where: { $0.id == item.dishId }) else { continue }
            for ingredient in dish.ingredients {
                ingredientDishes[ingredient, default: []].insert(dish.id)
                ingredientDishNames[ingredient, default: []].insert(dish.name)
            }
        }
        shoppingListItems = ingredientDishes
            .map { ingredient, dishIDs in
                ShoppingListItem(
                    ingredient: ingredient,
                    dishCount: dishIDs.count,
                    dishNames: ingredientDishNames[ingredient, default: []].sorted()
                )
            }
            .sorted { $0.ingredient < $1.ingredient }
    }
}
