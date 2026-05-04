import UIKit

enum DishDraftImageState {
    case empty
    case processing
    case remote(previewImage: UIImage, remoteURL: URL)
    case ready(previewImage: UIImage, fileURL: URL)
    case uploading
    /// 上传失败但本地临时文件仍在，可再次点保存重试
    case uploadFailed(previewImage: UIImage, fileURL: URL, message: String)
    case failed(String)
}

extension DishDraftImageState {
    var statusTitle: String {
        switch self {
        case .empty:
            return L10n.tr("Add a photo")
        case .processing:
            return L10n.tr("Optimizing image")
        case .remote:
            return L10n.tr("Image ready")
        case .ready:
            return L10n.tr("Image ready")
        case .uploading:
            return L10n.tr("dishDraft.state.uploading")
        case .uploadFailed:
            return L10n.tr("Upload failed")
        case .failed:
            return L10n.tr("Processing failed")
        }
    }

    var statusSubtitle: String {
        switch self {
        case .empty:
            return L10n.tr("After taking or choosing a photo, frame your dish in the square")
        case .processing:
            return L10n.tr("Generating dish cover")
        case .remote:
            return L10n.tr("Using the uploaded image")
        case .ready:
            return L10n.tr("Dish cover ready")
        case .uploading:
            return L10n.tr("Ready to sync")
        case .uploadFailed(_, _, let message):
            return message
        case .failed(let message):
            return message
        }
    }
}
