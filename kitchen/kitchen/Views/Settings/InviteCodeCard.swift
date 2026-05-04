import SwiftUI

/// 邀请码卡片组件
struct InviteCodeCard: View {
    let inviteCode: String
    let onCopy: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.fire(.selection)
            onCopy()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.xxs) {
                    Text(L10n.tr("settings.inviteCode.prefix"))
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppSemanticColor.textSecondary)
                    Text(inviteCode)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppSemanticColor.primary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "doc.on.doc")
                    .font(.system(size: AppIconSize.sm - 1, weight: .semibold))
                    .foregroundStyle(AppSemanticColor.primary)
            }
            .frame(maxWidth: .infinity, minHeight: AppDimension.minTouchTarget, alignment: .leading)
            .padding(AppInset.card)
        }
        .buttonStyle(InviteCodeCardStyle())
        .accessibilityLabel(L10n.tr("Copy invite code"))
    }
}

private struct InviteCodeCardStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed
                    ? AppSemanticColor.surfaceSecondary
                    : AppSemanticColor.surface,
                in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
            .animation(reduceMotion ? nil : AppMotion.press, value: configuration.isPressed)
    }
}
