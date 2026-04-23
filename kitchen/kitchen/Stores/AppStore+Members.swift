import Foundation

// MARK: - AppStore: Members Extension

extension AppStore {
    func refreshMembers() async {
        guard let kitchen else { return }
        error = nil
        do {
            members = try await apiClient.fetchMembers(kitchenID: kitchen.id, authToken: authToken)
        } catch {
            consumeError(error)
        }
    }

    @discardableResult
    func removeMember(accountID: String) async -> Bool {
        guard let kitchen else { return false }
        error = nil
        do {
            _ = try await apiClient.removeMember(kitchenID: kitchen.id, accountID: accountID, authToken: authToken)
            members.removeAll { $0.accountId == accountID }
            return true
        } catch {
            consumeError(error)
            return false
        }
    }

    @discardableResult
    func updateMemberRole(accountID: String, role: KitchenRole) async -> Bool {
        guard let kitchen else { return false }
        error = nil
        do {
            let updatedMember = try await apiClient.updateMemberRole(
                kitchenID: kitchen.id,
                accountID: accountID,
                role: role,
                authToken: authToken
            )
            guard let index = members.firstIndex(where: { $0.accountId == accountID }) else { return false }
            members[index] = updatedMember
            return true
        } catch {
            consumeError(error)
            return false
        }
    }
}
