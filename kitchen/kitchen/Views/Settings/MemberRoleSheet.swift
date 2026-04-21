import SwiftUI

/// 成员角色 Sheet 组件
struct MemberRoleSheet: View {
    let memberAccountID: String
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    private var member: Member? {
        store.members.first { $0.accountId == memberAccountID }
    }

    private var isSelf: Bool {
        memberAccountID == store.currentAccount?.id
    }

    var body: some View {
        AppSheetContainer(title: "成员", dismissTitle: "关闭", onDismiss: { dismiss() }) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                if let member {
                    HStack(alignment: .center, spacing: AppSpacing.sm) {
                        ZStack {
                            Circle()
                                .fill(AppSemanticColor.interactiveSecondaryPressed)
                                .overlay(
                                    Circle()
                                        .stroke(AppSemanticColor.surface, lineWidth: 2)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(isSelf ? AppSemanticColor.brandAccent : AppSemanticColor.border, lineWidth: isSelf ? 2 : 1)
                                )
                            Text(String(member.nickName.prefix(1)))
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(isSelf ? AppSemanticColor.primary : AppSemanticColor.textPrimary)
                        }
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(member.nickName)
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(AppSemanticColor.textPrimary)
                                .lineLimit(1)
                            Text("权限：\(member.role.title)")
                                .font(AppTypography.micro)
                                .foregroundStyle(AppSemanticColor.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }

                    if isSelf {
                        Text("这是我的账号")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppSemanticColor.textTertiary)
                    }
                } else {
                    Text("成员已不在列表中")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppSemanticColor.textSecondary)
                }

                if store.isOwner && !isSelf, let member {
                    Button {
                        Task {
                            await store.removeMember(accountID: member.accountId)
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "person.badge.minus")
                                .font(.system(size: AppIconSize.sm, weight: .semibold))
                            Text("移除成员")
                        }
                        .font(AppTypography.button)
                        .foregroundStyle(AppSemanticColor.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppSemanticColor.dangerBackground)
                    .padding(.top, AppSpacing.xs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
