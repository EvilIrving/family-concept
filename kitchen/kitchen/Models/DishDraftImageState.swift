import UIKit

enum DishDraftImageState {
    case empty
    case cropping(UIImage)
    case processing
    case ready(previewImage: UIImage, fileURL: URL)
    case uploading
    /// 上传失败但本地临时文件仍在，可再次点保存重试
    case uploadFailed(previewImage: UIImage, fileURL: URL, message: String)
    case failed(String)
}
