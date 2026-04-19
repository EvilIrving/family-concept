import SwiftUI

struct AppButton: View {
    enum Style {
        case primary
        case secondary
        case ghost
        case destructive
    }

    let title: String
    var systemImage: String? = nil
    var style: Style = .primary
    var fullWidth: Bool = true
    var phase: LoadingPhase<Void> = .idle
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if phase.isLoading {
                    AppLoadingIndicator(label: loadingLabel, tone: loadingTone, controlSize: .small)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: AppIconSize.sm, weight: .semibold))
                }
                Text(title)
            }
            .font(AppTypography.button)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: AppDimension.buttonHeight)
            .padding(.horizontal, AppSpacing.md)
        }
        .buttonStyle(AppButtonStyle(style: style))
        .disabled(phase.isLoading)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return AppComponentColor.Button.primaryText
        case .secondary:
            return AppComponentColor.Button.secondaryText
        case .ghost:
            return AppComponentColor.Button.ghostText
        case .destructive:
            return AppComponentColor.Button.destructiveText
        }
    }

    private var loadingTone: AppLoadingIndicator.Tone {
        switch style {
        case .primary, .destructive:
            return .inverse
        case .secondary, .ghost:
            return .secondary
        }
    }

    private var loadingLabel: String? {
        guard case .loading(let context) = phase else { return nil }
        return context.label == title ? nil : context.label
    }
}

private struct AppButtonStyle: ButtonStyle {
    let style: AppButton.Style

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(resolvedBackgroundColor(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(borderColor, lineWidth: style == .ghost ? AppBorderWidth.hairline : 0)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(AppMotion.press, value: configuration.isPressed)
    }

    private func resolvedBackgroundColor(isPressed: Bool) -> Color {
        switch style {
        case .primary:
            return isPressed ? AppComponentColor.Button.primaryBackgroundPressed : AppComponentColor.Button.primaryBackground
        case .secondary:
            return isPressed ? AppComponentColor.Button.secondaryBackgroundPressed : AppComponentColor.Button.secondaryBackground
        case .ghost:
            return isPressed ? AppComponentColor.Button.ghostBackgroundPressed : AppComponentColor.Button.ghostBackground
        case .destructive:
            return isPressed ? AppComponentColor.Button.destructiveBackgroundPressed : AppComponentColor.Button.destructiveBackground
        }
    }

    private var borderColor: Color {
        switch style {
        case .ghost:
            return AppComponentColor.Button.ghostBorder
        default:
            return .clear
        }
    }
}
