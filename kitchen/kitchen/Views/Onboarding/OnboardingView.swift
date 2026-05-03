import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore

    // 状态
    @State private var authMode: AuthMode = .login
    @State private var kitchenMode: KitchenMode = .join

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

                authSection

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

            KitchenForm(
                kitchenInput: $kitchenInput,
                kitchenMode: $kitchenMode,
                kitchenInputInvalid: $kitchenInputInvalid,
                kitchenInputShake: $kitchenInputShake,
                focusedField: $focusedField,
                onSubmit: submit
            )

            authModeLink
        }
    }

    // MARK: - Helpers

    private var authModeLink: some View {
        HStack {
            Spacer()
            AppLinkButton(title: authMode == .login ? L10n.tr("还没有账号？注册") : L10n.tr("已有账号？登录"), role: .secondary) {
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
            .init(value: .join, title: L10n.tr("邀请码"), accessibilityLabel: L10n.tr("输入邀请码加入")),
            .init(value: .create, title: L10n.tr("创建私厨"), accessibilityLabel: L10n.tr("创建私厨"))
        ]
    }

    private var kitchenModeSelection: Binding<KitchenMode> {
        Binding(
            get: { kitchenMode },
            set: { mode in
                withAnimation(.easeInOut(duration: 0.2)) {
                    kitchenMode = mode
                    kitchenInput = ""
                    kitchenInputInvalid = false
                    focusedField = .kitchen
                }
            }
        )
    }

    private var hintText: String {
        switch authMode {
        case .login: return kitchenMode == .join ? L10n.tr("登录并加入私厨") : L10n.tr("登录并创建私厨")
        case .register: return L10n.tr("创建新账号")
        }
    }

    private var buttonTitle: String {
        return authMode == .login ? L10n.tr("登录") : L10n.tr("注册")
    }

    private func submit() {
        focusedField = nil
        store.error = nil

        if authMode == .login {
            submitLogin()
        } else {
            submitRegister()
        }
    }

    private func submitLogin() {
        guard OnboardingValidationHelper.validateUserName(userName, shake: &userNameShake, invalid: &userNameInvalid),
              OnboardingValidationHelper.validatePassword(password, shake: &passwordShake, invalid: &passwordInvalid)
        else { return }

        if !kitchenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !OnboardingValidationHelper.validateKitchenInput(kitchenInput, shake: &kitchenInputShake, invalid: &kitchenInputInvalid) {
            return
        }

        let code = kitchenMode == .join ? kitchenInput : ""
        let name = kitchenMode == .create ? kitchenInput : ""

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
              OnboardingValidationHelper.validateNickName(nickName, shake: &nickNameShake, invalid: &nickNameInvalid),
              OnboardingValidationHelper.validateKitchenInput(kitchenInput, shake: &kitchenInputShake, invalid: &kitchenInputInvalid)
        else { return }

        let code = kitchenMode == .join ? kitchenInput : ""
        let name = kitchenMode == .create ? kitchenInput : ""

        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            await store.register(userName: userName.trimmingCharacters(in: .whitespacesAndNewlines),
                                password: password.trimmingCharacters(in: .whitespacesAndNewlines),
                                nickName: nickName.trimmingCharacters(in: .whitespacesAndNewlines),
                                inviteCode: code, kitchenName: name)
        }
    }

}

#Preview {
    OnboardingView()
        .environmentObject(AppStore())
}
