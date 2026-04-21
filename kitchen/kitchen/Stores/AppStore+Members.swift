import Foundation

// MARK: - AppStore: Members Extension

extension AppStore {
    func refreshMembers() async {
        guard let kitchen else { return }
        do {
            members = try await apiClient.fetchMembers(kitchenID: kitchen.id, authToken: authToken)
        } catch {
            consumeError(error)
        }
    }

    func removeMember(accountID: String) async {
        guard let kitchen else { return }
        do {
            _ = try await apiClient.removeMember(kitchenID: kitchen.id, accountID: accountID, authToken: authToken)
            members.removeAll { $0.accountId == accountID }
        } catch {
            consumeError(error)
        }
    }
}
