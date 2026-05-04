import SwiftUI

struct MenuDishFlowImagePickerSection: View {
    @ObservedObject var coordinator: DishImageCoordinator
    let onPhotoLibraryRequest: () -> Void
    let onCameraRequest: () -> Void
    var isInvalid: Bool = false
    var validationTrigger: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            switch coordinator.imageState {
            case .empty:
                pickerButtons
            case .extracting:
                previewWithLoading(L10n.tr("subjectExtract.status.extracting"))
            case .processing:
                previewWithLoading(L10n.tr("Processing…"))
            case .remote(let previewImage, _):
                previewBox(content: { fittedImage(previewImage) }, removable: true)
            case .ready(let previewImage, _):
                previewBox(content: { fittedImage(previewImage) }, removable: true)
            case .uploading:
                previewWithLoading(L10n.tr("dishFlow.progress.uploading"))
            case .uploadFailed(let previewImage, _, let message):
                VStack(spacing: AppSpacing.xs) {
                    previewBox(content: { fittedImage(previewImage) }, removable: true)
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
        }
        .overlay {
            if isInvalid {
                RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous)
                    .inset(by: -AppSpacing.xs)
                    .stroke(AppSemanticColor.danger, lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
        .modifier(AppShakeEffect(animatableData: CGFloat(validationTrigger)))
        .animation(.easeInOut(duration: 0.34), value: validationTrigger)
        .animation(.easeInOut(duration: 0.16), value: isInvalid)
    }

    private var pickerButtons: some View {
        HStack(spacing: AppSpacing.sm) {
            AppButton(title: L10n.tr("Photo Library"), leadingIcon: "photo.on.rectangle", role: .secondary, size: .sm) {
                onPhotoLibraryRequest()
            }

            AppButton(title: L10n.tr("Camera"), leadingIcon: "camera", role: .secondary, size: .sm) {
                onCameraRequest()
            }
        }
    }

    private func previewWithLoading(_ label: String) -> some View {
        previewBox(
            content: {
                AppLoadingIndicator(label: label, tone: .primary, controlSize: .regular)
            },
            removable: false
        )
    }

    private func fittedImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(AppSpacing.md)
    }

    @ViewBuilder
    private func previewBox<Content: View>(
        @ViewBuilder content: () -> Content,
        removable: Bool
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay {
                    content()
                }

            if removable {
                Button {
                    coordinator.clearImage()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(AppSemanticColor.textSecondary)
                }
                .padding(AppInset.badgeHorizontal)
            }
        }
    }
}
