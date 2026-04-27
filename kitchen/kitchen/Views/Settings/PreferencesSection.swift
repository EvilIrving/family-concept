import SwiftUI

/// 偏好设置区域组件
struct PreferencesSection: View {
    @Binding var notificationsEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Binding var themeMode: String

    var body: some View {
        AppCard {
            VStack(spacing: 0) {
                toggleRow(title: "通知", isOn: $notificationsEnabled)
                rowDivider
                placeholderRow(title: "语言")
                rowDivider
                toggleRow(title: "触感反馈", isOn: $hapticsEnabled)
                rowDivider
                ThemeSelectionRow(themeMode: $themeMode)
            }
        }
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

    private func placeholderRow(title: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textPrimary)
            Spacer()
            Text("稍后推出")
                .font(AppTypography.body)
                .foregroundStyle(AppSemanticColor.textSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: AppIconSize.xs, weight: .semibold))
                .foregroundStyle(AppSemanticColor.textTertiary)
        }
        .frame(minHeight: 44)
    }
}
