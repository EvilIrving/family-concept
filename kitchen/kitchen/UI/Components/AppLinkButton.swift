import SwiftUI

struct AppLinkButton: View {
    enum Role {
        case primary
        case secondary
        case destructive
    }

    let title: String
    var role: Role = .primary
    var haptic: AppHapticIntent = .selection
    var action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.fire(haptic)
            action()
        } label: {
            Text(title)
                .font(AppTypography.bodyStrong)
                .frame(minHeight: AppDimension.minTouchTarget)
        }
        .buttonStyle(AppLinkButtonStyle(role: role))
    }
}

private struct AppLinkButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let role: AppLinkButton.Role

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? pressedColor : foregroundColor)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : AppMotion.press, value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        switch role {
        case .primary:
            return AppComponentColor.Link.primary
        case .secondary:
            return AppComponentColor.Link.secondary
        case .destructive:
            return AppComponentColor.Link.destructive
        }
    }

    private var pressedColor: Color {
        switch role {
        case .primary:
            return AppComponentColor.Link.primaryPressed
        case .secondary:
            return AppComponentColor.Link.primaryPressed
        case .destructive:
            return AppComponentColor.Link.destructive
        }
    }
}
