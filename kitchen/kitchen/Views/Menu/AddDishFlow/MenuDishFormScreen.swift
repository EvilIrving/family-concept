import SwiftUI

struct MenuDishFormScreen: View {
    let title: String
    let confirmTitle: String
    let requiresImage: Bool
    @Binding var draft: AddDishDraft
    let quickCategories: [String]
    var focusedField: FocusState<MenuField?>.Binding
    @ObservedObject var imageCoordinator: DishImageCoordinator
    @Binding var archiveConfirmationPresented: Bool
    let isSaving: Bool
    let onDismiss: () -> Void
    let onSave: () -> Void
    let onPhotoLibraryRequest: () -> Void
    let onCameraRequest: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    MenuDishFlowImagePickerSection(
                        coordinator: imageCoordinator,
                        onPhotoLibraryRequest: onPhotoLibraryRequest,
                        onCameraRequest: onCameraRequest,
                        isInvalid: draft.invalidImage,
                        validationTrigger: draft.validationTrigger
                    )

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(L10n.tr("Common categories"))
                            .font(AppTypography.micro)
                            .foregroundStyle(AppSemanticColor.textSecondary)

                        quickCategoryChips

                        if draft.selectedQuickCategory == "Custom" {
                            formTextField(L10n.tr("Custom category"), text: $draft.customCategory, field: .customCategory)
                        }
                    }

                    formTextField(L10n.tr("Dish name"), text: $draft.name, field: .name)

                    IngredientTagInput(
                        tags: $draft.ingredientTags,
                        input: $draft.ingredientInput,
                        focusedField: focusedField,
                        isInvalid: draft.invalidIngredients,
                        validationTrigger: draft.validationTrigger
                    )

                    if let onDelete {
                        AppButton(
                            title: L10n.tr("Delete Dish"),
                            role: .destructive,
                            action: {
                                archiveConfirmationPresented = true
                            }
                        )
                        .confirmationDialog(
                            L10n.tr("Deleting will archive this dish"),
                            isPresented: $archiveConfirmationPresented,
                            titleVisibility: .visible
                        ) {
                            Button(L10n.tr("Delete Dish"), role: .destructive, action: onDelete)
                            Button(L10n.tr("Cancel"), role: .cancel) {}
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.bottom, AppSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.never)
        }
        .background(AppSemanticColor.surface)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            draft.resetValidation()
            focusedField.wrappedValue = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                focusedField.wrappedValue = .name
            }
        }
        .task(id: draft.validationTrigger) {
            guard draft.validationTrigger > 0 else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                draft.resetValidation()
            }
        }
    }

    private var isSaveDisabled: Bool {
        isSaving || (draft.hasTriedSubmit && !formIsComplete)
    }

    private var formIsComplete: Bool {
        draft.trimmedName.isEmpty == false &&
        draft.hasCategory &&
        draft.hasIngredients &&
        (!requiresImage || imageCoordinator.hasImage)
    }

    private var header: some View {
        HStack(alignment: .top) {
            Button(L10n.tr("Close"), action: onDismiss)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textSecondary)

            Spacer()

            Text(title)
                .font(AppTypography.cardTitle)
                .foregroundStyle(AppSemanticColor.textPrimary)

            Spacer()

            Button(confirmTitle, action: onSave)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(isSaveDisabled ? AppSemanticColor.textTertiary : AppSemanticColor.primary)
                .disabled(isSaveDisabled)
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.md)
        .padding(.bottom, AppSpacing.md)
    }

    private var quickCategoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(quickCategories, id: \.self) { category in
                    AppChipButton(
                        title: category == "Custom" ? L10n.tr("Custom") : category,
                        isSelected: draft.selectedQuickCategory == category
                    ) {
                        draft.selectedQuickCategory = category
                    }
                }
            }
        }
    }

    private func formTextField(_ title: String, text: Binding<String>, field: MenuField) -> some View {
        AppTextField(
            title: title,
            text: text,
            focusedField: focusedField,
            field: field,
            height: 52,
            chrome: .card,
            autocapitalization: .never,
            autocorrectionDisabled: true,
            submitLabel: .done,
            onSubmit: nil,
            isInvalid: field == .name ? draft.invalidName : draft.invalidCategory,
            validationTrigger: draft.validationTrigger
        )
    }
}
