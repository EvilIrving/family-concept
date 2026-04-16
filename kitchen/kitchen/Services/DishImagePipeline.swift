import UIKit
import Vision
import CoreImage

enum DishImagePipelineError: LocalizedError {
    case readFailed
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .readFailed: "图片读取失败"
        case .exportFailed: "导出失败"
        }
    }
}

struct DishImagePipeline {
    private let context = CIContext()

    /// Input: a cropped UIImage at viewport aspect ratio (any resolution).
    /// Output: transparent PNG preview + temp file URL at DishImageSpec.outputSize.
    func process(_ image: UIImage) async throws -> (preview: UIImage, fileURL: URL) {
        let prepared = image.jpegReencoded(quality: 0.82).capped(to: DishImageSpec.outputSize)
        let final = await foregroundMaskedOrOriginalImage(from: prepared)

        guard let pngData = final.pngData() else {
            throw DishImagePipelineError.exportFailed
        }

        let fileName = "\(UUID().uuidString).\(DishImageSpec.fileExtension)"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try pngData.write(to: fileURL)

        return (preview: final, fileURL: fileURL)
    }

    private func foregroundMaskedOrOriginalImage(from image: UIImage) async -> UIImage {
        do {
            return try await applyForegroundMask(to: image) ?? image
        } catch {
            return image
        }
    }

    private func applyForegroundMask(to image: UIImage) async throws -> UIImage? {
        guard let cgImage = image.cgImage else {
            throw DishImagePipelineError.readFailed
        }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            do {
                try handler.perform([request])
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }

        guard let observation = request.results?.first else {
            return nil
        }

        let instances = observation.allInstances
        guard !instances.isEmpty else {
            return nil
        }

        let maskBuffer = try observation.generateScaledMaskForImage(
            forInstances: instances,
            from: handler
        )

        let sourceCI = CIImage(cgImage: cgImage)
        let scaledMask = CIImage(cvPixelBuffer: maskBuffer)
            .cropped(to: sourceCI.extent)
        let clearBackground = CIImage(color: .clear).cropped(to: sourceCI.extent)
        let blended = sourceCI.applyingFilter(
            "CIBlendWithMask",
            parameters: [
                kCIInputBackgroundImageKey: clearBackground,
                kCIInputMaskImageKey: scaledMask
            ]
        )
        guard let outputCGImage = context.createCGImage(blended, from: sourceCI.extent) else {
            throw DishImagePipelineError.exportFailed
        }

        return UIImage(cgImage: outputCGImage, scale: image.scale, orientation: .up)
    }
}

// MARK: - UIImage helpers

extension UIImage {
    /// 裁图前调用：将 HEIC / Live Photo 静帧等任意格式统一重编码为 JPEG 位图。
    nonisolated func standardizedForCrop(jpegQuality: CGFloat = 0.82) -> UIImage {
        jpegReencoded(quality: jpegQuality)
    }

    /// 长边超过 `longSide` 时等比缩小，否则原样返回。
    nonisolated func scaledDown(toLongSide longSide: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        guard maxSide > longSide else { return self }
        let ratio = longSide / maxSide
        let newSize = CGSize(width: (size.width * ratio).rounded(), height: (size.height * ratio).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    /// JPEG 重编码：强制将任意格式解码为标准位图并做质量压缩。失败时原样返回。
    nonisolated func jpegReencoded(quality: CGFloat) -> UIImage {
        guard let data = jpegData(compressionQuality: quality),
              let reloaded = UIImage(data: data) else { return self }
        return reloaded
    }
}

private extension UIImage {
    /// 若图片任意一边超出 `maxSize`，等比缩小到恰好装入；否则原样返回。
    func capped(to maxSize: CGSize) -> UIImage {
        guard size.width > maxSize.width || size.height > maxSize.height else { return self }
        let scale = min(maxSize.width / size.width, maxSize.height / size.height)
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
