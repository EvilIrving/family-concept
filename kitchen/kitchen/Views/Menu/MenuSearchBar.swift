import SwiftUI

struct MenuSearchBar: View {
    @Binding var searchText: String
    @FocusState.Binding var focusedField: MenuField?
    let canManageDishes: Bool
    let onAddDish: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppSemanticColor.textTertiary)

                AppTextField(
                    title: "搜菜名",
                    text: $searchText,
                    focusedField: $focusedField,
                    field: .search,
                    height: 50,
                    chrome: .inline,
                    autocapitalization: .never,
                    autocorrectionDisabled: true,
                    submitLabel: .search,
                    onSubmit: nil,
                    isInvalid: false,
                    validationTrigger: 0
                )

                if !searchText.isEmpty {
                    AppIconActionButton(systemImage: "xmark.circle.fill", tone: .neutral, size: .sm) {
                        searchText = ""
                        focusedField = .search
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .frame(height: AppDimension.barControlHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppSemanticColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(AppSemanticColor.border, lineWidth: AppBorderWidth.hairline)
                    .allowsHitTesting(false)
            }

            if canManageDishes {
                AppButton(title: "新增", leadingIcon: "plus.circle.fill", role: .ghost, size: .sm, fullWidth: false) {
                    onAddDish()
                }
                .accessibilityLabel("新增菜品")
            }
        }
    }
}

struct MenuCategoryChips: View {
    let categories: [String]
    @Binding var selection: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(categories, id: \.self) { category in
                    AppChipButton(
                        title: category,
                        isSelected: selection == category
                    ) {
                        selection = category
                    }
                }
            }
        }
    }
}
