import SwiftUI

struct LanguageRow: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(L10n.tr("Language"))
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textPrimary)
            Spacer(minLength: AppSpacing.sm)
            languagePicker
        }
        .frame(minHeight: 44)
    }

    private var languagePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xxs) {
                ForEach(AppLanguage.allCases) { language in
                    languageButton(language)
                }
            }
            .padding(AppSpacing.xxs)
        }
        .frame(maxWidth: 196)
        .background(
            RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                .fill(AppComponentColor.Segmented.background)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
    }

    private func languageButton(_ language: AppLanguage) -> some View {
        let isSelected = languageStore.language == language
        return Button {
            HapticManager.shared.fire(.selection)
            languageStore.language = language
        } label: {
            Text(language.displayName)
                .font(AppTypography.caption)
                .foregroundStyle(isSelected ? AppComponentColor.Segmented.selectedForeground : AppComponentColor.Segmented.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
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
