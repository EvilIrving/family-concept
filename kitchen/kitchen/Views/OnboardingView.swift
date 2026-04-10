import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var displayName = ""
    @State private var primaryInput = ""
    @State private var selectedMode: EntryMode = .join
    @State private var nameIsInvalid = false
    @State private var primaryIsInvalid = false
    @State private var nameShakeTrigger = 0
    @State private var primaryShakeTrigger = 0
    var demoEnterAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            formCard
                .padding(.horizontal, AppSpacing.md)

            Spacer(minLength: 0)
        }
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

                AppInputField(
                    text: $displayName,
                    isInvalid: $nameIsInvalid,
                    prompt: "你的名字",
                    trigger: nameShakeTrigger
                )
                AppInputField(
                    text: $primaryInput,
                    isInvalid: $primaryIsInvalid,
                    prompt: selectedMode.placeholder,
                    autocapitalization: selectedMode.autocapitalization,
                    trigger: primaryShakeTrigger
                )

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

            if let demoEnterAction {
                AppButton(title: "进入当前 Demo", style: .ghost) {
                    demoEnterAction()
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.md)
        .background(.regularMaterial)
    }

    private func submit() {
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

        switch selectedMode {
        case .join:
            store.joinKitchen(inviteCode: trimmedPrimary, displayName: trimmedName)
        case .create:
            store.createKitchen(named: trimmedPrimary, displayName: trimmedName)
        }
    }

    private func switchMode() {
        switchMode(to: selectedMode == .join ? .create : .join)
    }

    private func switchMode(to mode: EntryMode) {
        guard selectedMode != mode else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedMode = mode
            primaryInput = ""
            primaryIsInvalid = false
        }
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

private struct AppInputField: View {
    @Binding var text: String
    @Binding var isInvalid: Bool
    let prompt: String
    var autocapitalization: TextInputAutocapitalization = .sentences
    var trigger: Int = 0

    var body: some View {
        TextField(prompt, text: $text)
            .textInputAutocapitalization(autocapitalization)
            .font(AppTypography.body)
            .foregroundStyle(AppColor.textPrimary)
            .padding(.horizontal, AppSpacing.md)
            .frame(height: 52)
            .background(AppColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .submitLabel(.done)
            .appValidationFeedback(isInvalid: isInvalid, trigger: trigger)
            .onChange(of: text) { oldValue, newValue in
                guard isInvalid, oldValue != newValue else { return }
                withAnimation(.easeInOut(duration: 0.16)) {
                    isInvalid = false
                }
            }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppStore())
}
