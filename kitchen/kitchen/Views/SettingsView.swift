import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var feedbackRouter: AppFeedbackRouter
    @State private var notificationsEnabled = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("themeMode") private var themeMode = "system"
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
                                    .foregroundStyle(AppSemanticColor.textPrimary)
                                Spacer()
                                Text("共 \(store.members.count) 人")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppSemanticColor.textSecondary)
                            }

                            kitchenIdentityCluster

                            Button {
                                UIPasteboard.general.string = kitchen.inviteCode
                                feedbackRouter.show(.low(message: "已复制邀请码"), hint: .centerToast)
                            } label: {
                                HStack(spacing: AppSpacing.sm) {
                                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                        Text("邀请码")
                                            .font(AppTypography.micro)
                                            .foregroundStyle(AppSemanticColor.textSecondary)
                                        Text(kitchen.inviteCode)
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
                }
            }

            AppCard {
                AppSectionHeader(title: "偏好")
                toggleRow(title: "消息通知", isOn: $notificationsEnabled)
                rowDivider
                toggleRow(title: "震动反馈", isOn: $hapticsEnabled)
                rowDivider
                placeholderRow(title: "多语言", value: "简体中文")
                rowDivider
                themeSelectionRow
            }

//            AppCard {
                AppButton(title: "退出登录", style: .destructive) {
                    Task { await store.signOut() }
                }
//            }
        }
        .sheet(item: modalRouteBinding, onDismiss: { modalRouter.handleDismissedCurrent() }) { route in
            MemberRoleSheet(memberAccountID: route.token.accountID)
                .environmentObject(store)
                .presentationBackground(.clear)
                .presentationDetents([.fraction(0.25)])
                .presentationDragIndicator(.hidden)
        }
    }

    private var kitchenIdentityCluster: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
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
                    .foregroundStyle(AppSemanticColor.textTertiary)
            }
        }
    }

    private func memberAvatarButton(_ member: Member, colorIndex: Int) -> some View {
        let colors: [Color] = [
            AppSemanticColor.interactiveSecondaryPressed,
            AppSemanticColor.surfaceSecondary,
            AppSemanticColor.interactiveSecondary,
            AppSemanticColor.toastAccent,
            AppSemanticColor.surfaceTertiary,
            AppSemanticColor.successBackground
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
                            .stroke(AppSemanticColor.surface, lineWidth: 2)
                    )
                    .overlay(
                        Circle()
                            .stroke(isCurrentAccount ? AppSemanticColor.brandAccent : AppSemanticColor.border, lineWidth: isCurrentAccount ? 2 : 1)
                    )

                Text(initials)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(isCurrentAccount ? AppSemanticColor.primary : AppSemanticColor.textPrimary)
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
            .shadow(color: AppSemanticColor.shadowSubtle, radius: 1, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(member.nickName)，\(member.role.title)")
    }

    private var rowDivider: some View {
        Divider()
            .overlay(AppSemanticColor.border)
    }

    private var themeSelectionRow: some View {
        HStack(spacing: AppSpacing.sm) {
            Text("主题")
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textPrimary)
            Spacer()
            Menu {
                Button {
                    themeMode = "light"
                    store.setThemeMode("light")
                } label: {
                    HStack {
                        Text("浅色")
                        if themeMode == "light" {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button {
                    themeMode = "system"
                    store.setThemeMode("system")
                } label: {
                    HStack {
                        Text("系统")
                        if themeMode == "system" {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Button {
                    themeMode = "dark"
                    store.setThemeMode("dark")
                } label: {
                    HStack {
                        Text("深色")
                        if themeMode == "dark" {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Text(themeDisplayName)
                        .font(AppTypography.body)
                        .foregroundStyle(AppSemanticColor.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: AppIconSize.xs, weight: .semibold))
                        .foregroundStyle(AppSemanticColor.textTertiary)
                }
            }
        }
        .frame(minHeight: 44)
    }

    private var themeDisplayName: String {
        switch themeMode {
        case "light":
            return "浅色"
        case "dark":
            return "深色"
        default:
            return "系统"
        }
    }

    private func placeholderRow(title: String, value: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textPrimary)
            Spacer()
            Text(value)
                .font(AppTypography.body)
                .foregroundStyle(AppSemanticColor.textSecondary)
            Image(systemName: "chevron.right")
                .font(.system(size: AppIconSize.xs, weight: .semibold))
                .foregroundStyle(AppSemanticColor.textTertiary)
        }
        .frame(minHeight: 44)
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textPrimary)
            Spacer()
            Toggle("", isOn: isOn)
                .tint(AppSemanticColor.brandAccent)
                .labelsHidden()
        }
        .frame(minHeight: 44)
    }

    private var modalRouteBinding: Binding<SettingsModalRoute?> {
        Binding(
            get: { modalRouter.current },
            set: { route in
                if let route {
                    modalRouter.present(route)
                } else {
                    modalRouter.dismiss()
                }
            }
        )
    }
}

private struct MemberSheetToken: Identifiable, Equatable {
    let accountID: String
    var id: String { accountID }
}

private enum SettingsModalRoute: Identifiable, Equatable {
    case member(MemberSheetToken)

    var id: String {
        switch self {
        case .member(let token):
            return token.id
        }
    }

    var token: MemberSheetToken {
        switch self {
        case .member(let token):
            return token
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

#Preview {
    SettingsView()
        .environmentObject(AppStore())
}
