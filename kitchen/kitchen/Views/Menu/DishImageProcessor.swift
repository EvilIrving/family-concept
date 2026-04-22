import UIKit
import Vision
import CoreImage

struct DishImageComposition: Sendable {
    enum SubjectStyle: String, Sendable {
        case standard
        case elongated
    }

    let foregroundImage: UIImage
    let sourceSubimage: UIImage
    let bboxInPixels: CGRect
    let baseScale: CGFloat
    let suggestedOffset: CGSize
    let style: SubjectStyle

    var suggestedTransform: DishImageTransform {
        DishImageTransform(scaleMultiplier: 1, offset: suggestedOffset)
    }
}

struct DishImageTransform: Sendable, Equatable {
    var scaleMultiplier: CGFloat
    var offset: CGSize

    static let identity = DishImageTransform(scaleMultiplier: 1, offset: .zero)
}

/// 菜品图像处理器 - 负责 Vision 前景抠图、自动构图建议与最终图像合成
struct DishImageProcessor {

    static func composeFinalImage(from viewportSubimage: UIImage) async -> UIImage {
        let composition = await analyzeComposition(from: viewportSubimage)
        return renderFinalImage(from: composition, transform: composition.suggestedTransform)
    }

    static func analyzeComposition(from viewportSubimage: UIImage) async -> DishImageComposition {
        if let extracted = await extractForeground(from: viewportSubimage) {
            return makeComposition(
                foreground: extracted.image,
                sourceSubimage: viewportSubimage,
                bboxInPixels: extracted.bbox,
                canvasSize: viewportSubimage.size
            )
        }

        let fallbackBBox = CGRect(origin: .zero, size: viewportSubimage.size)
        return makeComposition(
            foreground: viewportSubimage,
            sourceSubimage: viewportSubimage,
            bboxInPixels: fallbackBBox,
            canvasSize: viewportSubimage.size
        )
    }

    static func renderFinalImage(from composition: DishImageComposition, transform: DishImageTransform) -> UIImage {
        let outputSize = DishImageSpec.outputSize
        let drawScale = composition.baseScale * transform.scaleMultiplier
        let drawWidth = composition.foregroundImage.size.width * drawScale
        let drawHeight = composition.foregroundImage.size.height * drawScale
        let originX = outputSize.width / 2 - (composition.bboxInPixels.midX * drawScale) + transform.offset.width
        let originY = outputSize.height / 2 - (composition.bboxInPixels.midY * drawScale) + transform.offset.height

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { _ in
            composition.foregroundImage.draw(in: CGRect(x: originX, y: originY, width: drawWidth, height: drawHeight))
        }
    }

    static func visionFraming(for image: UIImage, vpWidth: CGFloat, vpHeight: CGFloat) async -> (scale: CGFloat, offset: CGSize)? {
        await Task.detached(priority: .userInitiated) {
            guard let cgImage = image.cgImage else { return nil }

            do {
                let request = VNGenerateForegroundInstanceMaskRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])

                guard let observation = request.results?.first,
                      let normBounds = try observation.subjectBounds(using: handler) else { return nil }

                let imageSize = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
                let subjectCenter = CGPoint(
                    x: normBounds.midX * imageSize.width,
                    y: normBounds.midY * imageSize.height
                )
                let baseScale = max(vpWidth / imageSize.width, vpHeight / imageSize.height)
                let subjectScreenWidth = normBounds.width * imageSize.width * baseScale
                let subjectScreenHeight = normBounds.height * imageSize.height * baseScale

                guard subjectScreenWidth > 1, subjectScreenHeight > 1 else { return nil }

                let fitScale = min(vpWidth * 0.84 / subjectScreenWidth, vpHeight * 0.84 / subjectScreenHeight)
                let imageCenter = CGPoint(x: imageSize.width / 2, y: imageSize.height / 2)
                let offset = CGSize(
                    width: (imageCenter.x - subjectCenter.x) * baseScale * fitScale,
                    height: (imageCenter.y - subjectCenter.y) * baseScale * fitScale
                )
                return (fitScale, offset)
            } catch {
                return nil
            }
        }.value
    }

    private static func extractForeground(from image: UIImage) async -> (image: UIImage, bbox: CGRect)? {
        await Task.detached(priority: .userInitiated) {
            guard let cg = image.cgImage else { return nil }
            do {
                let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                let request = VNGenerateForegroundInstanceMaskRequest()
                try handler.perform([request])
                guard let obs = request.results?.first else { return nil }
                let instances = obs.allInstances
                guard !instances.isEmpty else { return nil }

                let buffer = try obs.generateMaskedImage(
                    ofInstances: instances,
                    from: handler,
                    croppedToInstancesExtent: false
                )
                let ciImage = CIImage(cvPixelBuffer: buffer)
                let ciContext = CIContext()
                guard let cgOut = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
                let foreground = UIImage(cgImage: cgOut, scale: 1, orientation: .up)

                guard let norm = try obs.subjectBounds(using: handler) else { return nil }
                let imgSize = CGSize(width: CGFloat(cg.width), height: CGFloat(cg.height))
                let bbox = CGRect(
                    x: norm.minX * imgSize.width,
                    y: norm.minY * imgSize.height,
                    width: norm.width * imgSize.width,
                    height: norm.height * imgSize.height
                )
                return (foreground, bbox)
            } catch {
                return nil
            }
        }.value
    }

    private static func makeComposition(
        foreground: UIImage,
        sourceSubimage: UIImage,
        bboxInPixels bbox: CGRect,
        canvasSize: CGSize
    ) -> DishImageComposition {
        let outputSize = DishImageSpec.outputSize
        let boundedBox = bbox.standardized.integral.intersection(CGRect(origin: .zero, size: canvasSize))
        let safeBox = boundedBox.width > 0 && boundedBox.height > 0 ? boundedBox : CGRect(origin: .zero, size: canvasSize)

        let aspectRatio = safeBox.width / max(safeBox.height, 1)
        let areaRatio = (safeBox.width * safeBox.height) / max(canvasSize.width * canvasSize.height, 1)
        let isTouchingHorizontalEdge = safeBox.minX <= 8 || safeBox.maxX >= canvasSize.width - 8
        let isElongated = aspectRatio >= 1.75 || (aspectRatio >= 1.45 && (areaRatio < 0.28 || isTouchingHorizontalEdge))
        let style: DishImageComposition.SubjectStyle = isElongated ? .elongated : .standard

        let subjectTargetRatio: CGFloat = isElongated ? 0.92 : 0.78
        let horizontalTarget = outputSize.width * subjectTargetRatio
        let verticalTarget = outputSize.height * (isElongated ? 0.62 : 0.78)
        let baseScale = min(horizontalTarget / max(safeBox.width, 1), verticalTarget / max(safeBox.height, 1))

        let centerOffset: CGSize = .zero

        return DishImageComposition(
            foregroundImage: foreground,
            sourceSubimage: sourceSubimage,
            bboxInPixels: safeBox,
            baseScale: baseScale,
            suggestedOffset: centerOffset,
            style: style
        )
    }
}

extension VNInstanceMaskObservation {
    nonisolated func subjectBounds(using handler: VNImageRequestHandler) throws -> CGRect? {
        let maskBuffer = try generateScaledMaskForImage(forInstances: allInstances, from: handler)
        CVPixelBufferLockBaseAddress(maskBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(maskBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(maskBuffer) else { return nil }

        let width = CVPixelBufferGetWidth(maskBuffer)
        let height = CVPixelBufferGetHeight(maskBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(maskBuffer)
        let pointer = base.assumingMemoryBound(to: UInt8.self)

        var minX = width
        var maxX = 0
        var minY = height
        var maxY = 0

        for y in 0..<height {
            let row = pointer.advanced(by: y * bytesPerRow)
            for x in 0..<width where row[x] > 0 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }

        return CGRect(
            x: CGFloat(minX) / CGFloat(width),
            y: CGFloat(minY) / CGFloat(height),
            width: CGFloat(maxX - minX + 1) / CGFloat(width),
            height: CGFloat(maxY - minY + 1) / CGFloat(height)
        )
    }
}
