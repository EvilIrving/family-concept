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
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(AppColor.green200)
                .frame(width: 42, height: 5)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.md)

            HStack(alignment: .top) {
                Button(dismissTitle, action: onDismiss)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppColor.textSecondary)

                Spacer()

                VStack(spacing: AppSpacing.xxs) {
                    Text(title)
                        .font(AppTypography.cardTitle)
                        .foregroundStyle(AppColor.textPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }

                Spacer()

                if let confirmTitle, let onConfirm {
                    Button(confirmTitle, action: onConfirm)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppColor.green800)
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
        .background(AppColor.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous))
    }
}
