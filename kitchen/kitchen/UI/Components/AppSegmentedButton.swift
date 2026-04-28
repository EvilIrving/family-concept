import SwiftUI

struct AppSegmentedButton<Value: Hashable>: View {
    struct Segment: Identifiable {
        let value: Value
        let title: String
        let accessibilityLabel: String
        let imageAssetName: String?

        init(value: Value, title: String, accessibilityLabel: String, imageAssetName: String? = nil) {
            self.value = value
            self.title = title
            self.accessibilityLabel = accessibilityLabel
            self.imageAssetName = imageAssetName
        }

        var id: Value { value }
    }

    let segments: [Segment]
    @Binding var selection: Value
    var haptic: AppHapticIntent = .selection

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                Button {
                    HapticManager.shared.fire(haptic)
                    selection = segment.value
                } label: {
                    segmentLabel(for: segment)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: AppDimension.regularControlHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(AppSegmentButtonStyle(isSelected: segment.value == selection))
                .overlay(alignment: .trailing) {
                    if shouldShowDivider(at: index) {
                        Rectangle()
                            .fill(AppComponentColor.Segmented.border)
                            .frame(width: AppDimension.divider, height: 20)
                    }
                }
                .accessibilityLabel(segment.accessibilityLabel)
                .accessibilityAddTraits(segment.value == selection ? .isSelected : [])
            }
        }
        .background(AppComponentColor.Segmented.background, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .stroke(AppComponentColor.Segmented.border, lineWidth: AppBorderWidth.hairline)
        }
    }

    private func shouldShowDivider(at index: Int) -> Bool {
        guard index < segments.count - 1 else { return false }
        let current = segments[index]
        let next = segments[index + 1]
        return selection != current.value && selection != next.value
    }

    @ViewBuilder
    private func segmentLabel(for segment: Segment) -> some View {
        if let imageAssetName = segment.imageAssetName {
            Image(imageAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
        } else {
            Text(segment.title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(segment.value == selection ? AppComponentColor.Segmented.selectedForeground : AppComponentColor.Segmented.foreground)
        }
    }
}

private struct AppSegmentButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .padding(3)
            }
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
