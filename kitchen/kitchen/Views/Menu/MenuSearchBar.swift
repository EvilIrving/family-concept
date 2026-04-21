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
                    Button {
                        searchText = ""
                        focusedField = .search
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppSemanticColor.textTertiary)
                    }
                    .buttonStyle(.plain)
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
                Button {
                    onAddDish()
                } label: {
                    HStack(spacing: AppGap.tight) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: AppIconSize.lg, weight: .semibold))
                        Text("新增")
                            .font(AppTypography.bodyStrong)
                    }
                    .foregroundStyle(AppSemanticColor.primary)
                    .padding(.horizontal, AppSpacing.xs)
                    .frame(height: AppDimension.barControlHeight)
                }
                .buttonStyle(.plain)
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
                    Button {
                        selection = category
                    } label: {
                        Text(category)
                            .font(AppTypography.micro)
                            .foregroundStyle(selection == category ? AppSemanticColor.onPrimary : AppSemanticColor.primary)
                            .padding(.horizontal, AppSpacing.sm)
                            .frame(height: AppDimension.compactPillHeight)
                            .background(
                                selection == category ? AppSemanticColor.primary : AppSemanticColor.interactiveSecondary,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
