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
            onConfirm: onSave
        ) {
            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    MenuDishImagePickerSection(
                        coordinator: imageCoordinator,
                        selectedPhotoItem: $selectedPhotoItem,
                        onCameraRequest: onCameraRequest
                    )

                    sheetTextField("菜名", text: $draft.name, field: .name)

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("常用分类")
                            .font(AppTypography.micro)
                            .foregroundStyle(AppColor.textSecondary)

                        quickCategoryChips

                        if draft.selectedQuickCategory == "其他" {
                            sheetTextField("自定义分类", text: $draft.customCategory, field: .customCategory)
                        }
                    }

                    IngredientTagInput(
                        tags: $draft.ingredientTags,
                        input: $draft.ingredientInput,
                        focusedField: focusedField
                    )

                    if let validationMessage = draft.validationMessage {
                        Text(validationMessage)
                            .font(AppTypography.caption)
                            .foregroundStyle(AppColor.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.never)
        }
        .presentationBackground(AppColor.surfacePrimary)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            draft.validationMessage = nil
            focusedField.wrappedValue = nil
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                focusedField.wrappedValue = .name
            }
        }
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
                            .foregroundStyle(draft.selectedQuickCategory == category ? AppColor.textOnBrand : AppColor.green800)
                            .padding(.horizontal, AppSpacing.sm)
                            .frame(height: 32)
                            .background(
                                draft.selectedQuickCategory == category ? AppColor.green800 : AppColor.green100,
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
            isInvalid: false,
            validationTrigger: 0
        )
    }
}
