import SwiftUI

struct AppIconActionButton: View {
    enum Tone {
        case neutral
        case brand
        case danger
    }

    enum Size {
        case sm
        case md
        case lg

        var side: CGFloat {
            switch self {
            case .sm:
                return 28
            case .md:
                return AppDimension.iconButtonSide
            case .lg:
                return 40
            }
        }
    }

    let systemImage: String
    var tone: Tone = .neutral
    var size: Size = .md
    var isDisabled = false
    var haptic: AppButton.HapticPolicy = .automatic
    var action: () -> Void

    var body: some View {
        Button {
            fireHaptic()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: AppIconSize.xs, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(width: size.side, height: size.side)
                .background(backgroundColor, in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                        .stroke(borderColor, lineWidth: AppBorderWidth.hairline)
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func fireHaptic() {
        switch haptic {
        case .none:
            return
        case .automatic:
            HapticManager.shared.fire(tone == .danger ? .warning : .selection)
        case let .custom(intent):
            HapticManager.shared.fire(intent)
        }
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
