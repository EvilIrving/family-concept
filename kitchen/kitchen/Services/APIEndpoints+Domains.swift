import Foundation

// MARK: - Auth Endpoints

extension APIEndpoints {
    enum Auth {
        static func register(userName: String, password: String, nickName: String) -> Endpoint<AuthResponse> {
            Endpoint(
                path: "/api/v1/auth/register",
                method: "POST",
                body: ["user_name": userName, "password": password, "nick_name": nickName]
            )
        }

        static func login(userName: String, password: String) -> Endpoint<AuthResponse> {
            Endpoint(
                path: "/api/v1/auth/login",
                method: "POST",
                body: ["user_name": userName, "password": password]
            )
        }

        static func logout() -> Endpoint<OKResult> {
            Endpoint(path: "/api/v1/auth/logout", method: "POST", requiresAuth: true)
        }

        static func fetchMe() -> Endpoint<AuthMeResponse> {
            Endpoint(path: "/api/v1/auth/me", requiresAuth: true)
        }
    }
}

// MARK: - Onboarding Endpoints

extension APIEndpoints {
    enum Onboarding {
        static func complete(
            mode: String,
            nickName: String? = nil,
            inviteCode: String? = nil,
            kitchenName: String? = nil
        ) -> Endpoint<APIClient.OnboardingResponse> {
            var body: [String: String] = ["mode": mode]
            if let nickName { body["nick_name"] = nickName }
            if let inviteCode { body["invite_code"] = inviteCode }
            if let kitchenName { body["kitchen_name"] = kitchenName }

            return Endpoint(
                path: "/api/v1/onboarding/complete",
                method: "POST",
                body: body,
                requiresAuth: true
            )
        }
    }
}

// MARK: - Kitchens Endpoints

extension APIEndpoints {
    enum Kitchens {
        static func fetch(id: String) -> Endpoint<Kitchen> {
            Endpoint(path: "/api/v1/kitchens/\(id)", requiresAuth: true)
        }

        static func update(id: String, name: String) -> Endpoint<Kitchen> {
            Endpoint(
                path: "/api/v1/kitchens/\(id)",
                method: "PATCH",
                body: ["name": name],
                requiresAuth: true
            )
        }

        static func rotateInviteCode(kitchenID: String) -> Endpoint<APIClient.InviteCodeResult> {
            Endpoint(
                path: "/api/v1/kitchens/\(kitchenID)/rotate_invite",
                method: "POST",
                requiresAuth: true
            )
        }
    }
}

// MARK: - Members Endpoints

extension APIEndpoints {
    enum Members {
        static func fetch(kitchenID: String) -> Endpoint<[Member]> {
            Endpoint(path: "/api/v1/kitchens/\(kitchenID)/members", requiresAuth: true)
        }

        static func remove(kitchenID: String, accountID: String) -> Endpoint<OKResult> {
            Endpoint(
                path: "/api/v1/kitchens/\(kitchenID)/members/\(accountID)",
                method: "DELETE",
                requiresAuth: true
            )
        }

        static func leave(kitchenID: String) -> Endpoint<OKResult> {
            Endpoint(
                path: "/api/v1/kitchens/\(kitchenID)/leave",
                method: "POST",
                requiresAuth: true
            )
        }
    }
}
