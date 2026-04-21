import Foundation

// MARK: - AppStore: Kitchen Management Extension

extension AppStore {
    func updateKitchenName(_ name: String) async {
        guard let kitchen else { return }
        do {
            let updated = try await apiClient.updateKitchen(id: kitchen.id, name: name, authToken: authToken)
            self.kitchen = updated
        } catch {
            consumeError(error)
        }
    }

    func rotateInviteCode() async {
        guard let kitchen else { return }
        do {
            let result = try await apiClient.rotateInviteCode(kitchenID: kitchen.id, authToken: authToken)
            self.kitchen = Kitchen(
                id: kitchen.id,
                name: kitchen.name,
                ownerAccountId: kitchen.ownerAccountId,
                inviteCode: result.inviteCode,
                inviteCodeRotatedAt: kitchen.inviteCodeRotatedAt,
                createdAt: kitchen.createdAt
            )
        } catch {
            consumeError(error)
        }
    }

    func leaveKitchen() async {
        guard let kitchen else { return }
        do {
            _ = try await apiClient.leaveKitchen(kitchenID: kitchen.id, authToken: authToken)
            clearKitchenState()
        } catch {
            consumeError(error)
        }
    }
}
