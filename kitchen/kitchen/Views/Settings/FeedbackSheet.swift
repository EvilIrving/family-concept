import SwiftUI

struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @FocusState private var focusedField: Field?
    @State private var message = ""
    @State private var contactPlatform: FeedbackContactPlatform = .tg
    @State private var contactHandle = ""
    @State private var isSubmitting = false
    @State private var validationTrigger = 0

    private enum Field: Hashable {
        case message
        case contact
    }

    var body: some View {
        AppSheetContainer(title: "需求和反馈", dismissTitle: "关闭", onDismiss: { dismiss() }) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    inputCard
                    qrCodeCard
                    submitButton
                }
                .padding(.bottom, AppSpacing.xl)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            fieldLabel("想提的需求和吐槽")
            feedbackEditor
            fieldLabel("联系方式")
            platformPicker
            AppTextField(
                title: "留下 \(contactPlatform.displayName) 联系方式",
                text: $contactHandle,
                focusedField: $focusedField,
                field: .contact,
                isInvalid: contactTrimmed.isEmpty && validationTrigger > 0,
                validationTrigger: validationTrigger
            )
        }
    }

    private var feedbackEditor: some View {
        TextEditor(text: $message)
            .focused($focusedField, equals: .message)
            .font(AppTypography.body)
            .foregroundStyle(AppSemanticColor.textPrimary)
            .tint(AppSemanticColor.primary)
            .frame(minHeight: 150)
            .padding(AppSpacing.sm)
            .scrollContentBackground(.hidden)
            .background(AppComponentColor.Input.background, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay(alignment: .topLeading) {
                if message.isEmpty {
                    Text("把所有想要的功能、遇到的问题、吐槽都写在这里")
                        .font(AppTypography.body)
                        .foregroundStyle(AppComponentColor.Input.placeholder)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.md)
                        .allowsHitTesting(false)
                }
            }
            .appValidationFeedback(isInvalid: messageTrimmed.isEmpty && validationTrigger > 0, trigger: validationTrigger)
    }

    private var platformPicker: some View {
        AppSegmentedButton(
            segments: platformSegments,
            selection: $contactPlatform
        )
    }

    private var platformSegments: [AppSegmentedButton<FeedbackContactPlatform>.Segment] {
        FeedbackContactPlatform.allCases.map { platform in
            .init(
                value: platform,
                title: platform.displayName,
                accessibilityLabel: platform.displayName,
                imageAssetName: platform.logoAssetName
            )
        }
    }

    private var qrCodeCard: some View {
        VStack(spacing: AppSpacing.md) {
            Image("TelegramQRCode")
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 168, height: 168)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            Text("也可以扫码直接联系 TG")
                .font(AppTypography.caption)
                .foregroundStyle(AppSemanticColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.md)
        .background(AppSemanticColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
    }

    private var submitButton: some View {
        AppButton(
            title: "提交",
            leadingIcon: "paperplane.fill",
            role: .primary,
            phase: isSubmitting ? .loading(label: "提交中") : .idle
        ) {
            submit()
        }
        .disabled(isSubmitting)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.bodyStrong)
            .foregroundStyle(AppSemanticColor.textPrimary)
    }

    private var messageTrimmed: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var contactTrimmed: String {
        contactHandle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        validationTrigger += 1
        guard !messageTrimmed.isEmpty else {
            focusedField = .message
            feedbackRouter.show(.low(message: "请先填写需求或吐槽"), hint: .centerToast)
            return
        }
        guard !contactTrimmed.isEmpty else {
            focusedField = .contact
            feedbackRouter.show(.low(message: "请留下联系方式"), hint: .centerToast)
            return
        }

        isSubmitting = true
        Task {
            do {
                _ = try await store.apiClient.submitFeedback(
                    message: messageTrimmed,
                    contactPlatform: contactPlatform,
                    contactHandle: contactTrimmed,
                    authToken: store.authToken
                )
                await MainActor.run {
                    isSubmitting = false
                    feedbackRouter.show(.high(message: "已提交反馈"), hint: .centerToast)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    feedbackRouter.show(store.feedback(for: error), hint: .centerToast)
                }
            }
        }
    }
}

#Preview {
    FeedbackSheet()
        .environmentObject(AppStore())
        .environmentObject(AppFeedbackRouter.shared)
}
