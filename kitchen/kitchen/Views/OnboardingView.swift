import SwiftUI

private enum OnboardingField: Hashable {
    case displayName
    case secondary
}

private enum OnboardingPhase {
    case login
    case join
    case create
}

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var displayName = ""
    @State private var secondaryInput = ""
    @State private var phase: OnboardingPhase = .login
    @State private var nameIsInvalid = false
    @State private var secondaryIsInvalid = false
    @State private var nameShakeTrigger = 0
    @State private var secondaryShakeTrigger = 0
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
        .onChange(of: store.loginNotFound) { _, notFound in
            if notFound {
                withAnimation(.easeInOut(duration: 0.2)) {
                    phase = .login
                }
            }
        }
    }

    private var formCard: some View {
        AppCard(padding: AppSpacing.lg) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                Text(hintText)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)

                AppTextField(
                    title: "你的名字",
                    text: $displayName,
                    focusedField: $focusedField,
                    field: .displayName,
                    autocapitalization: .sentences,
                    submitLabel: phase == .login ? .done : .next,
                    onSubmit: {
                        if phase == .login {
                            focusedField = nil
                            submit()
                        } else {
                            focusedField = .secondary
                        }
                    },
                    isInvalid: nameIsInvalid,
                    validationTrigger: nameShakeTrigger
                )
                .onChange(of: displayName) { oldValue, newValue in
                    guard nameIsInvalid, oldValue != newValue else { return }
                    withAnimation(.easeInOut(duration: 0.16)) {
                        nameIsInvalid = false
                    }
                    // Reset to login phase when name changes after not-found
                    if store.loginNotFound {
                        store.loginNotFound = false
                        withAnimation(.easeInOut(duration: 0.2)) {
                            phase = .login
                        }
                    }
                }

                if store.loginNotFound {
                    modeButtons
                }

                if phase == .join || phase == .create {
                    AppTextField(
                        title: phase == .join ? "邀请码" : "私厨名称",
                        text: $secondaryInput,
                        focusedField: $focusedField,
                        field: .secondary,
                        autocapitalization: phase == .join ? .characters : .words,
                        submitLabel: .done,
                        onSubmit: {
                            focusedField = nil
                            submit()
                        },
                        isInvalid: secondaryIsInvalid,
                        validationTrigger: secondaryShakeTrigger
                    )
                    .onChange(of: secondaryInput) { oldValue, newValue in
                        guard secondaryIsInvalid, oldValue != newValue else { return }
                        withAnimation(.easeInOut(duration: 0.16)) {
                            secondaryIsInvalid = false
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let error = store.error {
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.danger)
                }
            }
        }
    }

    private var modeButtons: some View {
        HStack(spacing: AppSpacing.md) {
            Button("输入邀请码加入") {
                switchPhase(to: .join)
            }
            .font(AppTypography.caption)
            .foregroundStyle(phase == .join ? AppColor.textPrimary : AppColor.textSecondary)

            Text("或")
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)

            Button("创建私厨") {
                switchPhase(to: .create)
            }
            .font(AppTypography.caption)
            .foregroundStyle(phase == .create ? AppColor.textPrimary : AppColor.textSecondary)
        }
    }

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

    private var hintText: String {
        switch phase {
        case .login:
            store.loginNotFound
                ? "没有找到该名字，选择加入或创建"
                : "输入名字登录"
        case .join:
            "输入邀请码加入已有私厨"
        case .create:
            "给你的私厨起个名字"
        }
    }

    private var buttonTitle: String {
        switch phase {
        case .login: "登录"
        case .join: "加入"
        case .create: "创建并进入"
        }
    }

    private var buttonSymbol: String {
        switch phase {
        case .login: "arrow.right"
        case .join: "arrow.right"
        case .create: "plus"
        }
    }

    private func switchPhase(to newPhase: OnboardingPhase) {
        guard phase != newPhase else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = newPhase
            secondaryIsInvalid = false
        }
        secondaryInput = ""
        focusedField = .secondary
    }

    private func submit() {
        focusedField = nil
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextNameInvalid = trimmedName.isEmpty

        withAnimation(.easeInOut(duration: 0.34)) {
            nameIsInvalid = nextNameInvalid
        }
        if nextNameInvalid {
            nameShakeTrigger += 1
            return
        }

        switch phase {
        case .login:
            Task {
                isSubmitting = true
                defer { isSubmitting = false }
                await store.login(displayName: trimmedName)
            }
        case .join, .create:
            let trimmedSecondary = secondaryInput.trimmingCharacters(in: .whitespacesAndNewlines)
            let nextSecondaryInvalid = trimmedSecondary.isEmpty

            withAnimation(.easeInOut(duration: 0.34)) {
                secondaryIsInvalid = nextSecondaryInvalid
            }
            if nextSecondaryInvalid {
                secondaryShakeTrigger += 1
                return
            }

            Task {
                isSubmitting = true
                defer { isSubmitting = false }
                if phase == .join {
                    await store.joinKitchen(inviteCode: trimmedSecondary, displayName: trimmedName)
                } else {
                    await store.createKitchen(named: trimmedSecondary, displayName: trimmedName)
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppStore())
}
