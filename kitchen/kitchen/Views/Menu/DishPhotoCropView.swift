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
    @State private var isAnalyzing = false

    var body: some View {
        GeometryReader { geo in
            let layout = viewportLayout(in: geo)
            let vpWidth = layout.width
            let vpHeight = layout.height
            let vpY = (geo.size.height - vpHeight) / 2

            ZStack {
                Color.black.ignoresSafeArea()

                cropCanvas(vpWidth: vpWidth, vpHeight: vpHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Dim areas outside the viewport
                VStack(spacing: 0) {
                    Color.black.opacity(0.55).frame(height: vpY)
                    Color.clear.frame(height: vpHeight)
                    Color.black.opacity(0.55)
                }
                .allowsHitTesting(false)

                // Viewport border
                Rectangle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    .frame(width: vpWidth, height: vpHeight)
                    .clipShape(RoundedRectangle(cornerRadius: DishImageSpec.viewportCornerRadius))
                    .allowsHitTesting(false)

                viewportGuides(width: vpWidth, height: vpHeight)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    HStack {
                        Button("取消") { onCancel() }
                            .foregroundStyle(.white)
                            .frame(minWidth: 44, minHeight: 44)

                        Spacer()

                        Button("智能定位") {
                            Task {
                                await applySuggestedFraming(vpWidth: vpWidth, vpHeight: vpHeight, forceRefresh: true)
                            }
                        }
                        .foregroundStyle(.white.opacity(isAnalyzing ? 0.45 : 0.95))
                        .disabled(isAnalyzing)
                        .frame(minWidth: 44, minHeight: 44)

                        Button("确认") {
                            crop(geo: geo, vpY: vpY, vpWidth: vpWidth, vpHeight: vpHeight)
                        }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, max(geo.safeAreaInsets.top, 16) + AppSpacing.xs)
                    .padding(.bottom, AppSpacing.xs)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.78), Color.black.opacity(0.32), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    Spacer()

                    if isAnalyzing {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)
                            Text("正在识别菜品主体")
                                .font(AppTypography.body)
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(.bottom, max(geo.safeAreaInsets.bottom, 16) + AppSpacing.md)
                    }
                }
            }
            .task(id: sourceImage) {
                await applySuggestedFraming(vpWidth: vpWidth, vpHeight: vpHeight, forceRefresh: false)
            }
        }
    }

    @ViewBuilder
    private func viewportGuides(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [8, 6]))
                .frame(width: width * 0.82, height: height * 0.82)

            Circle()
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                .frame(width: min(width, height) * 0.72, height: min(width, height) * 0.72)
        }
    }

    private func cropCanvas(vpWidth: CGFloat, vpHeight: CGFloat) -> some View {
        let baseFrame = aspectFillFrame(for: sourceImage.normalizedForCrop().size, vpWidth: vpWidth, vpHeight: vpHeight)

        return Image(uiImage: sourceImage)
            .resizable()
            .frame(
                width: baseFrame.width * scale,
                height: baseFrame.height * scale
            )
            .offset(offset)
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

    private func clamped(_ proposed: CGSize, vpWidth: CGFloat, vpHeight: CGFloat) -> CGSize {
        let baseFrame = aspectFillFrame(for: sourceImage.normalizedForCrop().size, vpWidth: vpWidth, vpHeight: vpHeight)
        let scaledWidth = baseFrame.width * scale
        let scaledHeight = baseFrame.height * scale
        let maxX = max(0, (scaledWidth - vpWidth) / 2)
        let maxY = max(0, (scaledHeight - vpHeight) / 2)
        return CGSize(
            width: proposed.width.clamped(to: -maxX...maxX),
            height: proposed.height.clamped(to: -maxY...maxY)
        )
    }

    private func aspectFillFrame(for imageSize: CGSize, vpWidth: CGFloat, vpHeight: CGFloat) -> CGSize {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGSize(width: vpWidth, height: vpHeight)
        }

        let fillScale = max(vpWidth / imageSize.width, vpHeight / imageSize.height)
        return CGSize(width: imageSize.width * fillScale, height: imageSize.height * fillScale)
    }

    private func viewportLayout(in geo: GeometryProxy) -> CGSize {
        let maxWidth = max(160, geo.size.width - DishImageSpec.viewportHorizontalInset * 2)
        let topReserved = max(geo.safeAreaInsets.top, 16) + 84
        let bottomReserved = max(geo.safeAreaInsets.bottom, 16) + 108
        let maxHeight = max(160, geo.size.height - topReserved - bottomReserved)
        let fittedWidth = min(maxWidth, maxHeight * DishImageSpec.viewportAspectRatio)
        return CGSize(
            width: fittedWidth,
            height: fittedWidth / DishImageSpec.viewportAspectRatio
        )
    }

    /// 与 `Image` + `scaledToFill` 一致：先按比例铺满画布，再按视口与偏移裁切，避免 `draw(in:)` 拉伸整张图导致变形。
    private func crop(geo: GeometryProxy, vpY: CGFloat, vpWidth: CGFloat, vpHeight: CGFloat) {
        let normalized = sourceImage.normalizedForCrop()
        let baseFrame = aspectFillFrame(for: normalized.size, vpWidth: vpWidth, vpHeight: vpHeight)
        let canvasW = baseFrame.width * scale
        let canvasH = baseFrame.height * scale

        let w = geo.size.width
        let h = geo.size.height
        let imageLeft = w / 2 + offset.width - canvasW / 2
        let imageTop = h / 2 + offset.height - canvasH / 2

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        let outputSize = DishImageSpec.outputSize
        let outputScale = outputSize.width / vpWidth
        let viewportOrigin = CGPoint(x: 0, y: vpY)
        let renderer = UIGraphicsImageRenderer(size: outputSize, format: format)
        let out = renderer.image { _ in
            let drawRect = CGRect(
                x: (imageLeft - viewportOrigin.x) * outputScale,
                y: (imageTop - viewportOrigin.y) * outputScale,
                width: canvasW * outputScale,
                height: canvasH * outputScale
            )
            normalized.drawAspectFill(in: drawRect)
        }
        onConfirm(out)
    }

    @MainActor
    private func applySuggestedFraming(vpWidth: CGFloat, vpHeight: CGFloat, forceRefresh: Bool) async {
        if isAnalyzing { return }
        if !forceRefresh, suggestedScale > 1.0001 { return }

        isAnalyzing = true
        defer { isAnalyzing = false }

        guard let framing = await suggestedFraming(for: sourceImage, vpWidth: vpWidth, vpHeight: vpHeight) else {
            let fallback = fallbackFraming(for: sourceImage, vpWidth: vpWidth, vpHeight: vpHeight)
            setFraming(scale: fallback.scale, offset: fallback.offset, vpWidth: vpWidth, vpHeight: vpHeight)
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

    private func fallbackFraming(for image: UIImage, vpWidth: CGFloat, vpHeight: CGFloat) -> (scale: CGFloat, offset: CGSize) {
        let imageSize = image.normalizedForCrop().size
        guard imageSize.width > 0, imageSize.height > 0 else {
            return (1.12, .zero)
        }

        let fillScale = max(vpWidth / imageSize.width, vpHeight / imageSize.height)
        let displayWidth = imageSize.width * fillScale
        let displayHeight = imageSize.height * fillScale
        let widthScale = (vpWidth * 0.88) / min(displayWidth, vpWidth * 0.88)
        let heightScale = (vpHeight * 0.9) / min(displayHeight, vpHeight * 0.9)
        let suggested = max(minimumScale, min(widthScale, heightScale))
        return (suggested, .zero)
    }

    private func suggestedFraming(for image: UIImage, vpWidth: CGFloat, vpHeight: CGFloat) async -> (scale: CGFloat, offset: CGSize)? {
        guard let cgImage = image.normalizedForCrop().cgImage else { return nil }

        do {
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])

            guard let observation = request.results?.first else { return nil }
            let points = try observation.allPoints(in: cgImage)
            guard !points.isEmpty else { return nil }

            let bounds = points.reduce(into: CGRect.null) { partial, point in
                partial = partial.union(CGRect(x: point.x, y: point.y, width: 1, height: 1))
            }

            guard bounds.width > 0, bounds.height > 0 else { return nil }

            let imageSize = CGSize(width: cgImage.width, height: cgImage.height)
            let baseScale = max(vpWidth / imageSize.width, vpHeight / imageSize.height)
            let targetWidth = vpWidth * 0.82
            let targetHeight = vpHeight * 0.82
            let subjectWidth = bounds.width * baseScale
            let subjectHeight = bounds.height * baseScale

            let fitScale = max(subjectWidth / targetWidth, subjectHeight / targetHeight)
            let suggestedScale = max(minimumScale, fitScale)

            let imageCenter = CGPoint(x: imageSize.width / 2, y: imageSize.height / 2)
            // Vision mask points use a bottom-left origin; SwiftUI image offsets use a top-left visual space.
            let subjectCenter = CGPoint(
                x: bounds.midX,
                y: imageSize.height - bounds.midY
            )
            let centeredOffset = CGSize(
                width: (imageCenter.x - subjectCenter.x) * baseScale * suggestedScale,
                height: (imageCenter.y - subjectCenter.y) * baseScale * suggestedScale
            )

            return (suggestedScale, centeredOffset)
        } catch {
            return nil
        }
    }
}

private extension UIImage {
    /// 与 `DishImagePipeline` 一致：修正 EXIF 方向，避免裁切与后续处理错位。
    func normalizedForCrop() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
    }

    /// 在 `rect` 内按 UIViewContentMode.scaleAspectFill 绘制（不拉伸变形）。
    func drawAspectFill(in rect: CGRect) {
        let iw = size.width
        let ih = size.height
        guard iw > 0, ih > 0 else { return }
        let s = max(rect.width / iw, rect.height / ih)
        let dw = iw * s
        let dh = ih * s
        let ox = rect.midX - dw / 2
        let oy = rect.midY - dh / 2
        draw(in: CGRect(x: ox, y: oy, width: dw, height: dh))
    }
}

private extension VNInstanceMaskObservation {
    func allPoints(in cgImage: CGImage) throws -> [CGPoint] {
        let maskBuffer = try generateScaledMaskForImage(forInstances: allInstances, from: VNImageRequestHandler(cgImage: cgImage, options: [:]))
        CVPixelBufferLockBaseAddress(maskBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(maskBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(maskBuffer) else { return [] }

        let width = CVPixelBufferGetWidth(maskBuffer)
        let height = CVPixelBufferGetHeight(maskBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(maskBuffer)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        let scaleX = CGFloat(cgImage.width) / CGFloat(width)
        let scaleY = CGFloat(cgImage.height) / CGFloat(height)

        var points: [CGPoint] = []
        points.reserveCapacity(width * height / 4)

        for y in 0..<height {
            let row = buffer.advanced(by: y * bytesPerRow)
            for x in 0..<width where row[x] > 0 {
                points.append(
                    CGPoint(
                        x: CGFloat(x) * scaleX,
                        y: CGFloat(y) * scaleY
                    )
                )
            }
        }

        return points
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    DishPhotoCropView(
        sourceImage: UIImage(systemName: "photo")!,
        onConfirm: { _ in },
        onCancel: {}
    )
}
