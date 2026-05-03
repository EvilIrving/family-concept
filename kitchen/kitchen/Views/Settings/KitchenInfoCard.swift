import SwiftUI

/// 厨房信息卡片组件
struct KitchenInfoCard: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    let onMemberTap: (Member) -> Void

    private var kitchen: Kitchen? {
        store.kitchen
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                        if let kitchen {
                            Text(kitchen.name)
                                .font(AppTypography.sectionTitle)
                                .foregroundStyle(AppSemanticColor.textPrimary)
                        }
                        Spacer()
                        if kitchen != nil {
                            Text(L10n.tr("共 %lld 人", Int64(store.members.count)))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppSemanticColor.textSecondary)
                        }
                    }

                    MemberAvatarStrip(
                        members: store.members,
                        currentAccountID: store.currentAccount?.id,
                        onMemberTap: onMemberTap
                    )

                    if let kitchen {
                        InviteCodeCard(
                            inviteCode: kitchen.inviteCode,
                            onCopy: {
                                UIPasteboard.general.string = kitchen.inviteCode
                                feedbackRouter.show(AppFeedback.low(message: L10n.tr("已复制邀请码")), hint: .centerToast)
                            }
                        )
                    }
                }
            }
        }
    }
}
