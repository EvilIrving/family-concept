import SwiftUI

/// 认证表单组件（登录/注册）
struct AuthForm: View {
    @Binding var userName: String
    @Binding var password: String
    @Binding var nickName: String
    let isRegisterMode: Bool

    @Binding var userNameInvalid: Bool
    @Binding var passwordInvalid: Bool
    @Binding var nickNameInvalid: Bool

    @Binding var userNameShake: Int
    @Binding var passwordShake: Int
    @Binding var nickNameShake: Int

    @FocusState.Binding var focusedField: OnboardingField?

    let onSubmitLogin: () -> Void
    let onSubmitRegister: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            AppTextField(
                title: L10n.tr("用户名"),
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
                if userNameInvalid { OnboardingValidationHelper.resetValidation(&userNameInvalid) }
            }

            AppTextField(
                title: L10n.tr("密码"),
                text: $password,
                focusedField: $focusedField,
                field: .password,
                isSecure: true,
                autocapitalization: .never,
                submitLabel: isRegisterMode ? .next : .done,
                onSubmit: {
                    if isRegisterMode {
                        focusedField = .nickName
                    } else {
                        focusedField = nil
                        onSubmitLogin()
                    }
                },
                isInvalid: passwordInvalid,
                validationTrigger: passwordShake
            )
            .onChange(of: password) { _, _ in
                if passwordInvalid { OnboardingValidationHelper.resetValidation(&passwordInvalid) }
            }

            if isRegisterMode {
                AppTextField(
                    title: L10n.tr("昵称"),
                    text: $nickName,
                    focusedField: $focusedField,
                    field: .nickName,
                    autocapitalization: .words,
                    submitLabel: .done,
                    onSubmit: {
                        focusedField = nil
                        onSubmitRegister()
                    },
                    isInvalid: nickNameInvalid,
                    validationTrigger: nickNameShake
                )
                .onChange(of: nickName) { _, _ in
                    if nickNameInvalid { OnboardingValidationHelper.resetValidation(&nickNameInvalid) }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
