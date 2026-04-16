import SwiftUI
import PhotosUI

struct MenuDishImagePickerSection: View {
    @ObservedObject var coordinator: DishImageCoordinator
    @Binding var selectedPhotoItem: PhotosPickerItem?
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
            case .cropping:
                progressState("裁剪中…")
            case .ready(let previewImage, _):
                imagePreview(previewImage)
            case .uploading:
                progressState("上传中…")
            case .uploadFailed(let previewImage, _, let message):
                VStack(spacing: AppSpacing.xs) {
                    imagePreview(previewImage)
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
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("相册", systemImage: "photo.on.rectangle")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.primary)
                    .frame(maxWidth: .infinity, minHeight: AppDimension.minTouchTarget)
                    .background(AppSemanticColor.interactiveSecondary, in: RoundedRectangle(cornerRadius: AppRadius.sm))
            }
            .buttonStyle(.plain)

            Button(action: onCameraRequest) {
                Label("拍照", systemImage: "camera")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.primary)
                    .frame(maxWidth: .infinity, minHeight: AppDimension.minTouchTarget)
                    .background(AppSemanticColor.interactiveSecondary, in: RoundedRectangle(cornerRadius: AppRadius.sm))
            }
            .buttonStyle(.plain)
        }
    }

    private func progressState(_ title: String) -> some View {
        HStack {
            ProgressView()
                .tint(AppSemanticColor.primary)
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppSemanticColor.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: AppDimension.progressBlockMinHeight)
        .background(AppSemanticColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.sm))
    }

    private func imagePreview(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(0.7)
                .padding(AppSpacing.sm)
                .frame(maxWidth: .infinity, minHeight: AppDimension.imagePreviewMinHeight, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .stroke(AppSemanticColor.border, lineWidth: AppBorderWidth.hairline)
                }

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
}
