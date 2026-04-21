import SwiftUI

/// 私厨表单组件（加入/创建）
struct KitchenForm: View {
    @Binding var kitchenInput: String
    @Binding var kitchenMode: KitchenMode

    @Binding var kitchenInputInvalid: Bool
    @Binding var kitchenInputShake: Int

    @FocusState.Binding var focusedField: OnboardingField?

    let onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            AppTextField(
                title: kitchenMode == .join ? "邀请码" : "私厨名称",
                text: $kitchenInput,
                focusedField: $focusedField,
                field: .kitchen,
                autocapitalization: kitchenMode == .join ? .characters : .words,
                submitLabel: .done,
                onSubmit: {
                    focusedField = nil
                    onSubmit()
                },
                isInvalid: kitchenInputInvalid,
                validationTrigger: kitchenInputShake
            )
            .onChange(of: kitchenInput) { _, _ in
                if kitchenInputInvalid { OnboardingValidationHelper.resetValidation(&kitchenInputInvalid) }
            }
        }
    }
}
