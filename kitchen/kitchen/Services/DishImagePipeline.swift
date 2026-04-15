import UIKit
import Vision
import CoreImage

enum DishImagePipelineError: LocalizedError {
    case readFailed
    case maskFailed
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .readFailed: "图片读取失败"
        case .maskFailed: "去背景失败"
        case .exportFailed: "导出失败"
        }
    }
}

struct DishImagePipeline {
    /// Input: a cropped UIImage at viewport aspect ratio.
    /// Output: transparent PNG preview + temp file URL.
    func process(_ image: UIImage) async throws -> (preview: UIImage, fileURL: URL) {
        let normalized = image.normalized()

        let processSize = CGSize(width: 800, height: 600)
        guard let scaled = normalized.scaled(to: processSize) else {
            throw DishImagePipelineError.readFailed
        }

        let masked = try await applyForegroundMask(to: scaled)

        guard let final = masked.scaled(to: DishImageSpec.outputSize) else {
            throw DishImagePipelineError.exportFailed
        }

        guard let pngData = final.pngData() else {
            throw DishImagePipelineError.exportFailed
        }

        let fileName = "\(UUID().uuidString).\(DishImageSpec.fileExtension)"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try pngData.write(to: fileURL)

        return (preview: final, fileURL: fileURL)
    }

    private func applyForegroundMask(to image: UIImage) async throws -> UIImage {
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
            throw DishImagePipelineError.maskFailed
        }

        let maskedBuffer = try observation.generateMaskedImage(
            ofInstances: observation.allInstances,
            from: handler,
            croppedToInstancesExtent: false
        )

        let ciImage = CIImage(cvPixelBuffer: maskedBuffer)
        let context = CIContext()
        guard let outputCGImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw DishImagePipelineError.exportFailed
        }

        return UIImage(cgImage: outputCGImage)
    }
}

private extension UIImage {
    func normalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }

    func scaled(to targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: targetSize)) }
    }
}
