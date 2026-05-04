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
                    title: L10n.tr("Search dishes"),
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
            .background(AppSemanticColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                    .stroke(AppSemanticColor.border, lineWidth: 1)
                    .allowsHitTesting(false)
            }

            if canManageDishes {
                AppButton(title: L10n.tr("Add"), role: .ghost, size: .md, fullWidth: false) {
                    onAddDish()
                }
                .accessibilityLabel(L10n.tr("Add Dish"))
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
                        title: category == "All" ? L10n.tr("All") : category,
                        isSelected: selection == category
                    ) {
                        selection = category
                    }
                }
            }
        }
    }
}
