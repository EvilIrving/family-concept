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
    var dismissSystemImage: String = "xmark"
    var confirmTitle: String? = nil
    var confirmSystemImage: String = "checkmark"
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
                        sheetIconButton(
                            systemImage: dismissSystemImage,
                            accessibilityLabel: dismissTitle,
                            tone: .neutral,
                            isDisabled: isConfirmLoading,
                            action: onDismiss
                        )

                        Spacer(minLength: AppSpacing.md)

                        if let confirmTitle, let onConfirm {
                            sheetIconButton(
                                systemImage: confirmSystemImage,
                                accessibilityLabel: confirmTitle,
                                tone: .brand,
                                isDisabled: isConfirmDisabled || isConfirmLoading,
                                isLoading: isConfirmLoading,
                                action: onConfirm
                            )
                        } else {
                            sheetIconPlaceholder()
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)
            } else {
                HStack {
                    sheetIconButton(
                        systemImage: dismissSystemImage,
                        accessibilityLabel: dismissTitle,
                        tone: .neutral,
                        action: onDismiss
                    )
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

    private func sheetIconButton(
        systemImage: String,
        accessibilityLabel: String,
        tone: AppIconActionButton.Tone,
        isDisabled: Bool = false,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Image(systemName: systemImage)
                    .font(.system(size: AppIconSize.sm, weight: .semibold))
                    .opacity(isLoading ? 0 : 1)

                if isLoading {
                    AppLoadingIndicator(tone: .primary, controlSize: .small)
                }
            }
            .foregroundStyle(sheetIconForeground(tone: tone, isDisabled: isDisabled))
            .frame(width: AppDimension.iconButtonSide, height: AppDimension.iconButtonSide)
            .background(sheetIconBackground(tone: tone, isDisabled: isDisabled), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                    .stroke(sheetIconBorder(tone: tone, isDisabled: isDisabled), lineWidth: AppBorderWidth.hairline)
            }
            .animation(.easeInOut(duration: 0.15), value: isLoading)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(accessibilityLabel)
    }

    private func sheetIconPlaceholder() -> some View {
        Color.clear
            .frame(width: AppDimension.iconButtonSide, height: AppDimension.iconButtonSide)
            .accessibilityHidden(true)
    }

    private func sheetIconForeground(tone: AppIconActionButton.Tone, isDisabled: Bool) -> Color {
        if isDisabled {
            return AppComponentColor.IconActionButton.disabledForeground
        }
        switch tone {
        case .neutral:
            return AppComponentColor.IconActionButton.neutralForeground
        case .brand:
            return AppComponentColor.IconActionButton.brandForeground
        case .danger:
            return AppComponentColor.IconActionButton.dangerForeground
        }
    }

    private func sheetIconBackground(tone: AppIconActionButton.Tone, isDisabled: Bool) -> Color {
        if isDisabled {
            return AppComponentColor.IconActionButton.disabledBackground
        }
        switch tone {
        case .neutral:
            return AppComponentColor.IconActionButton.neutralBackground
        case .brand:
            return AppComponentColor.IconActionButton.brandBackground
        case .danger:
            return AppComponentColor.IconActionButton.dangerBackground
        }
    }

    private func sheetIconBorder(tone: AppIconActionButton.Tone, isDisabled: Bool) -> Color {
        if isDisabled {
            return AppComponentColor.IconActionButton.disabledBorder
        }
        switch tone {
        case .neutral:
            return AppComponentColor.IconActionButton.neutralBorder
        case .brand, .danger:
            return .clear
        }
    }
}
