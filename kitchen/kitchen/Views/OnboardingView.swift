import SwiftUI

private enum AuthMode { case login, register }
private enum KitchenMode { case join, create }

private enum OnboardingField: Hashable {
    case userName, password, nickName, kitchen
}

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var authMode: AuthMode = .login
    @State private var kitchenMode: KitchenMode = .join
    @State private var showKitchenField = false

    @State private var userName = ""
    @State private var password = ""
    @State private var nickName = ""
    @State private var kitchenInput = ""

    @State private var userNameInvalid = false
    @State private var passwordInvalid = false
    @State private var nickNameInvalid = false
    @State private var kitchenInputInvalid = false

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
            bottomBar
        }
        .appPageBackground()
    }

    private var formCard: some View {
        AppCard(padding: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(hintText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)

                if store.isAuthenticated {
                    kitchenSection
                } else {
                    authSection
                }

                if let error = store.error {
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.danger)
                }
            }
        }
    }

    // MARK: - Auth Section (not logged in)

    private var authSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            AppTextField(
                title: "用户名",
                text: $userName,
                focusedField: $focusedField,
                field: .userName,
                autocapitalization: .never,
                submitLabel: .next,
                onSubmit: { focusedField = .password },
                isInvalid: userNameInvalid,
                validationTrigger: userNameShake
            )
            .onChange(of: userName) { _, _ in
                if userNameInvalid { withAnimation(.easeInOut(duration: 0.16)) { userNameInvalid = false } }
            }

            AppTextField(
                title: "密码",
                text: $password,
                focusedField: $focusedField,
                field: .password,
                isSecure: true,
                autocapitalization: .never,
                submitLabel: authMode == .register ? .next : (showKitchenField ? .next : .done),
                onSubmit: {
                    if authMode == .register {
                        focusedField = .nickName
                    } else if showKitchenField {
                        focusedField = .kitchen
                    } else {
                        focusedField = nil
                        submit()
                    }
                },
                isInvalid: passwordInvalid,
                validationTrigger: passwordShake
            )
            .onChange(of: password) { _, _ in
                if passwordInvalid { withAnimation(.easeInOut(duration: 0.16)) { passwordInvalid = false } }
            }

            if authMode == .register {
                AppTextField(
                    title: "昵称",
                    text: $nickName,
                    focusedField: $focusedField,
                    field: .nickName,
                    autocapitalization: .words,
                    submitLabel: showKitchenField ? .next : .done,
                    onSubmit: {
                        if showKitchenField {
                            focusedField = .kitchen
                        } else {
                            focusedField = nil
                            submit()
                        }
                    },
                    isInvalid: nickNameInvalid,
                    validationTrigger: nickNameShake
                )
                .onChange(of: nickName) { _, _ in
                    if nickNameInvalid { withAnimation(.easeInOut(duration: 0.16)) { nickNameInvalid = false } }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            kitchenModeToggle

            if showKitchenField {
                AppTextField(
                    title: kitchenMode == .join ? "邀请码" : "私厨名称",
                    text: $kitchenInput,
                    focusedField: $focusedField,
                    field: .kitchen,
                    autocapitalization: kitchenMode == .join ? .characters : .words,
                    submitLabel: .done,
                    onSubmit: {
                        focusedField = nil
                        submit()
                    },
                    isInvalid: kitchenInputInvalid,
                    validationTrigger: kitchenInputShake
                )
                .onChange(of: kitchenInput) { _, _ in
                    if kitchenInputInvalid { withAnimation(.easeInOut(duration: 0.16)) { kitchenInputInvalid = false } }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            authModeLink
        }
    }

    private var kitchenModeToggle: some View {
        HStack(spacing: AppSpacing.md) {
            Button("输入邀请码加入") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    kitchenMode = .join
                    showKitchenField = true
                    kitchenInput = ""
                    kitchenInputInvalid = false
                }
                focusedField = .kitchen
            }
            .font(AppTypography.caption)
            .foregroundStyle(
                showKitchenField && kitchenMode == .join ? AppColor.textPrimary : AppColor.textSecondary
            )

            Text("或")
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)

            Button("创建私厨") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    kitchenMode = .create
                    showKitchenField = true
                    kitchenInput = ""
                    kitchenInputInvalid = false
                }
                focusedField = .kitchen
            }
            .font(AppTypography.caption)
            .foregroundStyle(
                showKitchenField && kitchenMode == .create ? AppColor.textPrimary : AppColor.textSecondary
            )
        }
    }

    private var authModeLink: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                authMode = authMode == .login ? .register : .login
                store.error = nil
                userNameInvalid = false
                passwordInvalid = false
                nickNameInvalid = false
            }
        } label: {
            Text(authMode == .login ? "还没有账号？注册" : "已有账号？登录")
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textTertiary)
        }
    }

    // MARK: - Kitchen Section (logged in, no kitchen)

    private var kitchenSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                Button("输入邀请码加入") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        kitchenMode = .join
                        kitchenInput = ""
                        kitchenInputInvalid = false
                    }
                    focusedField = .kitchen
                }
                .font(AppTypography.caption)
                .foregroundStyle(kitchenMode == .join ? AppColor.textPrimary : AppColor.textSecondary)

                Text("或")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)

                Button("创建私厨") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        kitchenMode = .create
                        kitchenInput = ""
                        kitchenInputInvalid = false
                    }
                    focusedField = .kitchen
                }
                .font(AppTypography.caption)
                .foregroundStyle(kitchenMode == .create ? AppColor.textPrimary : AppColor.textSecondary)
            }

            AppTextField(
                title: kitchenMode == .join ? "邀请码" : "私厨名称",
                text: $kitchenInput,
                focusedField: $focusedField,
                field: .kitchen,
                autocapitalization: kitchenMode == .join ? .characters : .words,
                submitLabel: .done,
                onSubmit: {
                    focusedField = nil
                    submit()
                },
                isInvalid: kitchenInputInvalid,
                validationTrigger: kitchenInputShake
            )
            .onChange(of: kitchenInput) { _, _ in
                if kitchenInputInvalid { withAnimation(.easeInOut(duration: 0.16)) { kitchenInputInvalid = false } }
            }

            Button {
                Task { await store.signOut() }
            } label: {
                Text("退出登录")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textTertiary)
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: AppSpacing.sm) {
            AppButton(title: buttonTitle, systemImage: buttonSymbol) {
                submit()
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.md)
        .background(.regularMaterial)
    }

    // MARK: - Helpers

    private var hintText: String {
        if store.isAuthenticated {
            return kitchenMode == .join ? "输入邀请码加入已有私厨" : "给你的私厨起个名字"
        }
        switch authMode {
        case .login: return "用户名和密码登录"
        case .register: return "创建新账号"
        }
    }

    private var buttonTitle: String {
        if store.isAuthenticated {
            return kitchenMode == .join ? "加入" : "创建并进入"
        }
        return authMode == .login ? "登录" : "注册"
    }

    private var buttonSymbol: String {
        if store.isAuthenticated {
            return kitchenMode == .join ? "arrow.right" : "plus"
        }
        return authMode == .login ? "arrow.right" : "arrow.right"
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
        let trimmedUser = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPass = password.trimmingCharacters(in: .whitespacesAndNewlines)

        var valid = true
        if trimmedUser.isEmpty {
            withAnimation(.easeInOut(duration: 0.34)) { userNameInvalid = true }
            userNameShake += 1
            valid = false
        }
        if trimmedPass.isEmpty {
            withAnimation(.easeInOut(duration: 0.34)) { passwordInvalid = true }
            passwordShake += 1
            valid = false
        }
        guard valid else { return }

        let code = showKitchenField && kitchenMode == .join ? kitchenInput : ""
        let name = showKitchenField && kitchenMode == .create ? kitchenInput : ""

        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            await store.login(userName: trimmedUser, password: trimmedPass, inviteCode: code, kitchenName: name)
        }
    }

    private func submitRegister() {
        let trimmedUser = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPass = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNick = nickName.trimmingCharacters(in: .whitespacesAndNewlines)

        var valid = true
        if trimmedUser.isEmpty {
            withAnimation(.easeInOut(duration: 0.34)) { userNameInvalid = true }
            userNameShake += 1
            valid = false
        }
        if trimmedPass.isEmpty {
            withAnimation(.easeInOut(duration: 0.34)) { passwordInvalid = true }
            passwordShake += 1
            valid = false
        }
        if trimmedNick.isEmpty {
            withAnimation(.easeInOut(duration: 0.34)) { nickNameInvalid = true }
            nickNameShake += 1
            valid = false
        }
        guard valid else { return }

        let code = showKitchenField && kitchenMode == .join ? kitchenInput : ""
        let name = showKitchenField && kitchenMode == .create ? kitchenInput : ""

        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            await store.register(userName: trimmedUser, password: trimmedPass, nickName: trimmedNick, inviteCode: code, kitchenName: name)
        }
    }

    private func submitKitchen() {
        let trimmed = kitchenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            withAnimation(.easeInOut(duration: 0.34)) { kitchenInputInvalid = true }
            kitchenInputShake += 1
            return
        }

        Task {
            isSubmitting = true
            defer { isSubmitting = false }
            if kitchenMode == .join {
                await store.joinKitchen(inviteCode: trimmed)
            } else {
                await store.createKitchen(named: trimmed)
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppStore())
}
