import SwiftUI

struct MenuDishFlowImagePickerSection: View {
    @ObservedObject var coordinator: DishImageCoordinator
    let onPhotoLibraryRequest: () -> Void
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
            case .remote(let previewImage, _):
                imagePreview(previewImage, showsRemoveButton: false)
            case .ready(let previewImage, _):
                imagePreview(previewImage, showsRemoveButton: true)
            case .uploading:
                progressState("上传中…")
            case .uploadFailed(let previewImage, _, let message):
                VStack(spacing: AppSpacing.xs) {
                    imagePreview(previewImage, showsRemoveButton: true)
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
        .modifier(AppShakeEffect(animatableData: CGFloat(validationTrigger)))
        .animation(.easeInOut(duration: 0.34), value: validationTrigger)
    }

    private var pickerButtons: some View {
        HStack(spacing: AppSpacing.sm) {
            Button(action: onPhotoLibraryRequest) {
                Label("相册", systemImage: "photo.on.rectangle")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.primary)
                    .frame(maxWidth: .infinity, minHeight: AppDimension.minTouchTarget)
                    .background(
                        AppSemanticColor.interactiveSecondary,
                        in: RoundedRectangle(cornerRadius: AppRadius.sm)
                    )
            }
            .buttonStyle(.plain)

            Button(action: onCameraRequest) {
                Label("拍照", systemImage: "camera")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.primary)
                    .frame(maxWidth: .infinity, minHeight: AppDimension.minTouchTarget)
                    .background(
                        AppSemanticColor.interactiveSecondary,
                        in: RoundedRectangle(cornerRadius: AppRadius.sm)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func progressState(_ title: String) -> some View {
        AppLoadingIndicator(label: title, tone: .primary, controlSize: .regular)
            .frame(maxWidth: .infinity, minHeight: AppDimension.progressBlockMinHeight)
            .background(AppSemanticColor.surfaceSecondary, in: RoundedRectangle(cornerRadius: AppRadius.sm))
    }

    private func imagePreview(
        _ image: UIImage,
        showsRemoveButton: Bool
    ) -> some View {
        VStack(spacing: AppSpacing.xs) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                    .fill(AppSemanticColor.surfaceSecondary)
                    .frame(maxWidth: .infinity, minHeight: 188)
                    .overlay {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            GeometryReader { proxy in
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: proxy.size.width, height: proxy.size.width)
                                    .clipShape(
                                        RoundedRectangle(
                                            cornerRadius: DishImageSpec.viewportCornerRadius,
                                            style: .continuous
                                        )
                                    )
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            }
                            .aspectRatio(1, contentMode: .fit)
                        }
                        .padding(AppSpacing.md)
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

            pickerButtons
        }
    }
}
