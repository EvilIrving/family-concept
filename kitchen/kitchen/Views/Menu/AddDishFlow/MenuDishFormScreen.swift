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
                        validationTrigger: draft.validationTrigger,
                        errorMessage: draft.imageError
                    )

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("常用分类")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppSemanticColor.textSecondary)

                        quickCategoryChips

                        if draft.selectedQuickCategory == "自定义" {
                            formTextField("自定义分类", text: $draft.customCategory, field: .customCategory)
                        }

                        if let categoryError = draft.categoryError {
                            Text(categoryError)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppSemanticColor.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    formTextField("菜名", text: $draft.name, field: .name)

                    if let nameError = draft.nameError {
                        Text(nameError)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppSemanticColor.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    IngredientTagInput(
                        tags: $draft.ingredientTags,
                        input: $draft.ingredientInput,
                        focusedField: focusedField,
                        isInvalid: draft.invalidIngredients,
                        validationTrigger: draft.validationTrigger,
                        errorMessage: draft.ingredientError
                    )

                    if let onDelete {
                        AppButton(
                            title: "删除菜品",
                            style: .destructive,
                            action: {
                                archiveConfirmationPresented = true
                            }
                        )
                        .confirmationDialog(
                            "删除后会归档该菜品",
                            isPresented: $archiveConfirmationPresented,
                            titleVisibility: .visible
                        ) {
                            Button("删除菜品", role: .destructive, action: onDelete)
                            Button("取消", role: .cancel) {}
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
        draft.hasTriedSubmit && !formIsComplete
    }

    private var formIsComplete: Bool {
        draft.trimmedName.isEmpty == false &&
        draft.hasCategory &&
        draft.hasIngredients &&
        (!requiresImage || imageCoordinator.hasImage)
    }

    private var header: some View {
        HStack(alignment: .top) {
            Button("关闭", action: onDismiss)
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
                    Button {
                        draft.selectedQuickCategory = category
                    } label: {
                        Text(category)
                            .font(AppTypography.micro)
                            .foregroundStyle(draft.selectedQuickCategory == category ? AppSemanticColor.onPrimary : AppSemanticColor.primary)
                            .padding(.horizontal, AppSpacing.sm)
                            .frame(height: AppDimension.compactPillHeight)
                            .background(
                                draft.selectedQuickCategory == category ? AppSemanticColor.primary : AppSemanticColor.interactiveSecondary,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
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
