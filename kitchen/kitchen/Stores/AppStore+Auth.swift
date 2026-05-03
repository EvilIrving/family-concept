import Foundation

// MARK: - AppStore: Authentication Extensions

extension AppStore {
    // MARK: - Auth & Onboarding

    func login(userName: String, password: String, inviteCode: String = "", kitchenName: String = "") async {
        error = nil
        do {
            let response = try await apiClient.login(userName: userName, password: password)
            persistAuth(response.token, account: response.account)

            if let kitchen = response.kitchen {
                self.kitchen = kitchen
                UserDefaults.standard.set(kitchen.id, forKey: "lastKitchenID")
                return
            }

            if let lastKitchenID = UserDefaults.standard.string(forKey: "lastKitchenID"),
               let k = try? await apiClient.fetchKitchen(id: lastKitchenID, authToken: authToken) {
                kitchen = k
                return
            }

            if inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               kitchenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                error = L10n.tr("这个账号还没有加入私厨，请输入邀请码或创建私厨")
            } else {
                await completeOnboarding(inviteCode: inviteCode, kitchenName: kitchenName)
            }
        } catch {
            consumeError(error)
        }
    }

    func register(userName: String, password: String, nickName: String, inviteCode: String = "", kitchenName: String = "") async {
        error = nil
        do {
            let response = try await apiClient.register(userName: userName, password: password, nickName: nickName)
            persistAuth(response.token, account: response.account)
            await completeOnboarding(inviteCode: inviteCode, kitchenName: kitchenName)
        } catch {
            consumeError(error)
        }
    }

    func joinKitchen(inviteCode: String) async {
        error = nil
        await completeOnboarding(inviteCode: inviteCode, kitchenName: "")
    }

    func createKitchen(named name: String) async {
        error = nil
        await completeOnboarding(inviteCode: "", kitchenName: name)
    }

    func signOut() async {
        if !authToken.isEmpty {
            _ = try? await apiClient.logout(authToken: authToken)
        }
        clearSession()
    }

    // MARK: - Private Helpers

    private func completeOnboarding(inviteCode: String, kitchenName: String) async {
        let trimmedCode = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = kitchenName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedCode.isEmpty || !trimmedName.isEmpty else { return }
        let mode = trimmedCode.isEmpty ? "create" : "join"

        do {
            let result = try await apiClient.onboardingComplete(
                mode: mode,
                authToken: authToken,
                inviteCode: trimmedCode.isEmpty ? nil : trimmedCode,
                kitchenName: trimmedName.isEmpty ? nil : trimmedName
            )
            kitchen = result.kitchen
            members = [result.member]
            UserDefaults.standard.set(result.kitchen.id, forKey: "lastKitchenID")
        } catch {
            consumeError(error)
        }
    }

    private func persistAuth(_ token: String, account: Account) {
        authToken = token
        currentAccount = account
        storedNickName = account.nickName
        UserDefaults.standard.set(token, forKey: "authToken")
        UserDefaults.standard.set(account.id, forKey: "accountID")
        UserDefaults.standard.set(account.nickName, forKey: "nickName")
    }

    func clearSession() {
        authToken = ""
        currentAccount = nil
        clearKitchenState()
        UserDefaults.standard.removeObject(forKey: "authToken")
        UserDefaults.standard.removeObject(forKey: "accountID")
        UserDefaults.standard.removeObject(forKey: "nickName")
    }
}
