import SwiftUI

struct AppearanceRow: View {
    @Binding var themeMode: String
    @EnvironmentObject private var store: AppStore

    private var options: [(value: String, label: String)] {
        [
            ("light", L10n.tr("Light")),
            ("system", L10n.tr("System")),
            ("dark", L10n.tr("Dark"))
        ]
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(L10n.tr("Appearance"))
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textPrimary)
            Spacer()
            HStack(spacing: AppSpacing.xxs) {
                ForEach(options, id: \.value) { option in
                    segmentButton(value: option.value, label: option.label)
                }
            }
            .padding(AppSpacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                    .fill(AppComponentColor.Segmented.background)
            )
        }
        .frame(minHeight: 44)
    }

    private func segmentButton(value: String, label: String) -> some View {
        let isSelected = themeMode == value
        return Button {
            HapticManager.shared.fire(.selection)
            themeMode = value
            store.setThemeMode(value)
        } label: {
            Text(label)
                .font(AppTypography.caption)
                .foregroundStyle(isSelected ? AppComponentColor.Segmented.selectedForeground : AppComponentColor.Segmented.foreground)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .fill(isSelected ? AppComponentColor.Segmented.selectedBackground : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
