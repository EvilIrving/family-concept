import SwiftUI

struct AppSegmentedButton<Value: Hashable>: View {
    struct Segment: Identifiable {
        let value: Value
        let title: String
        let accessibilityLabel: String

        var id: Value { value }
    }

    let segments: [Segment]
    @Binding var selection: Value
    var haptic: AppHapticIntent = .selection

    var body: some View {
        HStack(spacing: AppSpacing.xxs) {
            ForEach(segments) { segment in
                Button {
                    HapticManager.shared.fire(haptic)
                    selection = segment.value
                } label: {
                    Text(segment.title)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(segment.value == selection ? AppComponentColor.Segmented.selectedForeground : AppComponentColor.Segmented.foreground)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AppDimension.regularControlHeight)
                }
                .buttonStyle(AppSegmentButtonStyle(isSelected: segment.value == selection))
                .accessibilityLabel(segment.accessibilityLabel)
                .accessibilityAddTraits(segment.value == selection ? .isSelected : [])
            }
        }
        .padding(AppSpacing.xxs)
        .background(AppComponentColor.Segmented.background, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .stroke(AppComponentColor.Segmented.border, lineWidth: AppBorderWidth.hairline)
        }
    }
}

private struct AppSegmentButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(backgroundColor(isPressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : AppMotion.press, value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        if isPressed {
            return AppComponentColor.Segmented.pressedBackground
        }
        return isSelected ? AppComponentColor.Segmented.selectedBackground : .clear
    }
}
