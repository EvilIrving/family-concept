import SwiftUI

struct InviteCodeMenuRow: View {
    let inviteCode: String
    let onCopy: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(L10n.tr("settings.inviteCode.prefix"))
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textPrimary)
            Text(inviteCode)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.primary)
                .lineLimit(1)
            Spacer()
            Text(L10n.tr("Copy"))
                .font(AppTypography.caption)
                .foregroundStyle(AppSemanticColor.textSecondary)
        }
        .frame(minHeight: AppDimension.listRowMinHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.shared.fire(.selection)
            onCopy()
        }
        .accessibilityLabel(L10n.tr("Copy invite code"))
        .overlay(alignment: .bottom) {
            Divider()
                .overlay(AppSemanticColor.border)
        }
    }
}
