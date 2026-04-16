import SwiftUI

struct AppIconActionButton: View {
    enum Tone {
        case neutral
        case brand
        case danger
    }

    let systemImage: String
    var tone: Tone = .neutral
    var isDisabled = false
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: AppIconSize.xs, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(width: AppDimension.iconButtonSide, height: AppDimension.iconButtonSide)
                .background(backgroundColor, in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .stroke(borderColor, lineWidth: AppBorderWidth.hairline)
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var foregroundColor: Color {
        if isDisabled {
            return AppComponentColor.IconActionButton.disabledForeground
        }
        switch tone {
        case .neutral:
            return AppComponentColor.IconActionButton.neutralForeground
        case .brand:
            return AppComponentColor.IconActionButton.brandForeground
        case .danger:
            return AppComponentColor.IconActionButton.dangerForeground
        }
    }

    private var backgroundColor: Color {
        if isDisabled {
            return AppComponentColor.IconActionButton.disabledBackground
        }
        switch tone {
        case .neutral:
            return AppComponentColor.IconActionButton.neutralBackground
        case .brand:
            return AppComponentColor.IconActionButton.brandBackground
        case .danger:
            return AppComponentColor.IconActionButton.dangerBackground
        }
    }

    private var borderColor: Color {
        if isDisabled {
            return AppComponentColor.IconActionButton.disabledBorder
        }
        switch tone {
        case .neutral:
            return AppComponentColor.IconActionButton.neutralBorder
        case .brand, .danger:
            return .clear
        }
    }
}
