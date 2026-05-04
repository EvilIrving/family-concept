import SwiftUI

/// 主题选择行组件
struct ThemeSelectionRow: View {
    @Binding var themeMode: String
    @EnvironmentObject private var store: AppStore

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text("Appearance")
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textPrimary)
            Spacer()
            Menu {
                ForEach([(L10n.tr("Light"), "light"), (L10n.tr("System"), "system"), (L10n.tr("Dark"), "dark")], id: \.1) { label, value in
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
        case "light": return L10n.tr("Light")
        case "dark": return L10n.tr("Dark")
        default: return L10n.tr("System")
        }
    }
}
