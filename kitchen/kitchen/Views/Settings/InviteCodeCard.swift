import SwiftUI

/// 邀请码卡片组件
struct InviteCodeCard: View {
    let inviteCode: String
    let onCopy: () -> Void

    var body: some View {
        AppRowButton(action: {
            onCopy()
        }, accessory: .custom(AnyView(
            Image(systemName: "doc.on.doc")
                .font(.system(size: AppIconSize.sm - 1, weight: .semibold))
                .foregroundStyle(AppSemanticColor.primary)
        ))) {
            HStack(spacing: AppSpacing.xxs) {
                Text("邀请码：")
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppSemanticColor.textSecondary)
                Text(inviteCode)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppSemanticColor.primary)
                Spacer()
            }
        }
        .accessibilityLabel("复制邀请码")
    }
}
