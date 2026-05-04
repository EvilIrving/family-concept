import SwiftUI

struct KitchenSummaryCard: View {
    @EnvironmentObject private var store: AppStore
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
                            Text(L10n.tr("%lld members", Int64(store.members.count)))
                                .font(AppTypography.caption)
                                .foregroundStyle(AppSemanticColor.textSecondary)
                        }
                    }

                    MemberAvatarStrip(
                        members: store.members,
                        currentAccountID: store.currentAccount?.id,
                        onMemberTap: onMemberTap
                    )
                }
            }
        }
    }
}
