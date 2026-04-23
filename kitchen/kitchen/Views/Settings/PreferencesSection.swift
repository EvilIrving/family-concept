import SwiftUI

/// 偏好设置区域组件
struct PreferencesSection: View {
    @Binding var notificationsEnabled: Bool
    @Binding var hapticsEnabled: Bool
    @Binding var themeMode: String

    var body: some View {
        AppCard {
            AppSectionHeader(title: "偏好")

            VStack(spacing: 0) {
                toggleRow(title: "消息通知", isOn: $notificationsEnabled)
                rowDivider
                toggleRow(title: "震动反馈", isOn: $hapticsEnabled)
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
}
