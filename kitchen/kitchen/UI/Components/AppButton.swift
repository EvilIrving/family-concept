import SwiftUI

struct AppButton: View {
    enum Style {
        case primary
        case secondary
        case ghost
        case destructive
    }

    let title: String
    var systemImage: String? = nil
    var style: Style = .primary
    var fullWidth: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
            }
            .font(AppTypography.button)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(minHeight: 50)
            .padding(.horizontal, AppSpacing.md)
        }
        .buttonStyle(AppButtonStyle(style: style))
    }

    private var foregroundColor: Color {
        switch style {
        case .primary:
            return AppColor.textOnBrand
        case .secondary:
            return AppColor.green800
        case .ghost:
            return AppColor.textPrimary
        case .destructive:
            return AppColor.danger
        }
    }
}

private struct AppButtonStyle: ButtonStyle {
    let style: AppButton.Style

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(backgroundColor.opacity(configuration.isPressed ? 0.92 : 1), in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(borderColor, lineWidth: style == .ghost ? 1 : 0)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary:
            return AppColor.green800
        case .secondary:
            return AppColor.green100
        case .ghost:
            return AppColor.surfacePrimary
        case .destructive:
            return AppColor.dangerSoft
        }
    }

    private var borderColor: Color {
        switch style {
        case .ghost:
            return AppColor.lineSoft
        default:
            return .clear
        }
    }
}
