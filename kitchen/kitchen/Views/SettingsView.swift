import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var notificationsEnabled = true
    @State private var hapticsEnabled = true
    @State private var showMembersSheet = false
    @State private var isEditingName = false
    @State private var nameInput = ""

    var body: some View {
        AppScrollPage {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("设置")
                    .font(AppTypography.pageTitle)
                    .foregroundStyle(AppColor.textPrimary)
            }
        } content: {
            if let kitchen = store.kitchen {
                AppCard {
                    AppSectionHeader(eyebrow: "厨房", title: kitchen.name)
                    AppPill(title: "邀请码 \(kitchen.inviteCode)", tint: AppColor.green800, background: AppColor.green100)
                    Divider()
                        .overlay(AppColor.lineSoft)
                    displayNameRow
                    Divider()
                        .overlay(AppColor.lineSoft)
                    Button {
                        showMembersSheet = true
                    } label: {
                        HStack {
                            Text("成员管理")
                                .font(AppTypography.bodyStrong)
                                .foregroundStyle(AppColor.textPrimary)
                            Spacer()
                            Text("\(store.members.count) 人")
                                .font(AppTypography.body)
                                .foregroundStyle(AppColor.textSecondary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColor.textTertiary)
                        }
                        .frame(height: 28)
                    }
                }
                .sheet(isPresented: $showMembersSheet) {
                    MembersSheetView()
                        .environmentObject(store)
                }
            }

            AppCard {
                AppSectionHeader(eyebrow: "基础设置", title: "界面偏好")
                toggleRow(title: "消息通知", isOn: $notificationsEnabled)
                Divider()
                    .overlay(AppColor.lineSoft)
                row(title: "多语言", value: "简体中文")
                Divider()
                    .overlay(AppColor.lineSoft)
                toggleRow(title: "震动反馈", isOn: $hapticsEnabled)
            }

        }
    }

    @ViewBuilder
    private var displayNameRow: some View {
        if isEditingName {
            HStack(spacing: AppSpacing.sm) {
                TextField("你的名字", text: $nameInput)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .frame(height: 28)
                Button("完成") {
                    let trimmed = nameInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty, let id = store.currentMember?.id {
                        store.updateDisplayName(memberID: id, name: trimmed)
                        UserDefaults.standard.set(trimmed, forKey: "displayName")
                    }
                    isEditingName = false
                }
                .font(AppTypography.body)
                .foregroundStyle(AppColor.green700)
            }
        } else {
            Button {
                nameInput = store.currentMember?.displayName ?? store.storedDisplayName
                isEditingName = true
            } label: {
                HStack {
                    Text("我的名字")
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                    Text(store.currentMember?.displayName ?? store.storedDisplayName)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.textSecondary)
                    Image(systemName: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColor.textTertiary)
                }
                .frame(height: 28)
            }
        }
    }

    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            HStack(spacing: AppSpacing.xs) {
                Text(value)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColor.textTertiary)
            }
        }
        .frame(height: 28)
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
        .frame(height: 28)
    }
}

private struct MembersSheetView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.members) { member in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: AppSpacing.xs) {
                                Text(member.displayName)
                                    .font(AppTypography.bodyStrong)
                                    .foregroundStyle(AppColor.textPrimary)
                                if member.id == store.currentDeviceID {
                                    Text("本机")
                                        .font(.caption2)
                                        .foregroundStyle(AppColor.green700)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppColor.green100)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        Spacer()
                        Text(member.role.title)
                            .font(AppTypography.body)
                            .foregroundStyle(member.role == .owner ? AppColor.green700 : AppColor.textSecondary)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if store.isOwner && member.id != store.currentDeviceID {
                            if member.role == .member {
                                Button("设为管理员") {
                                    store.updateRole(memberID: member.id, to: .owner)
                                }
                                .tint(AppColor.green700)
                            } else {
                                Button("降为成员") {
                                    store.updateRole(memberID: member.id, to: .member)
                                }
                                .tint(AppColor.textSecondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("成员管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                        .foregroundStyle(AppColor.green700)
                }
            }
        }
    }
}
