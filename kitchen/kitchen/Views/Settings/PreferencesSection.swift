import SwiftUI

/// 偏好设置区域组件
struct PreferencesSection: View {
    @EnvironmentObject private var languageStore: AppLanguageStore
    @Binding var notificationsEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Binding var themeMode: String

    var body: some View {
        AppCard {
            VStack(spacing: 0) {
                toggleRow(title: "通知", isOn: $notificationsEnabled)
                rowDivider
                languageRow
                rowDivider
                toggleRow(title: "触感反馈", isOn: $hapticsEnabled)
                rowDivider
                ThemeSelectionRow(themeMode: $themeMode)
            }
        }
    }

    private var languageRow: some View {
        HStack {
            Text("语言")
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textPrimary)
            Spacer()
            Picker("语言", selection: $languageStore.language) {
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
