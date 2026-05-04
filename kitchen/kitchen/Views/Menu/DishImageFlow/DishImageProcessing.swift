import UIKit

enum DishImageProcessingError: LocalizedError {
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .exportFailed: L10n.tr("Export failed")
        }
    }
}

extension UIImage {
    /// 将当前裁切后的菜品封面导出为 temp 目录中的 PNG 文件，并返回同一张预览图。
    nonisolated func exportForDishUpload() async throws -> (preview: UIImage, fileURL: URL) {
        guard let pngData = pngData() else {
            throw DishImageProcessingError.exportFailed
        }
        let fileName = "\(UUID().uuidString).png"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try pngData.write(to: fileURL)
        return (preview: self, fileURL: fileURL)
    }

    /// 进入裁切页前调用：将 HEIC / Live Photo 静帧等任意格式统一重编码为标准位图，不改变像素尺寸。
    nonisolated func standardizedForCrop(jpegQuality: CGFloat = 0.82) -> UIImage {
        jpegReencoded(quality: jpegQuality)
    }

    /// JPEG 重编码：将任意格式解码为标准位图并做质量压缩。失败时原样返回。
    nonisolated func jpegReencoded(quality: CGFloat) -> UIImage {
        guard let data = jpegData(compressionQuality: quality),
              let reloaded = UIImage(data: data) else { return self }
        return reloaded
    }
}
