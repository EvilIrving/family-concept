import SwiftUI

/// 私厨模式切换条组件
struct KitchenModeToggle: View {
    @Binding var kitchenMode: KitchenMode
    @Binding var showKitchenField: Bool
    @FocusState.Binding var focusedField: OnboardingField?

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Spacer()
            Button("输入邀请码加入") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    kitchenMode = .join
                    showKitchenField = true
                    focusedField = .kitchen
                }
            }
            .font(AppTypography.caption)
            .foregroundStyle(
                showKitchenField && kitchenMode == .join ? AppSemanticColor.textPrimary : AppSemanticColor.textSecondary
            )

            Text("或")
                .font(AppTypography.caption)
                .foregroundStyle(AppSemanticColor.textSecondary)

            Button("创建私厨") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    kitchenMode = .create
                    showKitchenField = true
                    focusedField = .kitchen
                }
            }
            .font(AppTypography.caption)
            .foregroundStyle(
                showKitchenField && kitchenMode == .create ? AppSemanticColor.textPrimary : AppSemanticColor.textSecondary
            )
        }
    }
}
