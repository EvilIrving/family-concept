import SwiftUI

struct IngredientTagInput: View {
    @Binding var tags: [String]
    @Binding var input: String
    var focusedField: FocusState<MenuField?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("食材")
                .font(AppTypography.micro)
                .foregroundStyle(AppColor.textSecondary)

            FlowLayout(spacing: AppSpacing.xs) {
                ForEach(tags, id: \.self) { tag in
                    HStack(spacing: 4) {
                        Text(tag)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.textPrimary)
                        Button {
                            tags.removeAll { $0 == tag }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 6)
                    .background(AppColor.surfaceSecondary, in: Capsule())
                    .overlay(Capsule().stroke(AppColor.lineSoft, lineWidth: 1))
                }
            }

            AppTextField(
                title: "添加食材",
                text: $input,
                focusedField: focusedField,
                field: .ingredient,
                height: 52,
                chrome: .card,
                autocapitalization: .never,
                autocorrectionDisabled: true,
                submitLabel: .done,
                onSubmit: { commitTag() },
                isInvalid: false,
                validationTrigger: 0
            )
            .onChange(of: input) { _, newValue in
                if newValue.last == " " {
                    commitTag()
                }
            }
        }
    }

    private func commitTag() {
        let tag = input.trimmingCharacters(in: .whitespacesAndNewlines)
        input = ""
        if !tag.isEmpty {
            tags.append(tag)
        }
        focusedField.wrappedValue = .ingredient
    }
}
