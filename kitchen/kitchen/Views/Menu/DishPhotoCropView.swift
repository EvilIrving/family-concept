import SwiftUI
import Vision

struct DishPhotoCropView: View {
    private let minimumScale: CGFloat = 0.5

    let sourceImage: UIImage
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var suggestedScale: CGFloat = 1.0
    @State private var normalizedImage: UIImage?

    private var displayImage: UIImage { normalizedImage ?? sourceImage }

    var body: some View {
        GeometryReader { geo in
            let vpSize = viewportSize(in: geo)
            let vpWidth = vpSize.width
            let vpHeight = vpSize.height
            let topPad = max(geo.safeAreaInsets.top, 16) + 16
            let bottomPad = max(geo.safeAreaInsets.bottom, 16) + 80
            let availableH = geo.size.height - topPad - bottomPad
            let vpY = topPad + max(0, (availableH - vpHeight) / 2)
            let viewportCenter = CGPoint(x: geo.size.width / 2, y: vpY + vpHeight / 2)

            ZStack {
                Color.black.ignoresSafeArea()

                cropCanvas(vpWidth: vpWidth, vpHeight: vpHeight, viewportCenter: viewportCenter, containerSize: geo.size)

                darkOverlay(geo: geo, viewportCenter: viewportCenter, vpWidth: vpWidth, vpHeight: vpHeight)

                viewportBorder(vpWidth: vpWidth, vpHeight: vpHeight)
                    .position(x: viewportCenter.x, y: viewportCenter.y)

                actionButtons(geo: geo, vpWidth: vpWidth, vpY: vpY, vpHeight: vpHeight, viewportCenter: viewportCenter)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .task(id: sourceImage) {
                let img = await Task.detached(priority: .userInitiated) {
                    sourceImage.normalizedForCrop()
                }.value
                normalizedImage = img
                await applySuggestedFraming(vpWidth: vpWidth, vpHeight: vpHeight)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func darkOverlay(geo: GeometryProxy, viewportCenter: CGPoint, vpWidth: CGFloat, vpHeight: CGFloat) -> some View {
        Rectangle()
            .fill(Color.black.opacity(0.55))
            .ignoresSafeArea()
            .overlay(
                RoundedRectangle(cornerRadius: DishImageSpec.viewportCornerRadius)
                    .frame(width: vpWidth, height: vpHeight)
                    .offset(
                        x: viewportCenter.x - geo.size.width / 2,
                        y: viewportCenter.y - geo.size.height / 2
                    )
                    .blendMode(.destinationOut)
            )
            .compositingGroup()
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func viewportBorder(vpWidth: CGFloat, vpHeight: CGFloat) -> some View {
        ZStack {
            // Outer border
            RoundedRectangle(cornerRadius: DishImageSpec.viewportCornerRadius)
                .strokeBorder(Color.white.opacity(0.85), lineWidth: 2.5)
                .frame(width: vpWidth, height: vpHeight)

            // Inner shadow layer
            RoundedRectangle(cornerRadius: DishImageSpec.viewportCornerRadius)
                .strokeBorder(Color.black.opacity(0.45), lineWidth: 18)
                .blur(radius: 12)
                .frame(width: vpWidth, height: vpHeight)
                .clipShape(RoundedRectangle(cornerRadius: DishImageSpec.viewportCornerRadius))
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func actionButtons(geo: GeometryProxy, vpWidth: CGFloat, vpY: CGFloat, vpHeight: CGFloat, viewportCenter: CGPoint) -> some View {
        let spaceBelow = geo.size.height - geo.safeAreaInsets.bottom - (vpY + vpHeight)
        let buttonRowY = vpY + vpHeight + spaceBelow / 2
        let buttonInset = (geo.size.width - vpWidth) / 2 + 8

        HStack(spacing: 0) {
            Button(action: onCancel) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.5)
                        .frame(width: 56, height: 56)
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 56, height: 56)

            Spacer()

            Button(action: {
                crop(viewportCenter: viewportCenter, vpY: vpY, vpWidth: vpWidth, vpHeight: vpHeight)
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 64, height: 64)
                    Image(systemName: "checkmark")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.black)
                }
            }
            .frame(width: 64, height: 64)
        }
        .padding(.horizontal, buttonInset)
        .frame(width: geo.size.width)
        .position(x: geo.size.width / 2, y: buttonRowY)
    }

    private func cropCanvas(vpWidth: CGFloat, vpHeight: CGFloat, viewportCenter: CGPoint, containerSize: CGSize) -> some View {
        let baseFrame = aspectFillFrame(for: displayImage.size, vpWidth: vpWidth, vpHeight: vpHeight)
        let baseOffset = CGSize(
            width: viewportCenter.x - containerSize.width / 2,
            height: viewportCenter.y - containerSize.height / 2
        )

        return Color.clear
            .frame(width: containerSize.width, height: containerSize.height)
            .overlay(
                Image(uiImage: displayImage)
                    .resizable()
                    .frame(width: baseFrame.width * scale, height: baseFrame.height * scale)
                    .offset(x: baseOffset.width + offset.width, y: baseOffset.height + offset.height)
            )
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = max(minimumScale, lastScale * value)
                            offset = clamped(offset, vpWidth: vpWidth, vpHeight: vpHeight)
                        }
                        .onEnded { _ in
                            lastScale = scale
                            lastOffset = offset
                        },
                    DragGesture()
                        .onChanged { value in
                            let proposed = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                            offset = clamped(proposed, vpWidth: vpWidth, vpHeight: vpHeight)
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
            )
    }

    // MARK: - Layout

    private func viewportSize(in geo: GeometryProxy) -> CGSize {
        let topPad = max(geo.safeAreaInsets.top, 16) + 16
        let bottomPad = max(geo.safeAreaInsets.bottom, 16) + 80
        let maxWidth = max(160, geo.size.width - 32)
        let maxHeight = max(160, geo.size.height - topPad - bottomPad)
        let fittedWidth = min(maxWidth, maxHeight * DishImageSpec.viewportAspectRatio)
        return CGSize(width: fittedWidth, height: fittedWidth / DishImageSpec.viewportAspectRatio)
    }

    private func aspectFillFrame(for imageSize: CGSize, vpWidth: CGFloat, vpHeight: CGFloat) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGSize(width: vpWidth, height: vpHeight)
        }
        let fillScale = max(vpWidth / imageSize.width, vpHeight / imageSize.height)
        return CGSize(width: imageSize.width * fillScale, height: imageSize.height * fillScale)
    }

    private func clamped(_ proposed: CGSize, vpWidth: CGFloat, vpHeight: CGFloat) -> CGSize {
        let baseFrame = aspectFillFrame(for: displayImage.size, vpWidth: vpWidth, vpHeight: vpHeight)
        let maxX = max(0, (baseFrame.width * scale - vpWidth) / 2)
        let maxY = max(0, (baseFrame.height * scale - vpHeight) / 2)
        return CGSize(
            width: proposed.width.clamped(to: -maxX...maxX),
            height: proposed.height.clamped(to: -maxY...maxY)
        )
    }

    // MARK: - Crop output

    private func crop(viewportCenter: CGPoint, vpY: CGFloat, vpWidth: CGFloat, vpHeight: CGFloat) {
        let img = displayImage
        let baseFrame = aspectFillFrame(for: img.size, vpWidth: vpWidth, vpHeight: vpHeight)
        let canvasW = baseFrame.width * scale
        let canvasH = baseFrame.height * scale
        let imageLeft = viewportCenter.x + offset.width - canvasW / 2
        let imageTop = viewportCenter.y + offset.height - canvasH / 2

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let outputSize = DishImageSpec.outputSize
        let outputScale = outputSize.width / vpWidth
        let vpLeft = viewportCenter.x - vpWidth / 2
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        let out = renderer.image { _ in
            let drawRect = CGRect(
                x: (imageLeft - vpLeft) * outputScale,
                y: (imageTop - vpY) * outputScale,
                width: canvasW * outputScale,
                height: canvasH * outputScale
            )
            img.drawAspectFill(in: drawRect)
        }
        onConfirm(out)
    }

    // MARK: - Vision framing

    @MainActor
    private func applySuggestedFraming(vpWidth: CGFloat, vpHeight: CGFloat) async {
        guard suggestedScale <= 1.0001 else { return }

        guard let framing = await Self.visionFraming(for: displayImage, vpWidth: vpWidth, vpHeight: vpHeight) else {
            setFraming(scale: 1.0, offset: .zero, vpWidth: vpWidth, vpHeight: vpHeight)
            return
        }
        setFraming(scale: framing.scale, offset: framing.offset, vpWidth: vpWidth, vpHeight: vpHeight)
    }

    @MainActor
    private func setFraming(scale: CGFloat, offset: CGSize, vpWidth: CGFloat, vpHeight: CGFloat) {
        self.scale = max(minimumScale, scale)
        self.lastScale = self.scale
        let clampedOffset = clamped(offset, vpWidth: vpWidth, vpHeight: vpHeight)
        self.offset = clampedOffset
        self.lastOffset = clampedOffset
        self.suggestedScale = self.scale
    }

    private static func visionFraming(for image: UIImage, vpWidth: CGFloat, vpHeight: CGFloat) async -> (scale: CGFloat, offset: CGSize)? {
        await Task.detached(priority: .userInitiated) {
            guard let cgImage = image.scaledDown(toLongSide: 1024).cgImage else { return nil }

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
}

// MARK: - UIImage helpers

private extension UIImage {
    nonisolated func normalizedForCrop() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }

    func drawAspectFill(in rect: CGRect) {
        guard size.width > 0, size.height > 0 else { return }
        let s = max(rect.width / size.width, rect.height / size.height)
        let dw = size.width * s
        let dh = size.height * s
        draw(in: CGRect(x: rect.midX - dw / 2, y: rect.midY - dh / 2, width: dw, height: dh))
    }
}

// MARK: - VNInstanceMaskObservation helper

private extension VNInstanceMaskObservation {
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

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    DishPhotoCropView(
        sourceImage: {
            let size = CGSize(width: 1200, height: 900)
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
                let colors = [UIColor.systemOrange, UIColor.systemYellow, UIColor.systemPink]
                let gradient = CGGradient(
                    colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: colors.map(\.cgColor) as CFArray,
                    locations: [0, 0.5, 1]
                )!
                ctx.cgContext.drawLinearGradient(
                    gradient,
                    start: .zero,
                    end: CGPoint(x: size.width, y: size.height),
                    options: []
                )
                let label = "预览图" as NSString
                label.draw(
                    at: CGPoint(x: size.width / 2 - 40, y: size.height / 2 - 20),
                    withAttributes: [.font: UIFont.systemFont(ofSize: 40, weight: .bold), .foregroundColor: UIColor.white]
                )
            }
        }(),
        onConfirm: { _ in },
        onCancel: {}
    )
}
