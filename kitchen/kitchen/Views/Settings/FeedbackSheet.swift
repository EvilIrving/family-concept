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
        AppSheetContainer(title: L10n.tr("Requests & Feedback"), dismissTitle: L10n.tr("Close"), onDismiss: { dismiss() }) {
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
            fieldLabel(L10n.tr("Requests or feedback"))
            feedbackEditor
            fieldLabel(L10n.tr("Contact"))
            platformPicker
            AppTextField(
                title: L10n.tr("Leave your %@ contact", contactPlatform.displayName),
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
                    Text("Write feature requests, issues, or comments here")
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
            Text("Or scan to reach us on Telegram")
                .font(AppTypography.caption)
                .foregroundStyle(AppSemanticColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.md)
        .background(AppSemanticColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
    }

    private var submitButton: some View {
        AppButton(
            title: L10n.tr("Submit"),
            leadingIcon: "paperplane.fill",
            role: .primary,
            phase: isSubmitting ? .loading(label: L10n.tr("Submitting")) : .idle
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
            feedbackRouter.show(.low(message: L10n.tr("Please write your request or comment first")), placement: .centerToast)
            return
        }
        guard !contactTrimmed.isEmpty else {
            focusedField = .contact
            feedbackRouter.show(.low(message: L10n.tr("Please leave a contact")), placement: .centerToast)
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
                    feedbackRouter.show(.high(message: L10n.tr("Feedback submitted")), placement: .centerToast)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    feedbackRouter.show(store.feedback(for: error), placement: .centerToast)
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
