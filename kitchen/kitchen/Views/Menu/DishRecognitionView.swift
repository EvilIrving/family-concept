import SwiftUI
import Vision
import CoreImage

/// 两阶段菜品识别页：
/// 1. 编辑态 — 用户在 1:1 取景框内拖动、缩放原图；
/// 2. 识别态 — 对取景框内子图执行 Vision 前景抠图，生成主体最长边占画布 80%
///    的透明背景 1:1 PNG；`onConfirm` 返回的是该抠图成品。
struct DishRecognitionView: View {
    enum Source { case album, camera }

    fileprivate enum Phase {
        case editing
        case recognizing(subimage: UIImage)
        case recognized(subimage: UIImage, finalImage: UIImage)
    }

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

    private var isEditing: Bool {
        if case .editing = phase { return true }
        return false
    }

    private var isRecognizing: Bool {
        if case .recognizing = phase { return true }
        return false
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

                if isEditing {
                    DishRecognitionCanvas(
                        displayImage: displayImage,
                        scale: scale,
                        offset: offset,
                        isEditing: isEditing,
                        vpWidth: vpWidth,
                        vpHeight: vpHeight,
                        viewportCenter: viewportCenter,
                        containerSize: geo.size
                    )
                    .gesture(gesture(vpWidth: vpWidth, vpHeight: vpHeight))

                    DishRecognitionDarkOverlay(
                        vpWidth: vpWidth,
                        vpHeight: vpHeight,
                        viewportCenter: viewportCenter,
                        containerSize: geo.size
                    )
                } else {
                    DishRecognitionRecognizedView(vpWidth: vpWidth, vpHeight: vpHeight)
                        .position(x: viewportCenter.x, y: viewportCenter.y)
                }

                DishRecognitionViewportBorder(isEditing: isEditing, vpWidth: vpWidth, vpHeight: vpHeight)
                    .position(x: viewportCenter.x, y: viewportCenter.y)

                DishRecognitionActionButtons(
                    phase: phase,
                    source: source,
                    isRecognizing: isRecognizing,
                    geo: geo,
                    vpWidth: vpWidth,
                    vpY: vpY,
                    vpHeight: vpHeight,
                    viewportCenter: viewportCenter,
                    onCancel: onCancel,
                    onRecognize: { handleRightTap(viewportCenter: viewportCenter, vpY: vpY, vpWidth: vpWidth, vpHeight: vpHeight) },
                    onConfirm: { handleConfirm() }
                )

                if case .recognizing(let subimage) = phase {
                    DishRecognitionRecognizingOverlay(
                        subimage: subimage,
                        vpWidth: vpWidth,
                        vpHeight: vpHeight,
                        viewportCenter: viewportCenter
                    )
                    .transition(.opacity)
                }

                if case let .recognized(_, finalImage) = phase {
                    DishRecognitionFinalPreview(
                        finalImage: finalImage,
                        vpWidth: vpWidth,
                        vpHeight: vpHeight,
                        viewportCenter: viewportCenter
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .top) {
                DishRecognitionTopBar(onCancel: onCancel, isRecognizing: isRecognizing)
            }
            .task(id: sourceImage) {
                let img = await Task.detached(priority: .userInitiated) {
                    sourceImage.normalizedForCrop()
                }.value
                normalizedImage = img
                await applySuggestedFraming(vpWidth: vpWidth, vpHeight: vpHeight)
            }
        }
    }

    // MARK: - Gesture

    private func gesture(vpWidth: CGFloat, vpHeight: CGFloat) -> some Gesture {
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

    private func clamped(_ proposed: CGSize, vpWidth: CGFloat, vpHeight: CGFloat) -> CGSize {
        let baseFrame = aspectFillFrame(for: displayImage.size, vpWidth: vpWidth, vpHeight: vpHeight)
        let maxX = max(0, (baseFrame.width * scale - vpWidth) / 2)
        let maxY = max(0, (baseFrame.height * scale - vpHeight) / 2)
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

    // MARK: - Vision framing

    @MainActor
    private func applySuggestedFraming(vpWidth: CGFloat, vpHeight: CGFloat) async {
        guard suggestedScale <= 1.0001 else { return }

        guard let framing = await DishImageProcessor.visionFraming(for: displayImage, vpWidth: vpWidth, vpHeight: vpHeight) else {
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

    // MARK: - Actions

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

    private func handleConfirm() {
        if case let .recognized(_, finalImage) = phase {
            onConfirm(finalImage)
        }
    }
}

// MARK: - Supporting Views (local to this file)

private struct DishRecognitionRecognizedView: View {
    let vpWidth: CGFloat
    let vpHeight: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: DishImageSpec.viewportCornerRadius)
            .fill(AppComponentColor.Cropper.backdrop)
            .frame(width: vpWidth, height: vpHeight)
            .allowsHitTesting(false)
    }
}

private struct DishRecognitionViewportBorder: View {
    let isEditing: Bool
    let vpWidth: CGFloat
    let vpHeight: CGFloat

    var body: some View {
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
}

private struct DishRecognitionActionButtons: View {
    let phase: DishRecognitionView.Phase
    let source: DishRecognitionView.Source
    let isRecognizing: Bool
    let geo: GeometryProxy
    let vpWidth: CGFloat
    let vpY: CGFloat
    let vpHeight: CGFloat
    let viewportCenter: CGPoint
    let onCancel: () -> Void
    let onRecognize: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        let buttonBottomInset = max(geo.safeAreaInsets.bottom, 16) + 12
        let buttonRowY = geo.size.height - buttonBottomInset - (AppDimension.minTouchTarget / 2)
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
            Button(action: onCancel) {
                Text(leftLabel)
                    .cropActionLabel()
            }
            .buttonStyle(.plain)
            .disabled(isRecognizing)

            Spacer()

            Button(action: onRecognize) {
                Text(rightLabel)
                    .cropActionLabel()
            }
            .buttonStyle(.plain)
            .disabled(isRecognizing)
        }
        .padding(.horizontal, buttonInset)
        .frame(width: geo.size.width)
        .position(x: geo.size.width / 2, y: buttonRowY)
        .opacity(isRecognizing ? 0 : 1)
    }
}

private struct DishRecognitionTopBar: View {
    let onCancel: () -> Void
    let isRecognizing: Bool

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Button(action: onCancel) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppComponentColor.Cropper.controlForeground)
                    .frame(width: AppDimension.minTouchTarget, height: AppDimension.minTouchTarget)
                    .background(AppComponentColor.Cropper.controlForeground.opacity(0.12), in: Circle())
                    .overlay(
                        Circle()
                            .stroke(AppComponentColor.Cropper.controlBorder, lineWidth: AppBorderWidth.hairline)
                    )
            }
            .buttonStyle(.plain)
            .disabled(isRecognizing)
            .accessibilityLabel("返回")

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.bottom, AppSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clear)
    }
}

private extension View {
    func cropActionLabel() -> some View {
        self
            .font(AppTypography.button)
            .foregroundStyle(AppComponentColor.Cropper.controlForeground)
            .frame(minHeight: AppDimension.minTouchTarget)
            .padding(.horizontal, AppSpacing.md)
            .background(AppComponentColor.Cropper.controlForeground.opacity(0.12), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppComponentColor.Cropper.controlBorder, lineWidth: AppBorderWidth.hairline)
            )
            .contentShape(Capsule())
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

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

#Preview {
    DishRecognitionView(
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
