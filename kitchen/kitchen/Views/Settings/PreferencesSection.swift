import SwiftUI

struct PreferencesSection: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    // TODO: 通知开关未实现，恢复时打开下面的 Binding 与 toggleRow。
    // @Binding var notificationsEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Binding var themeMode: String

    var body: some View {
        AppCard {
            VStack(spacing: 0) {
                languageRow
                rowDivider
                AppearanceRow(themeMode: $themeMode)
                rowDivider
                // toggleRow(title: L10n.tr("Notifications"), isOn: $notificationsEnabled)
                // rowDivider
                toggleRow(title: L10n.tr("Haptics"), isOn: $hapticsEnabled)
            }
        }
    }

    private var languageRow: some View {
        HStack {
            Text(L10n.tr("Language"))
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textPrimary)
            Spacer()
            Picker(L10n.tr("Language"), selection: $languageStore.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .labelsHidden()
            .tint(AppSemanticColor.textSecondary)
        }
        .frame(minHeight: 44)
    }

    private var rowDivider: some View {
        Divider().overlay(AppSemanticColor.border)
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(AppSemanticColor.brandAccent)
                .labelsHidden()
        }
        .frame(minHeight: 44)
    }

}
