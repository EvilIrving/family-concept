import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var inviteCode = ""
    @State private var kitchenName = ""
    @State private var showsCreateForm = false

    var body: some View {
        AppScrollPage {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("私厨")
                    .font(AppTypography.pageTitle)
                    .foregroundStyle(AppColor.textOnBrand)
                Text("加入现有厨房，或在一分钟内创建自己的厨房空间。")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textOnBrand.opacity(0.88))

                HStack(spacing: AppSpacing.xs) {
                    AppPill(title: "操作直接", tint: AppColor.green900, background: AppColor.green300.opacity(0.95))
                    AppPill(title: "反馈即时", tint: AppColor.green900, background: AppColor.green300.opacity(0.95))
                }
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [AppColor.green900, AppColor.green800, AppColor.green500],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: AppRadius.xxl, style: .continuous)
            )
        } content: {
            AppCard {
                AppSectionHeader(eyebrow: "入驻", title: "输入邀请码", detail: "输入后直接进入现有厨房。")
                appTextField("邀请码", text: $inviteCode)
                    .textInputAutocapitalization(.characters)
                AppButton(title: "立即加入", systemImage: "arrow.right") {
                    store.joinKitchen(inviteCode: inviteCode)
                }
            }

            AppCard {
                AppSectionHeader(eyebrow: "创建", title: "新建我的厨房", detail: "如果你是第一次使用，可以先创建自己的厨房。")
                if showsCreateForm {
                    appTextField("厨房名称", text: $kitchenName)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    AppButton(title: "创建并进入", systemImage: "sparkles") {
                        store.createKitchen(named: kitchenName)
                    }
                } else {
                    AppButton(title: "展开创建表单", style: .secondary) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showsCreateForm = true
                        }
                    }
                }
            }
        }
    }

    private func appTextField(_ title: String, text: Binding<String>) -> some View {
        TextField(title, text: text)
            .font(AppTypography.body)
            .foregroundStyle(AppColor.textPrimary)
            .padding(.horizontal, AppSpacing.md)
            .frame(height: 52)
            .background(AppColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(AppColor.lineSoft, lineWidth: 1)
            }
    }
}
