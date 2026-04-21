import Foundation

// MARK: - AppStore: Cart Management Extension

extension AppStore {
    func addToCart(dish: Dish) {
        if let index = cartItems.firstIndex(where: { $0.dishID == dish.id }) {
            cartItems[index].quantity += 1
        } else {
            cartItems.insert(
                CartItem(id: UUID().uuidString, dishID: dish.id, dishName: dish.name, quantity: 1),
                at: 0
            )
        }
    }

    func updateCartQuantity(dishID: String, delta: Int) {
        guard let item = cartItems.first(where: { $0.dishID == dishID }) else {
            if delta > 0, let dish = activeDishes.first(where: { $0.id == dishID }) {
                addToCart(dish: dish)
            }
            return
        }
        updateCartQuantity(itemID: item.id, delta: delta)
    }

    func updateCartQuantity(itemID: String, delta: Int) {
        guard let index = cartItems.firstIndex(where: { $0.id == itemID }) else { return }
        let newQty = cartItems[index].quantity + delta
        if newQty <= 0 {
            cartItems.remove(at: index)
        } else {
            cartItems[index].quantity = newQty
        }
    }

    func removeFromCart(itemID: String) {
        cartItems.removeAll { $0.id == itemID }
    }

    func clearCart() {
        cartItems.removeAll()
    }

    func submitCart() async {
        guard !cartItems.isEmpty, !isSubmittingCart else { return }
        error = nil
        isSubmittingCart = true
        defer { isSubmittingCart = false }

        do {
            if currentOrder == nil {
                let order = try await apiClient.createOrder(kitchenID: kitchen!.id, authToken: authToken)
                currentOrder = order
            }

            let orderID = currentOrder!.id

            for item in cartItems {
                _ = try await apiClient.addOrderItem(
                    orderID: orderID,
                    dishID: item.dishID,
                    quantity: item.quantity,
                    authToken: authToken
                )
            }

            cartItems.removeAll()
            await refreshOrderItems()
        } catch {
            consumeError(error)
        }
    }
}
