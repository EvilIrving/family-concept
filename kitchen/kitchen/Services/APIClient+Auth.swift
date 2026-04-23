import Foundation

// MARK: - APIClient Extensions: Auth & Onboarding

extension APIClient {
    func register(userName: String, password: String, nickName: String) async throws -> AuthResponse {
        try await request(APIEndpoints.Auth.register(userName: userName, password: password, nickName: nickName))
    }

    func login(userName: String, password: String) async throws -> AuthResponse {
        try await request(APIEndpoints.Auth.login(userName: userName, password: password))
    }

    func logout(authToken: String) async throws -> OKResult {
        try await request(APIEndpoints.Auth.logout(), authToken: authToken)
    }

    func fetchMe(authToken: String) async throws -> AuthMeResponse {
        try await request(APIEndpoints.Auth.fetchMe(), authToken: authToken)
    }

    // MARK: - Onboarding

    struct OnboardingResponse: Decodable {
        let account: Account
        let kitchen: Kitchen
        let member: Member
    }

    func onboardingComplete(
        mode: String,
        authToken: String,
        nickName: String? = nil,
        inviteCode: String? = nil,
        kitchenName: String? = nil
    ) async throws -> OnboardingResponse {
        try await request(
            APIEndpoints.Onboarding.complete(
                mode: mode,
                nickName: nickName,
                inviteCode: inviteCode,
                kitchenName: kitchenName
            ),
            authToken: authToken
        )
    }

    // MARK: - Kitchens

    struct InviteCodeResult: Decodable {
        let inviteCode: String
    }

    func fetchKitchen(id: String, authToken: String) async throws -> Kitchen {
        try await request(APIEndpoints.Kitchens.fetch(id: id), authToken: authToken)
    }

    func updateKitchen(id: String, name: String, authToken: String) async throws -> Kitchen {
        try await request(APIEndpoints.Kitchens.update(id: id, name: name), authToken: authToken)
    }

    func rotateInviteCode(kitchenID: String, authToken: String) async throws -> InviteCodeResult {
        try await request(APIEndpoints.Kitchens.rotateInviteCode(kitchenID: kitchenID), authToken: authToken)
    }

    // MARK: - Members

    func fetchMembers(kitchenID: String, authToken: String) async throws -> [Member] {
        try await request(APIEndpoints.Members.fetch(kitchenID: kitchenID), authToken: authToken)
    }

    func removeMember(kitchenID: String, accountID: String, authToken: String) async throws -> OKResult {
        try await request(
            APIEndpoints.Members.remove(kitchenID: kitchenID, accountID: accountID),
            authToken: authToken
        )
    }

    func updateMemberRole(
        kitchenID: String,
        accountID: String,
        role: KitchenRole,
        authToken: String
    ) async throws -> Member {
        try await request(
            APIEndpoints.Members.updateRole(kitchenID: kitchenID, accountID: accountID, role: role),
            authToken: authToken
        )
    }

    func leaveKitchen(kitchenID: String, authToken: String) async throws -> OKResult {
        try await request(APIEndpoints.Members.leave(kitchenID: kitchenID), authToken: authToken)
    }
}
