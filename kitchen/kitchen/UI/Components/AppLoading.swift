import SwiftUI

struct AppLoadingIndicator: View {
    enum Tone {
        case primary
        case secondary
        case inverse

        var tintColor: Color {
            switch self {
            case .primary:
                return AppSemanticColor.primary
            case .secondary:
                return AppSemanticColor.textSecondary
            case .inverse:
                return AppSemanticColor.surface
            }
        }
    }

    var label: String? = nil
    var tone: Tone = .primary
    var controlSize: ControlSize = .regular

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            ProgressView()
                .tint(tone.tintColor)
                .controlSize(controlSize)

            if let label {
                Text(label)
                    .font(AppTypography.micro)
                    .foregroundStyle(tone == .inverse ? AppSemanticColor.surface : AppSemanticColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct AppLoadingBlock: View {
    var label: String? = nil
    var tone: AppLoadingIndicator.Tone = .primary

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            AppLoadingIndicator(label: label, tone: tone)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.md)
    }
}
