import SwiftUI

/// Onboarding 提交按钮条
struct OnboardingSubmitBar: View {
    @Binding var isSubmitting: Bool
    let buttonTitle: String
    let onSubmit: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            AppButton(title: buttonTitle) {
                onSubmit()
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.md)
        .background(.regularMaterial)
    }
}
