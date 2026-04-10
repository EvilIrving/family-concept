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
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(width: 32, height: 32)
                .background(backgroundColor, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private var foregroundColor: Color {
        if isDisabled {
            return AppColor.textTertiary
        }
        switch tone {
        case .neutral:
            return AppColor.textPrimary
        case .brand:
            return AppColor.textOnBrand
        case .danger:
            return AppColor.danger
        }
    }

    private var backgroundColor: Color {
        if isDisabled {
            return AppColor.surfaceTertiary
        }
        switch tone {
        case .neutral:
            return AppColor.surfaceSecondary
        case .brand:
            return AppColor.green800
        case .danger:
            return AppColor.dangerSoft
        }
    }

    private var borderColor: Color {
        if isDisabled {
            return AppColor.lineSoft
        }
        switch tone {
        case .neutral:
            return AppColor.lineSoft
        case .brand, .danger:
            return .clear
        }
    }
}
