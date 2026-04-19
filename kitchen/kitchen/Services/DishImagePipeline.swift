import UIKit

enum DishImagePipelineError: LocalizedError {
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .exportFailed: "导出失败"
        }
    }
}

struct DishImagePipeline {
    /// Input: 透明背景的菜品成品图（由 DishRecognitionView 的 Vision 抠图 + 80% 规格化合成输出）。
    /// Output: 写入 temp 目录的 PNG 文件 URL 与原始预览图。
    func process(_ image: UIImage) async throws -> (preview: UIImage, fileURL: URL) {
        guard let pngData = image.pngData() else {
            throw DishImagePipelineError.exportFailed
        }
        let fileName = "\(UUID().uuidString).\(DishImageSpec.fileExtension)"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try pngData.write(to: fileURL)
        return (preview: image, fileURL: fileURL)
    }
}

// MARK: - UIImage helpers

extension UIImage {
    /// 进入抠图页前调用：将 HEIC / Live Photo 静帧等任意格式统一重编码为标准位图，稳定 Vision 输入。不改变像素尺寸。
    nonisolated func standardizedForCrop(jpegQuality: CGFloat = 0.82) -> UIImage {
        jpegReencoded(quality: jpegQuality)
    }

    /// JPEG 重编码：强制将任意格式解码为标准位图并做质量压缩。失败时原样返回。
    nonisolated func jpegReencoded(quality: CGFloat) -> UIImage {
        guard let data = jpegData(compressionQuality: quality),
              let reloaded = UIImage(data: data) else { return self }
        return reloaded
    }
}
