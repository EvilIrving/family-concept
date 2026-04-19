import UIKit

enum DishDraftImageState {
    case empty
    case extracting(UIImage)
    case processing
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
        case .extracting:
            return "正在识别主体"
        case .processing:
            return "正在优化菜品图"
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
            return "拍一张正面的菜品照，系统会自动去背景"
        case .extracting:
            return "Vision 正在提取菜品前景"
        case .processing:
            return "识别主体、去背景并生成成品图"
        case .ready:
            return "菜品主体已经提取完成"
        case .uploading:
            return "准备同步到云端"
        case .uploadFailed(_, _, let message):
            return message
        case .failed(let message):
            return message
        }
    }
}
