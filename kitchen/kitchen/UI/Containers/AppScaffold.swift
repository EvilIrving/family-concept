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
    let title: String?
    var subtitle: String? = nil
    let dismissTitle: String
    var confirmTitle: String? = nil
    let onDismiss: () -> Void
    var onConfirm: (() -> Void)? = nil
    var isConfirmDisabled: Bool = false
    var isConfirmLoading: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppSemanticColor.interactiveSecondaryPressed)
                .frame(width: 42, height: 5)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.md)

            if title != nil || subtitle != nil || confirmTitle != nil {
                ZStack(alignment: .top) {
                    VStack(spacing: AppSpacing.xxs) {
                        if let title {
                            Text(title)
                                .font(AppTypography.cardTitle)
                                .foregroundStyle(AppSemanticColor.textPrimary)
                        }
                        if let subtitle {
                            Text(subtitle)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppSemanticColor.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)

                    HStack(alignment: .top) {
                        Button(dismissTitle, action: onDismiss)
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(isConfirmLoading ? AppSemanticColor.textTertiary : AppSemanticColor.textSecondary)
                            .disabled(isConfirmLoading)

                        Spacer(minLength: AppSpacing.md)

                        if let confirmTitle, let onConfirm {
                            Button(action: onConfirm) {
                                ZStack {
                                    Text(confirmTitle)
                                        .opacity(isConfirmLoading ? 0 : 1)
                                    if isConfirmLoading {
                                        AppLoadingIndicator(tone: .primary, controlSize: .small)
                                    }
                                }
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(isConfirmDisabled ? AppSemanticColor.textTertiary : AppSemanticColor.primary)
                                .animation(.easeInOut(duration: 0.15), value: isConfirmLoading)
                            }
                            .disabled(isConfirmDisabled || isConfirmLoading)
                            .accessibilityLabel(confirmTitle)
                        } else {
                            Text(dismissTitle)
                                .font(AppTypography.bodyStrong)
                                .hidden()
                                .accessibilityHidden(true)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)
            } else {
                HStack {
                    Button(dismissTitle, action: onDismiss)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppSemanticColor.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)
            }

            content
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppSemanticColor.surface)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: AppRadius.xxl,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: AppRadius.xxl,
                style: .continuous
            )
        )
        .ignoresSafeArea(edges: .bottom)
    }
}
