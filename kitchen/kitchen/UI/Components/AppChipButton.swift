import SwiftUI

struct AppChipButton: View {
    enum Role {
        case normal
        case removable
    }

    let title: String
    var role: Role = .normal
    var isSelected = false
    var haptic: AppHapticIntent = .selection
    var action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.fire(haptic)
            action()
        } label: {
            HStack(spacing: AppSpacing.xxs) {
                Text(title)
                    .lineLimit(1)
                if role == .removable {
                    Image(systemName: "xmark")
                        .font(.system(size: AppIconSize.xxs, weight: .bold))
                }
            }
            .font(AppTypography.chip)
            .foregroundStyle(isSelected ? AppComponentColor.Chip.selectedForeground : AppComponentColor.Chip.foreground)
            .padding(.horizontal, AppInset.chipHorizontal)
            .frame(height: AppDimension.compactPillHeight)
        }
        .buttonStyle(AppChipButtonStyle(isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AppChipButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(backgroundColor(isPressed: configuration.isPressed), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(AppComponentColor.Chip.border, lineWidth: AppBorderWidth.hairline)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : AppMotion.press, value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return AppComponentColor.Chip.backgroundPressed
        }
        return isSelected ? AppComponentColor.Chip.selectedBackground : AppComponentColor.Chip.background
    }
}
