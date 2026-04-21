import UIKit
import Vision
import CoreImage

/// 菜品图像处理器 - 负责 Vision 前景抠图和最终图像合成
struct DishImageProcessor {

    // MARK: - Public Entry Points

    static func composeFinalImage(from viewportSubimage: UIImage) async -> UIImage {
        if let extracted = await extractForeground(from: viewportSubimage) {
            return compose(foreground: extracted.image, bboxInPixels: extracted.bbox)
        }
        let fallbackBBox = CGRect(origin: .zero, size: viewportSubimage.size)
        return compose(foreground: viewportSubimage, bboxInPixels: fallbackBBox)
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

                let fitScale = min(vpWidth * 0.82 / subjectScreenWidth, vpHeight * 0.82 / subjectScreenHeight)
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

    // MARK: - Private Helpers

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

    private static func compose(foreground: UIImage, bboxInPixels bbox: CGRect) -> UIImage {
        let outputSize = DishImageSpec.outputSize
        let fillRatio = DishImageSpec.subjectFillRatio
        let maxSide = max(bbox.width, bbox.height)
        guard maxSide > 0 else { return foreground }

        let targetLong = outputSize.width * fillRatio
        let s = targetLong / maxSide

        let drawW = foreground.size.width * s
        let drawH = foreground.size.height * s
        let originX = outputSize.width / 2 - (bbox.midX * s)
        let originY = outputSize.height / 2 - (bbox.midY * s)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        return renderer.image { _ in
            foreground.draw(in: CGRect(x: originX, y: originY, width: drawW, height: drawH))
        }
    }
}

// MARK: - Supporting Types

extension VNInstanceMaskObservation {
    nonisolated func subjectBounds(using handler: VNImageRequestHandler) throws -> CGRect? {
        let maskBuffer = try generateScaledMaskForImage(forInstances: allInstances, from: handler)
        CVPixelBufferLockBaseAddress(maskBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(maskBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(maskBuffer) else { return nil }

        let w = CVPixelBufferGetWidth(maskBuffer)
        let h = CVPixelBufferGetHeight(maskBuffer)
        let bpr = CVPixelBufferGetBytesPerRow(maskBuffer)
        let ptr = base.assumingMemoryBound(to: UInt8.self)

        var minX = w, maxX = 0, minY = h, maxY = 0
        for y in 0..<h {
            let row = ptr.advanced(by: y * bpr)
            for x in 0..<w where row[x] > 0 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }

        return CGRect(
            x: CGFloat(minX) / CGFloat(w),
            y: CGFloat(minY) / CGFloat(h),
            width: CGFloat(maxX - minX + 1) / CGFloat(w),
            height: CGFloat(maxY - minY + 1) / CGFloat(h)
        )
    }
}
