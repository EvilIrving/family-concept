import SwiftUI
import Vision
import CoreImage

/// 两阶段菜品图确认页：
/// 1. 编辑态 — 用户在 1:1 取景框内拖动、缩放原图；
/// 2. 识别态 — 对取景框内子图执行 Vision 前景抠图，生成主体最长边占画布 80%
///    的透明背景 1:1 PNG；`onConfirm` 返回的是该抠图成品。
struct DishPhotoCropView: View {
    enum Source { case album, camera }

    private let minimumScale: CGFloat = 0.5

    let sourceImage: UIImage
    let source: Source
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var suggestedScale: CGFloat = 1.0
    @State private var normalizedImage: UIImage?
    @State private var phase: Phase = .editing

    private enum Phase {
        case editing
        case recognizing(subimage: UIImage)
        case recognized(subimage: UIImage, finalImage: UIImage)
    }

    private var isEditing: Bool {
        if case .editing = phase { return true }
        return false
    }

    private var isRecognizing: Bool {
        if case .recognizing = phase { return true }
        return false
    }

    private var recognizedFinalImage: UIImage? {
        if case let .recognized(_, finalImage) = phase { return finalImage }
        return nil
    }

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
                AppComponentColor.Cropper.backdrop.ignoresSafeArea()

                cropCanvas(vpWidth: vpWidth, vpHeight: vpHeight, viewportCenter: viewportCenter, containerSize: geo.size)

                darkOverlay(geo: geo, viewportCenter: viewportCenter, vpWidth: vpWidth, vpHeight: vpHeight)

                viewportBorder(vpWidth: vpWidth, vpHeight: vpHeight)
                    .position(x: viewportCenter.x, y: viewportCenter.y)

                actionButtons(geo: geo, vpWidth: vpWidth, vpY: vpY, vpHeight: vpHeight, viewportCenter: viewportCenter)

                if case .recognizing(let subimage) = phase {
                    DishConfirmDissolveView(
                        sourceImage: subimage,
                        produceFinal: { await Self.composeFinalImage(from: subimage) },
                        onFinish: { finalImage in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                phase = .recognized(subimage: subimage, finalImage: finalImage)
                            }
                        }
                    )
                    .transition(.opacity)
                }

                if case let .recognized(_, finalImage) = phase {
                    Image(uiImage: finalImage)
                        .resizable()
                        .scaledToFit()
                        .padding(16)
                        .frame(width: vpWidth, height: vpHeight)
                        .position(x: viewportCenter.x, y: viewportCenter.y)
                        .transition(.opacity)
                }
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
            .fill(AppComponentColor.Cropper.overlay)
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
            RoundedRectangle(cornerRadius: DishImageSpec.viewportCornerRadius)
                .strokeBorder(AppComponentColor.Cropper.viewportBorder, lineWidth: AppBorderWidth.strong + 0.5)
                .frame(width: vpWidth, height: vpHeight)

            RoundedRectangle(cornerRadius: DishImageSpec.viewportCornerRadius)
                .strokeBorder(AppComponentColor.Cropper.viewportShadow, lineWidth: 18)
                .blur(radius: 12)
                .frame(width: vpWidth, height: vpHeight)
                .clipShape(RoundedRectangle(cornerRadius: DishImageSpec.viewportCornerRadius))
        }
        .allowsHitTesting(false)
        .opacity(isEditing ? 1 : 0)
    }

    @ViewBuilder
    private func actionButtons(geo: GeometryProxy, vpWidth: CGFloat, vpY: CGFloat, vpHeight: CGFloat, viewportCenter: CGPoint) -> some View {
        let spaceBelow = geo.size.height - geo.safeAreaInsets.bottom - (vpY + vpHeight)
        let buttonRowY = vpY + vpHeight + spaceBelow / 2
        let buttonInset = (geo.size.width - vpWidth) / 2 + 8

        let leftLabel: String = {
            switch phase {
            case .editing, .recognizing:
                return source == .album ? "重新选图" : "重新拍照"
            case .recognized:
                return "重新识别"
            }
        }()
        let rightLabel: String = {
            if case .recognized = phase { return "确认" }
            return "识别"
        }()

        HStack(spacing: 0) {
            Button(action: handleLeftTap) {
                Text(leftLabel)
                    .font(AppTypography.button)
                    .foregroundStyle(AppComponentColor.Cropper.controlForeground)
                    .frame(minHeight: AppDimension.minTouchTarget)
                    .padding(.horizontal, AppSpacing.md)
                    .contentShape(Rectangle())
            }
            .disabled(isRecognizing)

            Spacer()

            Button(action: { handleRightTap(viewportCenter: viewportCenter, vpY: vpY, vpWidth: vpWidth, vpHeight: vpHeight) }) {
                Text(rightLabel)
                    .font(AppTypography.button)
                    .foregroundStyle(AppComponentColor.Cropper.confirmForeground)
                    .frame(minHeight: AppDimension.minTouchTarget)
                    .padding(.horizontal, AppSpacing.md)
                    .contentShape(Rectangle())
            }
            .disabled(isRecognizing)
        }
        .padding(.horizontal, buttonInset)
        .frame(width: geo.size.width)
        .position(x: geo.size.width / 2, y: buttonRowY)
        .opacity(isRecognizing ? 0 : 1)
    }

    private func handleLeftTap() {
        switch phase {
        case .editing:
            onCancel()
        case .recognizing:
            break
        case .recognized:
            withAnimation(.easeInOut(duration: 0.2)) {
                phase = .editing
            }
        }
    }

    private func handleRightTap(viewportCenter: CGPoint, vpY: CGFloat, vpWidth: CGFloat, vpHeight: CGFloat) {
        switch phase {
        case .editing:
            beginRecognition(viewportCenter: viewportCenter, vpY: vpY, vpWidth: vpWidth, vpHeight: vpHeight)
        case .recognizing:
            break
        case .recognized(_, let finalImage):
            onConfirm(finalImage)
        }
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
                            guard isEditing else { return }
                            scale = max(minimumScale, lastScale * value)
                            offset = clamped(offset, vpWidth: vpWidth, vpHeight: vpHeight)
                        }
                        .onEnded { _ in
                            lastScale = scale
                            lastOffset = offset
                        },
                    DragGesture()
                        .onChanged { value in
                            guard isEditing else { return }
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

    // MARK: - Extraction entry

    private func beginRecognition(viewportCenter: CGPoint, vpY: CGFloat, vpWidth: CGFloat, vpHeight: CGFloat) {
        guard isEditing else { return }
        guard let subimage = viewportSubimage(
            viewportCenter: viewportCenter,
            vpY: vpY,
            vpWidth: vpWidth,
            vpHeight: vpHeight
        ) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            phase = .recognizing(subimage: subimage)
        }
    }

    private func viewportSubimage(viewportCenter: CGPoint, vpY: CGFloat, vpWidth: CGFloat, vpHeight: CGFloat) -> UIImage? {
        let img = displayImage
        guard let cg = img.cgImage, img.size.width > 0, img.size.height > 0 else { return nil }

        let baseFrame = aspectFillFrame(for: img.size, vpWidth: vpWidth, vpHeight: vpHeight)
        let pxPerScreen = img.size.width / (baseFrame.width * scale)

        let imageLeft = viewportCenter.x + offset.width - (baseFrame.width * scale) / 2
        let imageTop = viewportCenter.y + offset.height - (baseFrame.height * scale) / 2
        let vpLeft = viewportCenter.x - vpWidth / 2

        var rectPx = CGRect(
            x: (vpLeft - imageLeft) * pxPerScreen,
            y: (vpY - imageTop) * pxPerScreen,
            width: vpWidth * pxPerScreen,
            height: vpHeight * pxPerScreen
        )
        rectPx = rectPx.integral.intersection(CGRect(origin: .zero, size: CGSize(width: cg.width, height: cg.height)))
        guard rectPx.width >= 1, rectPx.height >= 1, let cropped = cg.cropping(to: rectPx) else { return nil }
        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }

    // MARK: - Vision framing (auto-suggest initial crop)

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

    // MARK: - Final composition

    static func composeFinalImage(from viewportSubimage: UIImage) async -> UIImage {
        if let extracted = await extractForeground(from: viewportSubimage) {
            return compose(foreground: extracted.image, bboxInPixels: extracted.bbox)
        }
        let fallbackBBox = CGRect(origin: .zero, size: viewportSubimage.size)
        return compose(foreground: viewportSubimage, bboxInPixels: fallbackBBox)
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

// MARK: - UIImage helpers

private extension UIImage {
    nonisolated func normalizedForCrop() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: size)) }
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
        source: .album,
        onConfirm: { _ in },
        onCancel: {}
    )
}
