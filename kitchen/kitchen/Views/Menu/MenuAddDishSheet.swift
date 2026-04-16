import SwiftUI
import PhotosUI

struct MenuAddDishSheet: View {
    @Binding var draft: AddDishDraft
    let quickCategories: [String]
    @Binding var selectedPhotoItem: PhotosPickerItem?
    var focusedField: FocusState<MenuField?>.Binding
    @ObservedObject var imageCoordinator: DishImageCoordinator
    let onDismiss: () -> Void
    let onSave: () -> Void
    let onCameraRequest: () -> Void

    var body: some View {
        AppSheetContainer(
            title: "新增菜品",
            dismissTitle: "关闭",
            confirmTitle: "保存",
            onDismiss: onDismiss,
            onConfirm: onSave,
            isConfirmDisabled: isSaveDisabled
        ) {
            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    MenuDishImagePickerSection(
                        coordinator: imageCoordinator,
                        selectedPhotoItem: $selectedPhotoItem,
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
                            sheetTextField("自定义分类", text: $draft.customCategory, field: .customCategory)
                        }

                        if let categoryError = draft.categoryError {
                            Text(categoryError)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppSemanticColor.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    sheetTextField("菜名", text: $draft.name, field: .name)

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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.never)
        }
        .presentationBackground(AppSemanticColor.surface)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
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
        imageCoordinator.hasImage
    }

    // imageCoordinator.hasImage 提供了通用的图片可用性判断

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

    private func sheetTextField(_ title: String, text: Binding<String>, field: MenuField) -> some View {
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
