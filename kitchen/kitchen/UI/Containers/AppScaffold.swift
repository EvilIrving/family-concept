import SwiftUI

struct AppScrollPage<Header: View, Content: View>: View {
    @ViewBuilder var header: Header
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                header
                content
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)
            .padding(.bottom, 110)
        }
        .scrollDismissesKeyboard(.interactively)
        .appPageBackground()
    }
}

struct AppSheetContainer<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    let dismissTitle: String
    var confirmTitle: String? = nil
    let onDismiss: () -> Void
    var onConfirm: (() -> Void)? = nil
    var isConfirmDisabled: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppSemanticColor.interactiveSecondaryPressed)
                .frame(width: 42, height: 5)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.md)

            HStack(alignment: .top) {
                Button(dismissTitle, action: onDismiss)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppSemanticColor.textSecondary)

                Spacer()

                VStack(spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppSemanticColor.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppSemanticColor.textSecondary)
                    }
                }

                Spacer()

                if let confirmTitle, let onConfirm {
                    Button(confirmTitle, action: onConfirm)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(isConfirmDisabled ? AppSemanticColor.textTertiary : AppSemanticColor.primary)
                        .disabled(isConfirmDisabled)
                } else {
                    Button(dismissTitle, action: onDismiss)
                        .font(AppTypography.bodyStrong)
                        .hidden()
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.bottom, AppSpacing.md)

            content
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
        }
        .background(AppSemanticColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous))
    }
}
