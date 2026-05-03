import SwiftUI

/// 成员角色 Sheet 组件
struct MemberRoleSheet: View {
    let memberAccountID: String
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @Environment(\.dismiss) private var dismiss
    @State private var pendingAction: PendingAction?

    private enum PendingAction { case role, remove }

    private var member: Member? {
        store.members.first { $0.accountId == memberAccountID }
    }

    private var isSelf: Bool {
        memberAccountID == store.currentAccount?.id
    }

    private var canEditRole: Bool {
        store.isOwner && !isSelf && member?.role != .owner
    }

    private var roleActionTitle: String {
        member?.role == .admin ? L10n.tr("改为成员") : L10n.tr("设为副管理员")
    }

    private var roleActionTarget: KitchenRole {
        member?.role == .admin ? .member : .admin
    }

    private var hasActions: Bool {
        guard member != nil, store.isOwner, !isSelf else { return false }
        return true
    }

    var body: some View {
        AppSheetContainer(title: L10n.tr("成员"), dismissTitle: L10n.tr("关闭"), onDismiss: { dismiss() }) {
            if let member {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    memberHeader(member)
                    if hasActions {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            if canEditRole { roleButton(member) }
                            removeButton(member)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            } else {
                Text("该成员已不在私厨中")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, AppSpacing.lg)
            }
        }
    }

    @ViewBuilder
    private func memberHeader(_ member: Member) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            Circle()
                .fill(AppSemanticColor.interactiveSecondaryPressed)
                .overlay(
                    Text(String(member.nickName.prefix(1)))
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppSemanticColor.textPrimary)
                )
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(member.nickName)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(AppSemanticColor.textPrimary)
                    .lineLimit(1)
                Text(isSelf ? L10n.tr("这是我的账号 · %@", member.role.title) : L10n.tr("权限：%@", member.role.title))
                    .font(AppTypography.micro)
                    .foregroundStyle(AppSemanticColor.textSecondary)
            }
            Spacer(minLength: 0)
        }
    }

    private func roleButton(_ member: Member) -> some View {
        let title = roleActionTitle
        return AppButton(
            title: title,
            leadingIcon: member.role == .admin ? "person.badge.key" : "person.badge.shield.checkmark",
            role: .secondary,
            phase: pendingAction == .role ? .initialLoading(label: title) : .idle
        ) {
            run(.role, successMessage: L10n.tr("已%@", title), failureFallback: L10n.tr("%@失败，请稍后重试", title)) {
                await store.updateMemberRole(accountID: member.accountId, role: roleActionTarget)
            }
        }
        .disabled(pendingAction != nil)
    }

    private func removeButton(_ member: Member) -> some View {
        AppButton(
            title: L10n.tr("移除成员"),
            leadingIcon: "person.badge.minus",
            role: .destructive,
            phase: pendingAction == .remove ? .initialLoading(label: L10n.tr("移除成员")) : .idle
        ) {
            run(.remove, successMessage: L10n.tr("已移除成员"), failureFallback: L10n.tr("移除成员失败，请稍后重试"), dismissOnSuccess: true) {
                await store.removeMember(accountID: member.accountId)
            }
        }
        .disabled(pendingAction != nil)
    }

    private func run(
        _ action: PendingAction,
        successMessage: String,
        failureFallback: String,
        dismissOnSuccess: Bool = false,
        operation: @escaping () async -> Bool
    ) {
        Task {
            pendingAction = action
            let success = await operation()
            pendingAction = nil

            if success {
                feedbackRouter.show(.high(message: successMessage), hint: .centerToast)
                if dismissOnSuccess { dismiss() }
            } else {
                feedbackRouter.show(
                    .low(
                        message: store.error ?? failureFallback,
                        systemImage: "xmark.octagon.fill"
                    ),
                    hint: .centerToast
                )
            }
        }
    }
}
