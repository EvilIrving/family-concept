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
            return "待添加图片"
        case .processing:
            return "正在优化菜品图"
        case .remote:
            return "图片已就绪"
        case .ready:
            return "图片已就绪"
        case .uploading:
            return "正在上传"
        case .uploadFailed:
            return "上传失败"
        case .failed:
            return "处理失败"
        }
    }

    var statusSubtitle: String {
        switch self {
        case .empty:
            return "拍照或选图后，可在方形取景框内调整菜品构图"
        case .processing:
            return "正在生成方形菜品封面"
        case .remote:
            return "当前正在使用已上传图片"
        case .ready:
            return "菜品封面已经准备完成"
        case .uploading:
            return "准备同步到云端"
        case .uploadFailed(_, _, let message):
            return message
        case .failed(let message):
            return message
        }
    }
}
