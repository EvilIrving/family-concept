import SwiftUI

struct AppRowButton<Content: View>: View {
    enum Accessory {
        case chevron
        case none
        case custom(AnyView)
    }

    let action: () -> Void
    var accessory: Accessory
    var haptic: AppHapticIntent
    @ViewBuilder var content: Content

    init(
        action: @escaping () -> Void,
        accessory: Accessory = .chevron,
        haptic: AppHapticIntent = .selection,
        @ViewBuilder content: () -> Content
    ) {
        self.action = action
        self.accessory = accessory
        self.haptic = haptic
        self.content = content()
    }

    var body: some View {
        Button {
            HapticManager.shared.fire(haptic)
            action()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                accessoryView
            }
            .foregroundStyle(AppComponentColor.Row.foreground)
            .frame(maxWidth: .infinity, minHeight: AppDimension.minTouchTarget, alignment: .leading)
            .padding(AppInset.card)
        }
        .buttonStyle(AppRowButtonStyle())
    }

    @ViewBuilder
    private var accessoryView: some View {
        switch accessory {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: AppIconSize.xs, weight: .semibold))
                .foregroundStyle(AppComponentColor.Row.accessory)
        case .none:
            EmptyView()
        case let .custom(view):
            view
        }
    }
}

private struct AppRowButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? AppComponentColor.Row.backgroundPressed : AppComponentColor.Row.background, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
            .animation(reduceMotion ? nil : AppMotion.press, value: configuration.isPressed)
    }
}
