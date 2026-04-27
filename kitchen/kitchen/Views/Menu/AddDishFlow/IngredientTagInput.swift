import SwiftUI

struct IngredientTagInput: View {
    @Binding var tags: [String]
    @Binding var input: String
    var focusedField: FocusState<MenuField?>.Binding
    var isInvalid: Bool = false
    var validationTrigger: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.xs) {
                        ForEach(tags, id: \.self) { tag in
                            AppChipButton(title: tag, role: .removable) {
                                tags.removeAll { $0 == tag }
                            }
                        }
                    }
                }
            }

            AppTextField(
                title: "使用空格添加多个食材",
                text: $input,
                focusedField: focusedField,
                field: .ingredient,
                height: 52,
                chrome: .card,
                autocapitalization: .never,
                autocorrectionDisabled: true,
                submitLabel: .done,
                onSubmit: { commitTag() },
                isInvalid: isInvalid,
                validationTrigger: validationTrigger
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
