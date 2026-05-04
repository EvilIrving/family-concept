import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

enum VisionSubjectExtractorError: LocalizedError {
    case noSubject
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .noSubject: L10n.tr("subjectExtract.error.noSubject")
        case .processingFailed: L10n.tr("subjectExtract.error.processingFailed")
        }
    }
}

private extension UIImage.Orientation {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: .up
        case .upMirrored: .upMirrored
        case .down: .down
        case .downMirrored: .downMirrored
        case .left: .left
        case .leftMirrored: .leftMirrored
        case .right: .right
        case .rightMirrored: .rightMirrored
        @unknown default: .up
        }
    }
}

enum VisionSubjectExtractor {
    private static let ciContext: CIContext = {
        CIContext(options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()])
    }()

    /// 主入口：Vision 抠主体 → 居中放到固定 1280×960 透明画布 → 加 12px 黑色硬描边环。
    static func extractAndCompose(_ image: UIImage) async throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw VisionSubjectExtractorError.processingFailed
        }
        let orientation = image.imageOrientation.cgImagePropertyOrientation
        return try await Task.detached(priority: .userInitiated) {
            let subject = try performExtract(cgImage: cgImage, orientation: orientation)
            let canvas = composeOnCanvas(subject: subject)
            return try applyOutlineRing(
                canvasImage: canvas,
                strokeWidthPixels: DishImageSpec.strokeWidthPixels,
                color: DishImageSpec.strokeColor
            )
        }.value
    }

    private nonisolated static func performExtract(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation
    ) throws -> UIImage {
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        let request = VNGenerateForegroundInstanceMaskRequest()
        try handler.perform([request])

        guard let observation = request.results?.first,
              !observation.allInstances.isEmpty else {
            throw VisionSubjectExtractorError.noSubject
        }

        let pixelBuffer = try observation.generateMaskedImage(
            ofInstances: observation.allInstances,
            from: handler,
            croppedToInstancesExtent: true
        )
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cg = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            throw VisionSubjectExtractorError.processingFailed
        }
        return UIImage(cgImage: cg)
    }

    /// 将主体按 min(W,H) * subjectFillRatio 作为最长边等比缩放，居中放入固定画布。
    private nonisolated static func composeOnCanvas(subject: UIImage) -> UIImage {
        let canvasSize = DishImageSpec.canvasPixelSize
        let maxLongEdge = min(canvasSize.width, canvasSize.height) * DishImageSpec.subjectFillRatio
        let subjSize = subject.size
        let longEdge = max(subjSize.width, subjSize.height)
        let scale = longEdge > 0 ? maxLongEdge / longEdge : 1
        let drawSize = CGSize(width: subjSize.width * scale, height: subjSize.height * scale)
        let origin = CGPoint(
            x: (canvasSize.width - drawSize.width) / 2,
            y: (canvasSize.height - drawSize.height) / 2
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { _ in
            subject.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }

    /// 在画布坐标系下生成 12px 黑色轮廓环：膨胀 alpha → 减去原 alpha → 染色 → 主体覆盖。
    private nonisolated static func applyOutlineRing(
        canvasImage: UIImage,
        strokeWidthPixels: CGFloat,
        color: CIColor
    ) throws -> UIImage {
        guard let cg = canvasImage.cgImage else {
            throw VisionSubjectExtractorError.processingFailed
        }
        let base = CIImage(cgImage: cg)
        let extent = base.extent

        // 仅保留 alpha 通道，RGB 置 1，得到一张 alpha mask。
        let alphaMask = base.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: 0)
        ])

        let expanded = alphaMask
            .clampedToExtent()
            .applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": strokeWidthPixels])
            .cropped(to: extent)

        // ring = expanded \ alpha：在原 alpha 透明的位置保留膨胀部分。
        let ring = expanded.applyingFilter("CISourceOutCompositing", parameters: [
            kCIInputBackgroundImageKey: alphaMask
        ])

        // 用纯色填充 ring 的 alpha 形状。
        let colorFill = CIImage(color: color).cropped(to: extent)
        let coloredRing = colorFill.applyingFilter("CISourceInCompositing", parameters: [
            kCIInputBackgroundImageKey: ring
        ])

        // 主体在上、环在下：主体内部像素不被覆盖。
        let composited = base.composited(over: coloredRing)
        guard let out = ciContext.createCGImage(composited, from: extent) else {
            throw VisionSubjectExtractorError.processingFailed
        }
        return UIImage(cgImage: out)
    }
}
