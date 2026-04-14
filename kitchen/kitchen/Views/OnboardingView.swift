import SwiftUI

private enum OnboardingField: Hashable {
    case displayName
    case primary
}

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var displayName = ""
    @State private var primaryInput = ""
    @State private var selectedMode: EntryMode = .join
    @State private var nameIsInvalid = false
    @State private var primaryIsInvalid = false
    @State private var nameShakeTrigger = 0
    @State private var primaryShakeTrigger = 0
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
                Text(selectedMode.hint)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)

                AppTextField(
                    title: "你的名字",
                    text: $displayName,
                    focusedField: $focusedField,
                    field: .displayName,
                    autocapitalization: .sentences,
                    submitLabel: .next,
                    onSubmit: { focusedField = .primary },
                    isInvalid: nameIsInvalid,
                    validationTrigger: nameShakeTrigger
                )
                .onChange(of: displayName) { oldValue, newValue in
                    guard nameIsInvalid, oldValue != newValue else { return }
                    withAnimation(.easeInOut(duration: 0.16)) {
                        nameIsInvalid = false
                    }
                }

                AppTextField(
                    title: selectedMode.placeholder,
                    text: $primaryInput,
                    focusedField: $focusedField,
                    field: .primary,
                    autocapitalization: selectedMode.autocapitalization,
                    submitLabel: .done,
                    onSubmit: {
                        focusedField = nil
                        submit()
                    },
                    isInvalid: primaryIsInvalid,
                    validationTrigger: primaryShakeTrigger
                )
                .onChange(of: primaryInput) { oldValue, newValue in
                    guard primaryIsInvalid, oldValue != newValue else { return }
                    withAnimation(.easeInOut(duration: 0.16)) {
                        primaryIsInvalid = false
                    }
                }

                if let error = store.error {
                    Text(error)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.danger)
                }

                HStack {
                    Spacer()

                    Button(selectedMode.switchTitle) {
                        switchMode()
                    }
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: AppSpacing.sm) {
            AppButton(title: selectedMode.buttonTitle, systemImage: selectedMode.buttonSymbol) {
                submit()
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.md)
        .background(.regularMaterial)
    }

    private func submit() {
        focusedField = nil
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPrimary = primaryInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let nextNameInvalid = trimmedName.isEmpty
        let nextPrimaryInvalid = trimmedPrimary.isEmpty

        withAnimation(.easeInOut(duration: 0.34)) {
            nameIsInvalid = nextNameInvalid
            primaryIsInvalid = nextPrimaryInvalid
        }

        if nextNameInvalid {
            nameShakeTrigger += 1
        }

        if nextPrimaryInvalid {
            primaryShakeTrigger += 1
        }

        guard !nextNameInvalid, !nextPrimaryInvalid else { return }

        Task {
            isSubmitting = true
            defer { isSubmitting = false }

            switch selectedMode {
            case .join:
                await store.joinKitchen(inviteCode: trimmedPrimary, displayName: trimmedName)
            case .create:
                await store.createKitchen(named: trimmedPrimary, displayName: trimmedName)
            }
        }
    }

    private func switchMode() {
        switchMode(to: selectedMode == .join ? .create : .join)
    }

    private func switchMode(to mode: EntryMode) {
        guard selectedMode != mode else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedMode = mode
            primaryIsInvalid = false
        }
        primaryInput = ""
        focusedField = nextFocusFieldAfterModeSwitch()
    }

    private func nextFocusFieldAfterModeSwitch() -> OnboardingField {
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .displayName
        }
        return .primary
    }
}

private enum EntryMode: CaseIterable {
    case join
    case create

    var hint: String {
        switch self {
        case .join:
            return "输入名字和邀请码，直接进入"
        case .create:
            return "输入名字和私厨名称，立即创建"
        }
    }

    var placeholder: String {
        switch self {
        case .join:
            return "邀请码"
        case .create:
            return "私厨名称"
        }
    }

    var buttonTitle: String {
        switch self {
        case .join:
            return "加入"
        case .create:
            return "创建并进入"
        }
    }

    var buttonSymbol: String {
        switch self {
        case .join:
            return "arrow.right"
        case .create:
            return "plus"
        }
    }

    var autocapitalization: TextInputAutocapitalization {
        switch self {
        case .join:
            return .characters
        case .create:
            return .words
        }
    }

    var switchTitle: String {
        switch self {
        case .join:
            return "创建我的私厨"
        case .create:
            return "已有邀请码，改为加入"
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppStore())
}
