import SwiftUI

/// 主题选择行组件
struct ThemeSelectionRow: View {
    @Binding var themeMode: String
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text("主题")
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textPrimary)
            Spacer()
            Menu {
                ForEach([("浅色", "light"), ("系统", "system"), ("深色", "dark")], id: \.1) { label, value in
                    Button {
                        themeMode = value
                        store.setThemeMode(value)
                    } label: {
                        HStack {
                            Text(label)
                            if themeMode == value {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Text(themeDisplayName)
                        .font(AppTypography.body)
                        .foregroundStyle(AppSemanticColor.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: AppIconSize.xs, weight: .semibold))
                        .foregroundStyle(AppSemanticColor.textTertiary)
                }
            }
        }
        .frame(minHeight: 44)
    }

    private var themeDisplayName: String {
        switch themeMode {
        case "light": return "浅色"
        case "dark": return "深色"
        default: return "系统"
        }
    }
}
