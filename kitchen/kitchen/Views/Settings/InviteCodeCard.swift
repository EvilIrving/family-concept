import SwiftUI

/// 邀请码卡片组件
struct InviteCodeCard: View {
    let inviteCode: String
    let onCopy: () -> Void

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("邀请码")
                        .font(AppTypography.micro)
                        .foregroundStyle(AppSemanticColor.textSecondary)
                    Text(inviteCode)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppSemanticColor.primary)
                }
                Spacer()
                Image(systemName: "doc.on.doc")
                    .font(.system(size: AppIconSize.sm - 1, weight: .semibold))
                    .foregroundStyle(AppSemanticColor.primary)
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(AppSemanticColor.interactiveSecondary, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("复制邀请码")
    }
}
