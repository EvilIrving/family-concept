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
            return L10n.tr("待添加图片")
        case .processing:
            return L10n.tr("正在优化菜品图")
        case .remote:
            return L10n.tr("图片已就绪")
        case .ready:
            return L10n.tr("图片已就绪")
        case .uploading:
            return L10n.tr("正在上传")
        case .uploadFailed:
            return L10n.tr("上传失败")
        case .failed:
            return L10n.tr("处理失败")
        }
    }

    var statusSubtitle: String {
        switch self {
        case .empty:
            return L10n.tr("拍照或选图后，可在方形取景框内调整菜品构图")
        case .processing:
            return L10n.tr("正在生成方形菜品封面")
        case .remote:
            return L10n.tr("当前正在使用已上传图片")
        case .ready:
            return L10n.tr("菜品封面已经准备完成")
        case .uploading:
            return L10n.tr("准备同步到云端")
        case .uploadFailed(_, _, let message):
            return message
        case .failed(let message):
            return message
        }
    }
}
