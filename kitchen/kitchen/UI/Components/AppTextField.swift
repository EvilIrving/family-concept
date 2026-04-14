import SwiftUI

enum AppTextFieldChrome {
    /// 圆角底 + 描边（校验反馈），用于表单独立输入框。
    case card
    /// 仅输入内容层，用于嵌入搜索条等外层已有背景的场景。
    case inline
}

/// 全宽输入框：底层使用原生 `TextField`；`.card` 时在可视灰底外再外扩一圈命中区（默认上下各 8pt、左右各 4pt），便于点边缘与上下空白处聚焦。
struct AppTextField<Field: Hashable>: View {
    let title: String
    @Binding var text: String
    var focusedField: FocusState<Field?>.Binding
    let field: Field

    var height: CGFloat = 52
    var chrome: AppTextFieldChrome = .card
    /// 在 `.card` 下扩大输入区域相对可视框的点击范围（外扩，不放大灰底与描边）。
    var focusHitOutsetVertical: CGFloat = AppSpacing.xs
    var focusHitOutsetHorizontal: CGFloat = AppSpacing.xxs
    var autocapitalization: TextInputAutocapitalization = .never
    var autocorrectionDisabled: Bool = true
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)?
    var isInvalid: Bool = false
    var validationTrigger: Int = 0

    private var prompt: Text {
        Text(title)
            .foregroundStyle(AppColor.textTertiary)
    }

    private var fieldContent: some View {
        TextField("", text: $text, prompt: prompt)
            .focused(focusedField, equals: field)
            .font(AppTypography.body)
            .foregroundStyle(AppColor.textPrimary)
            .tint(AppColor.green800)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled(autocorrectionDisabled)
            .submitLabel(submitLabel)
            .onSubmit {
                onSubmit?()
            }
    }

    var body: some View {
        switch chrome {
        case .card:
            ZStack(alignment: .center) {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .fill(AppColor.surfaceSecondary)
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
                    .allowsHitTesting(false)
                    .appValidationFeedback(isInvalid: isInvalid, trigger: validationTrigger)

                fieldContent
                    .padding(.horizontal, AppSpacing.md)
                    .frame(maxWidth: .infinity, minHeight: height)
                    .padding(.vertical, focusHitOutsetVertical)
                    .padding(.horizontal, focusHitOutsetHorizontal)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField.wrappedValue = field
            }
        case .inline:
            fieldContent
                .frame(maxWidth: .infinity, minHeight: height)
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField.wrappedValue = field
                }
        }
    }
}
