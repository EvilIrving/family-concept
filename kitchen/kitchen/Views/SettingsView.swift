import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var notificationsEnabled = true
    @State private var hapticsEnabled = true
    @State private var toast: AppToastData?

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
                                Text("\(store.members.count) 人")
                                    .font(AppTypography.caption)
                                    .foregroundStyle(AppColor.textSecondary)
                                Spacer()
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
        }
        .appToast($toast)
    }

    private var kitchenIdentityCluster: some View {
        HStack(alignment: .center, spacing: AppSpacing.md) {
            ZStack {
                ForEach(Array(store.members.prefix(3).enumerated()), id: \.element.id) { index, member in
                    memberBubble(member, index: index)
                }
            }
            .frame(width: 124, height: 78, alignment: .leading)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                if displayNameForIdentity != "本机" {
                    Text(displayNameForIdentity)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppColor.textPrimary)
                }
            }
            Spacer()
        }
    }

    private var displayNameForIdentity: String {
        store.currentMember?.displayName ?? store.storedDisplayName
    }

    private func memberBubble(_ member: Member, index: Int) -> some View {
        let offsets: [CGSize] = [
            CGSize(width: 0, height: 18),
            CGSize(width: 32, height: 0),
            CGSize(width: 64, height: 16)
        ]
        let colors: [Color] = [AppColor.green200, AppColor.surfaceSecondary, AppColor.green100]
        let initials = String(member.displayName.prefix(1))

        return ZStack {
            Circle()
                .fill(colors[index % colors.count])
                .overlay(
                    Circle()
                        .stroke(member.id == store.currentDeviceID ? AppColor.green700 : AppColor.lineSoft, lineWidth: member.id == store.currentDeviceID ? 2 : 1)
                )

            Text(initials)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(member.id == store.currentDeviceID ? AppColor.green800 : AppColor.textPrimary)
        }
        .frame(width: 54, height: 54)
        .offset(offsets[index % offsets.count])
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
}

#Preview {
    SettingsView()
        .environmentObject(AppStore())
}
