import SwiftUI
import PhotosUI

struct MenuDishImagePickerSection: View {
    @ObservedObject var coordinator: DishImageCoordinator
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @Binding var isPhotoPickerPresented: Bool
    let onCameraRequest: () -> Void
    var isInvalid: Bool = false
    var validationTrigger: Int = 0
    var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            switch coordinator.imageState {
            case .empty:
                pickerButtons
            case .processing:
                progressState("处理中…")
            case .extracting:
                progressState("识别中…")
            case .remote(let previewImage, _):
                imagePreview(previewImage, showsRemoveButton: false, showsPickerButtons: true)
            case .ready(let previewImage, _):
                imagePreview(previewImage, showsRemoveButton: true, showsPickerButtons: true)
            case .uploading:
                progressState("上传中…")
            case .uploadFailed(let previewImage, _, let message):
                VStack(spacing: AppSpacing.xs) {
                    imagePreview(previewImage, showsRemoveButton: true, showsPickerButtons: true)
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppSemanticColor.danger)
                }
            case .failed(let message):
                VStack(spacing: AppSpacing.xs) {
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppSemanticColor.danger)
                    pickerButtons
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .appValidationFeedback(isInvalid: isInvalid, trigger: validationTrigger)
    }

    private var pickerButtons: some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                isPhotoPickerPresented = true
            } label: {
                Label("相册", systemImage: "photo.on.rectangle")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.primary)
                    .frame(maxWidth: .infinity, minHeight: AppDimension.minTouchTarget)
            }
            .buttonStyle(.plain)
            .photosPicker(isPresented: $isPhotoPickerPresented, selection: $selectedPhotoItem, matching: .images)

            Button(action: onCameraRequest) {
                Label("拍照", systemImage: "camera")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.primary)
                    .frame(maxWidth: .infinity, minHeight: AppDimension.minTouchTarget)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AppSpacing.xxs)
        .padding(.vertical, AppSpacing.xxs)
        .background(AppSemanticColor.interactiveSecondary, in: RoundedRectangle(cornerRadius: AppRadius.sm))
    }

    private func progressState(_ title: String) -> some View {
        AppLoadingIndicator(label: title, tone: .primary, controlSize: .regular)
        .frame(maxWidth: .infinity, minHeight: AppDimension.progressBlockMinHeight)
        .background(AppSemanticColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.sm))
    }

    private func imagePreview(
        _ image: UIImage,
        showsRemoveButton: Bool,
        showsPickerButtons: Bool
    ) -> some View {
        VStack(spacing: AppSpacing.xs) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                    .fill(AppSemanticColor.surfaceSecondary)
                    .frame(maxWidth: .infinity, minHeight: AppDimension.imagePreviewMinHeight)
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(0.7)
                            .padding(AppSpacing.sm)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    .clipped()

                if showsRemoveButton {
                    Button {
                        coordinator.clearImage()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: AppIconSize.xl))
                            .foregroundStyle(AppSemanticColor.textSecondary)
                            .padding(AppInset.badgeHorizontal)
                    }
                    .buttonStyle(.plain)
                }
            }

            if showsPickerButtons {
                pickerButtons
            }
        }
    }
}
