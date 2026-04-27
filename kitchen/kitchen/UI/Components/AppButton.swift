import SwiftUI

struct AppButton: View {
    enum Role {
        case primary
        case secondary
        case ghost
        case destructive
    }

    enum Size {
        case sm
        case md
        case lg
    }

    enum HapticPolicy {
        case none
        case automatic
        case custom(AppHapticIntent)
    }

    let title: String
    var leadingIcon: String? = nil
    var role: Role = .primary
    var size: Size = .md
    var fullWidth: Bool = true
    var phase: LoadingPhase<Void> = .idle
    var haptic: HapticPolicy = .automatic
    var action: () -> Void

    var body: some View {
        Button {
            fireHaptic()
            action()
        } label: {
            HStack(spacing: AppSpacing.xs) {
                if phase.isLoading {
                    AppLoadingIndicator(label: loadingLabel, tone: loadingTone, controlSize: .small)
                } else if let leadingIcon {
                    Image(systemName: leadingIcon)
                        .font(.system(size: AppIconSize.sm, weight: .semibold))
                }
                Text(title)
            }
            .font(font)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: minHeight)
            .padding(.horizontal, horizontalPadding)
        }
        .buttonStyle(AppButtonStyle(role: role, size: size))
        .disabled(phase.isLoading)
    }

    private var foregroundColor: Color {
        switch role {
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
        switch role {
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

    private var minHeight: CGFloat {
        switch size {
        case .sm:
            return 36
        case .md:
            return AppDimension.buttonHeight
        case .lg:
            return AppDimension.floatingButtonHeight
        }
    }

    private var horizontalPadding: CGFloat {
        switch size {
        case .sm:
            return AppSpacing.sm
        case .md:
            return AppSpacing.md
        case .lg:
            return AppSpacing.lg
        }
    }

    private var font: Font {
        size == .sm ? AppTypography.bodyStrong : AppTypography.button
    }

    private func fireHaptic() {
        switch haptic {
        case .none:
            return
        case .automatic:
            HapticManager.shared.fire(automaticHapticIntent)
        case let .custom(intent):
            HapticManager.shared.fire(intent)
        }
    }

    private var automaticHapticIntent: AppHapticIntent {
        switch role {
        case .primary, .secondary:
            return .light
        case .destructive:
            return .warning
        case .ghost:
            return .selection
        }
    }
}

private struct AppButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    let role: AppButton.Role
    let size: AppButton.Size

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(resolvedBackgroundColor(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(borderColor, lineWidth: role == .ghost ? AppBorderWidth.hairline : 0)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : AppMotion.press, value: configuration.isPressed)
    }

    private func resolvedBackgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            switch role {
            case .primary:
                return AppComponentColor.Button.primaryBackgroundDisabled
            case .secondary:
                return AppComponentColor.Button.secondaryBackgroundDisabled
            case .ghost:
                return AppComponentColor.Button.ghostBackgroundDisabled
            case .destructive:
                return AppComponentColor.Button.destructiveBackgroundDisabled
            }
        }

        switch role {
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
        switch role {
        case .ghost:
            return AppComponentColor.Button.ghostBorder
        default:
            return .clear
        }
    }

    private var radius: CGFloat {
        size == .sm ? AppRadius.sm : AppRadius.md
    }
}
