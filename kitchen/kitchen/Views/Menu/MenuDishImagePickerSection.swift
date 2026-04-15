import SwiftUI
import PhotosUI

struct MenuDishImagePickerSection: View {
    @ObservedObject var coordinator: DishImageCoordinator
    @Binding var selectedPhotoItem: PhotosPickerItem?
    let onCameraRequest: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("菜品图片")
                .font(AppTypography.micro)
                .foregroundStyle(AppColor.textSecondary)

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
                        .foregroundStyle(AppColor.danger)
                }
            case .failed(let message):
                VStack(spacing: AppSpacing.xs) {
                    Text(message)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.danger)
                    pickerButtons
                }
            }
        }
    }

    private var pickerButtons: some View {
        HStack(spacing: AppSpacing.sm) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Label("相册", systemImage: "photo.on.rectangle")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.green800)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(AppColor.green100, in: RoundedRectangle(cornerRadius: AppRadius.sm))
            }
            .buttonStyle(.plain)

            Button(action: onCameraRequest) {
                Label("拍照", systemImage: "camera")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.green800)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(AppColor.green100, in: RoundedRectangle(cornerRadius: AppRadius.sm))
            }
            .buttonStyle(.plain)
        }
    }

    private func progressState(_ title: String) -> some View {
        HStack {
            ProgressView()
                .tint(AppColor.green800)
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .background(AppColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.sm))
    }

    private func imagePreview(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(0.7)
                .padding(AppSpacing.sm)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.sm)
                        .stroke(AppColor.lineSoft, lineWidth: 1)
                }

            Button {
                coordinator.clearImage()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
    }
}
