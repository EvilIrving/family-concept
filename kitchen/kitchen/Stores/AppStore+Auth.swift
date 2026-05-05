import Foundation

// MARK: - AppStore: Authentication Extensions

extension AppStore {
    // MARK: - Auth & Onboarding

    func login(userName: String, password: String, inviteCode: String = "", kitchenName: String = "") async {
        error = nil
        #if DEBUG
        print("🔐 [login] tap → userName=\(userName) inviteCode=\(inviteCode.isEmpty ? "-" : inviteCode) kitchenName=\(kitchenName.isEmpty ? "-" : kitchenName)")
        #endif
        do {
            let response = try await apiClient.login(userName: userName, password: password)
            #if DEBUG
            print("🔐 [login] success → accountID=\(response.account.id) nick=\(response.account.nickName) tokenPrefix=\(response.token.prefix(8))… kitchen=\(response.kitchen?.id ?? "nil")")
            #endif
            persistAuth(response.token, account: response.account)

            if let kitchen = response.kitchen {
                self.kitchen = kitchen
                UserDefaults.standard.set(kitchen.id, forKey: "lastKitchenID")
                return
            }

            if inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               kitchenName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                #if DEBUG
                print("🔐 [login] account has no kitchen and no invite/create input → prompt user")
                #endif
                error = L10n.tr("This account hasn't joined a kitchen yet. Enter an invite code or create one.")
            } else {
                await completeOnboarding(inviteCode: inviteCode, kitchenName: kitchenName)
            }
        } catch {
            #if DEBUG
            print("🔐 [login] failure → \(error)")
            #endif
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
