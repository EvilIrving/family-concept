import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore

    // 状态
    @State private var authMode: AuthMode = .login
    @State private var kitchenMode: KitchenMode = .join
    @State private var showKitchenField = false

    // 表单字段
    @State private var userName = ""
    @State private var password = ""
    @State private var nickName = ""
    @State private var kitchenInput = ""

    // 校验状态
    @State private var userNameInvalid = false
    @State private var passwordInvalid = false
    @State private var nickNameInvalid = false
    @State private var kitchenInputInvalid = false

    // Shake 计数
    @State private var userNameShake = 0
    @State private var passwordShake = 0
    @State private var nickNameShake = 0
    @State private var kitchenInputShake = 0

    @State private var isSubmitting = false
    @FocusState private var focusedField: OnboardingField?

    var body: some View {
        ScrollView {
            formCard
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xxl)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            OnboardingSubmitBar(
                isSubmitting: $isSubmitting,
                buttonTitle: buttonTitle,
                onSubmit: submit
            )
        }
        .appPageBackground()
    }

    private var formCard: some View {
        AppCard(padding: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(hintText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.textSecondary)

                if store.isAuthenticated {
                    kitchenSection
                } else {
                    authSection
                }

                if let error = store.error {
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppSemanticColor.danger)
                }
            }
        }
    }

    // MARK: - Auth Section

    private var authSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            AuthForm(
                userName: $userName,
                password: $password,
                nickName: $nickName,
                isRegisterMode: authMode == .register,
                userNameInvalid: $userNameInvalid,
                passwordInvalid: $passwordInvalid,
                nickNameInvalid: $nickNameInvalid,
                userNameShake: $userNameShake,
                passwordShake: $passwordShake,
                nickNameShake: $nickNameShake,
                focusedField: $focusedField,
                onSubmitLogin: submitLogin,
                onSubmitRegister: submitRegister
            )

            AppSegmentedButton(
                segments: kitchenSegments,
                selection: kitchenModeSelection
            )

            if showKitchenField {
                KitchenForm(
                    kitchenInput: $kitchenInput,
                    kitchenMode: $kitchenMode,
                    kitchenInputInvalid: $kitchenInputInvalid,
                    kitchenInputShake: $kitchenInputShake,
                    focusedField: $focusedField,
                    onSubmit: submit
                )
            }

            authModeLink
        }
    }

    // MARK: - Kitchen Section (logged in, no kitchen)

    private var kitchenSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            AppSegmentedButton(
                segments: kitchenSegments,
                selection: loggedInKitchenSelection
            )

            KitchenForm(
                kitchenInput: $kitchenInput,
                kitchenMode: $kitchenMode,
                kitchenInputInvalid: $kitchenInputInvalid,
                kitchenInputShake: $kitchenInputShake,
                focusedField: $focusedField,
                onSubmit: submitKitchen
            )

            AppLinkButton(title: "退出登录", role: .secondary) {
                Task { await store.signOut() }
            }
        }
    }

    // MARK: - Helpers

    private var authModeLink: some View {
        HStack {
            Spacer()
            AppLinkButton(title: authMode == .login ? "还没有账号？注册" : "已有账号？登录", role: .secondary) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    authMode = authMode == .login ? .register : .login
                    store.error = nil
                    userNameInvalid = false
                    passwordInvalid = false
                    nickNameInvalid = false
                }
            }
        }
    }

    private var kitchenSegments: [AppSegmentedButton<KitchenMode>.Segment] {
        [
            .init(value: .join, title: "输入邀请码加入", accessibilityLabel: "输入邀请码加入"),
            .init(value: .create, title: "创建私厨", accessibilityLabel: "创建私厨")
        ]
    }

    private var kitchenModeSelection: Binding<KitchenMode> {
        Binding(
            get: { showKitchenField ? kitchenMode : .join },
            set: { mode in
                withAnimation(.easeInOut(duration: 0.2)) {
                    kitchenMode = mode
                    showKitchenField = true
                    focusedField = .kitchen
                }
            }
        )
    }

    private var loggedInKitchenSelection: Binding<KitchenMode> {
        Binding(
            get: { kitchenMode },
            set: { mode in
                withAnimation(.easeInOut(duration: 0.2)) {
                    kitchenMode = mode
                    kitchenInput = ""
                    kitchenInputInvalid = false
                }
                focusedField = .kitchen
            }
        )
    }

    private var hintText: String {
        if store.isAuthenticated {
            return kitchenMode == .join ? "输入邀请码加入已有私厨" : "给你的私厨起个名字"
        }
        switch authMode {
        case .login: return ""
        case .register: return "创建新账号"
        }
    }

    private var buttonTitle: String {
        if store.isAuthenticated {
            return kitchenMode == .join ? "加入" : "创建并进入"
        }
        return authMode == .login ? "登录" : "注册"
    }

    private func submit() {
        focusedField = nil
        store.error = nil

        if store.isAuthenticated {
            submitKitchen()
        } else if authMode == .login {
            submitLogin()
        } else {
            submitRegister()
        }
    }

    private func submitLogin() {
        guard OnboardingValidationHelper.validateUserName(userName, shake: &userNameShake, invalid: &userNameInvalid),
              OnboardingValidationHelper.validatePassword(password, shake: &passwordShake, invalid: &passwordInvalid)
        else { return }

        let code = showKitchenField && kitchenMode == .join ? kitchenInput : ""
        let name = showKitchenField && kitchenMode == .create ? kitchenInput : ""

        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            await store.login(userName: userName.trimmingCharacters(in: .whitespacesAndNewlines),
                             password: password.trimmingCharacters(in: .whitespacesAndNewlines),
                             inviteCode: code, kitchenName: name)
        }
    }

    private func submitRegister() {
        guard OnboardingValidationHelper.validateUserName(userName, shake: &userNameShake, invalid: &userNameInvalid),
              OnboardingValidationHelper.validatePassword(password, shake: &passwordShake, invalid: &passwordInvalid),
              OnboardingValidationHelper.validateNickName(nickName, shake: &nickNameShake, invalid: &nickNameInvalid)
        else { return }

        let code = showKitchenField && kitchenMode == .join ? kitchenInput : ""
        let name = showKitchenField && kitchenMode == .create ? kitchenInput : ""

        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            await store.register(userName: userName.trimmingCharacters(in: .whitespacesAndNewlines),
                                password: password.trimmingCharacters(in: .whitespacesAndNewlines),
                                nickName: nickName.trimmingCharacters(in: .whitespacesAndNewlines),
                                inviteCode: code, kitchenName: name)
        }
    }

    private func submitKitchen() {
        guard OnboardingValidationHelper.validateKitchenInput(kitchenInput, shake: &kitchenInputShake, invalid: &kitchenInputInvalid) else { return }

        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            if kitchenMode == .join {
                await store.joinKitchen(inviteCode: kitchenInput.trimmingCharacters(in: .whitespacesAndNewlines))
            } else {
                await store.createKitchen(named: kitchenInput.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppStore())
}
