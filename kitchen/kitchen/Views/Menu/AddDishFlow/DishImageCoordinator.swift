import UIKit
import Combine

@MainActor
final class DishImageCoordinator: ObservableObject {
    @Published var imageState: DishDraftImageState = .empty

    func processImage(_ image: UIImage) {
        imageState = .processing
        Task {
            do {
                let (preview, fileURL) = try await image.exportForDishUpload()
                imageState = .ready(previewImage: preview, fileURL: fileURL)
            } catch {
                imageState = .failed((error as? APIError)?.userMessage ?? error.localizedDescription)
            }
        }
    }

    /// 选图/拍照后调用：Vision 抠主体 + 白边 → 导出 PNG → ready
    /// 失败立即回到 .empty 并通过全局 feedback 路由弹 toast。
    func extractAndProcess(_ image: UIImage) {
        imageState = .extracting
        Task {
            do {
                let composed = try await VisionSubjectExtractor.extractAndCompose(image)
                let (preview, fileURL) = try await composed.exportForDishUpload()
                imageState = .ready(previewImage: preview, fileURL: fileURL)
            } catch {
                imageState = .empty
                AppFeedbackRouter.shared.show(
                    .low(message: L10n.tr("subjectExtract.toast.failed")),
                    placement: .centerToast
                )
            }
        }
    }

    func clearImage() {
        removeTempFileIfNeeded()
        imageState = .empty
    }

    func seedRemoteImage(_ image: UIImage, remoteURL: URL) {
        guard case .empty = imageState else { return }
        imageState = .remote(previewImage: image, remoteURL: remoteURL)
    }

    func cleanupAfterUpload(fileURL: URL) {
        try? FileManager.default.removeItem(at: fileURL)
        imageState = .empty
    }

    private func removeTempFileIfNeeded() {
        switch imageState {
        case .ready(_, let url), .uploadFailed(_, let url, _):
            try? FileManager.default.removeItem(at: url)
        default:
            break
        }
    }

    /// 是否有可用图片（包括已准备就绪、上传中或上次上传失败但仍有文件可用）
    var hasImage: Bool {
        switch imageState {
        case .remote, .ready, .uploadFailed, .uploading:
            return true
        default:
            return false
        }
    }
}
