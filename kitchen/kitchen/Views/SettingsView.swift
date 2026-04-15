import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var notificationsEnabled = true
    @State private var hapticsEnabled = true
    @State private var toast: AppToastData?
    @StateObject private var modalRouter = ModalRouter<SettingsModalRoute>()

    var body: some View {
        AppScrollPage {
            EmptyView()
        } content: {
            if let kitchen = store.kitchen {
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                                Text(kitchen.name)
                                    .font(AppTypography.sectionTitle)
                                    .foregroundStyle(AppColor.textPrimary)
                                Spacer()
                                Text("共 \(store.members.count) 人")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColor.textSecondary)
                            }

                            kitchenIdentityCluster

                            Button {
                                UIPasteboard.general.string = kitchen.inviteCode
                                toast = AppToastData(message: "已复制邀请码")
                            } label: {
                                HStack(spacing: AppSpacing.sm) {
                                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                        Text("邀请码")
                                            .font(AppTypography.micro)
                                            .foregroundStyle(AppColor.textSecondary)
                                        Text(kitchen.inviteCode)
                                            .font(AppTypography.bodyStrong)
                                            .foregroundStyle(AppColor.green800)
                                    }
                                    Spacer()
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(AppColor.green800)
                                }
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                                .background(AppColor.green100, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("复制邀请码")
                        }
                    }
                }
            }

            AppCard {
                AppSectionHeader(title: "偏好")
                toggleRow(title: "消息通知", isOn: $notificationsEnabled)
                rowDivider
                placeholderRow(title: "多语言", value: "简体中文")
                rowDivider
                placeholderRow(title: "主题色", value: "默认绿色")
                rowDivider
                toggleRow(title: "震动反馈", isOn: $hapticsEnabled)
            }

            AppCard {
                Button {
                    Task { await store.signOut() }
                } label: {
                    HStack {
                        Text("退出登录")
                            .font(AppTypography.bodyStrong)
                            .foregroundStyle(AppColor.danger)
                        Spacer()
                    }
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
        }
        .appToast($toast)
        .sheet(item: memberSheetBinding, onDismiss: { modalRouter.didDismissCurrent() }) { token in
            MemberRoleSheet(memberAccountID: token.accountID)
                .environmentObject(store)
                .presentationBackground(.clear)
                .presentationDetents([.fraction(0.25)])
                .presentationDragIndicator(.hidden)
        }
    }

    private var kitchenIdentityCluster: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if let nickName = store.currentMember?.nickName {
                Text("当前：\(nickName)")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -14) {
                    ForEach(Array(store.members.enumerated()), id: \.element.id) { index, member in
                        memberAvatarButton(member, colorIndex: index)
                            .zIndex(Double(index))
                    }
                }
                .padding(.leading, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xxs)
                .padding(.trailing, AppSpacing.xs)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(
                store.members.count > 6
                    ? "厨房成员，共 \(store.members.count) 人，横向滑动可查看全部"
                    : "厨房成员，共 \(store.members.count) 人"
            )

            if store.members.count > 6 {
                Text("共 \(store.members.count) 人，左滑可查看其余成员")
                    .font(AppTypography.micro)
                    .foregroundStyle(AppColor.textTertiary)
            }
        }
    }

    private func memberAvatarButton(_ member: Member, colorIndex: Int) -> some View {
        let colors: [Color] = [
            AppColor.green200,
            AppColor.surfaceSecondary,
            AppColor.green100,
            AppColor.green300,
            AppColor.surfaceTertiary,
            AppColor.successSoft
        ]

        let isCurrentAccount = member.accountId == store.currentAccount?.id
        let initials = String(member.nickName.prefix(1))

        return Button {
            modalRouter.present(.member(MemberSheetToken(accountID: member.accountId)))
        } label: {
            ZStack {
                Circle()
                    .fill(colors[colorIndex % colors.count])
                    .overlay(
                        Circle()
                            .stroke(AppColor.surfacePrimary, lineWidth: 2)
                    )
                    .overlay(
                        Circle()
                            .stroke(isCurrentAccount ? AppColor.green700 : AppColor.lineSoft, lineWidth: isCurrentAccount ? 2 : 1)
                    )

                Text(initials)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(isCurrentAccount ? AppColor.green800 : AppColor.textPrimary)
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .shadow(color: AppColor.green900.opacity(0.06), radius: 1, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(member.nickName)，\(member.role.title)")
    }

    private var rowDivider: some View {
        Divider()
            .overlay(AppColor.lineSoft)
    }

    private func placeholderRow(title: String, value: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            Text(value)
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColor.textTertiary)
        }
        .frame(minHeight: 44)
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(AppColor.green700)
                .labelsHidden()
        }
        .frame(minHeight: 44)
    }

    private var memberSheetBinding: Binding<MemberSheetToken?> {
        Binding(
            get: {
                if case .member(let token) = modalRouter.current {
                    return token
                }
                return nil
            },
            set: { token in
                if let token {
                    modalRouter.present(.member(token))
                } else if case .member = modalRouter.current {
                    modalRouter.dismiss()
                }
            }
        )
    }
}

private struct MemberSheetToken: Identifiable {
    let accountID: String
    var id: String { accountID }
}

private enum SettingsModalRoute: Identifiable {
    case member(MemberSheetToken)

    var id: String {
        switch self {
        case .member(let token):
            return token.id
        }
    }
}

private struct MemberRoleSheet: View {
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
                                .fill(AppColor.green200)
                                .overlay(
                                    Circle()
                                        .stroke(AppColor.surfacePrimary, lineWidth: 2)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(isSelf ? AppColor.green700 : AppColor.lineSoft, lineWidth: isSelf ? 2 : 1)
                                )
                            Text(String(member.nickName.prefix(1)))
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(isSelf ? AppColor.green800 : AppColor.textPrimary)
                        }
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                            Text(member.nickName)
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(AppColor.textPrimary)
                                .lineLimit(1)
                            Text("权限：\(member.role.title)")
                                .font(AppTypography.micro)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        Spacer(minLength: 0)
                    }

                    if isSelf {
                        Text("这是我的账号")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                } else {
                    Text("成员已不在列表中")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
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
                                .font(.system(size: 14, weight: .semibold))
                            Text("移除成员")
                        }
                        .font(AppTypography.button)
                        .foregroundStyle(AppColor.danger)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppColor.dangerSoft)
                    .padding(.top, AppSpacing.xs)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppStore())
}
