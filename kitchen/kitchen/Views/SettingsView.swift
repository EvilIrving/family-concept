import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var notificationsEnabled = true
    @State private var hapticsEnabled = true

    var body: some View {
        AppScrollPage {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("设置")
                    .font(AppTypography.pageTitle)
                    .foregroundStyle(AppColor.textPrimary)
                Text("把厨房信息、身份信息和基础偏好收拢进卡片。")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textSecondary)
            }
        } content: {
            if let kitchen = store.kitchen {
                AppCard {
                    AppSectionHeader(eyebrow: "厨房", title: kitchen.name, detail: "邀请码可直接分享给新的家庭成员。")
                    AppPill(title: "邀请码 \(kitchen.inviteCode)", tint: AppColor.green800, background: AppColor.green100)
                }
            }

            AppCard {
                AppSectionHeader(eyebrow: "成员", title: "当前身份", detail: "当前示例以本地演示数据驱动。")
                row(title: store.currentUser.name, value: store.currentUser.role.title)
            }

            AppCard {
                AppSectionHeader(eyebrow: "基础设置", title: "界面偏好", detail: "采用卡片化设置项，而不是默认表单风格。")
                toggleRow(title: "消息通知", isOn: $notificationsEnabled)
                Divider()
                    .overlay(AppColor.lineSoft)
                row(title: "多语言", value: "简体中文")
                Divider()
                    .overlay(AppColor.lineSoft)
                toggleRow(title: "震动反馈", isOn: $hapticsEnabled)
            }

            AppCard {
                AppSectionHeader(eyebrow: "说明", title: "当前实现范围", detail: "已覆盖入驻、菜单、订单、设置四个主页面，以及自定义按钮、卡片、toast、sheet 和底部导航。")
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
