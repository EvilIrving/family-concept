import SwiftUI
import UIKit

struct DishRecognitionView: View {
    enum Source { case album, camera }

    fileprivate enum Phase {
        case framing
        case processing(UIImage)
        case preview(PreviewResult)
    }

    fileprivate struct PreviewResult {
        let previewImage: UIImage
        let finalImage: UIImage
    }

    private let minimumScale: CGFloat = 0.5

    let sourceImage: UIImage
    let source: Source
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var framingScale: CGFloat = 1
    @State private var lastFramingScale: CGFloat = 1
    @State private var framingOffset: CGSize = .zero
    @State private var lastFramingOffset: CGSize = .zero
    @State private var normalizedImage: UIImage?
    @State private var phase: Phase = .framing

    private var displayImage: UIImage { normalizedImage ?? sourceImage }

    private var isFraming: Bool {
        if case .framing = phase { return true }
        return false
    }

    private var isProcessing: Bool {
        if case .processing = phase { return true }
        return false
    }

    private var currentPreview: PreviewResult? {
        if case .preview(let result) = phase { return result }
        return nil
    }

    private var currentProcessingImage: UIImage? {
        if case .processing(let image) = phase { return image }
        return nil
    }

    var body: some View {
        GeometryReader { geo in
            let viewportSize = viewportSize(in: geo)
            let viewportCenter = viewportCenter(in: geo, viewportSize: viewportSize)

            ZStack {
                ZStack {
                    Color(AppSemanticColor.surface)
                        .ignoresSafeArea()
                }
                .overlay {
                    if currentPreview != nil {
                        RoundedRectangle(
                            cornerRadius: DishImageSpec.viewportCornerRadius,
                            style: .continuous
                        )
                        .frame(width: viewportSize.width, height: viewportSize.height)
                        .position(x: viewportCenter.x, y: viewportCenter.y)
                        .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()

                if isFraming {
                    DishRecognitionCanvas(
                        displayImage: displayImage,
                        scale: framingScale,
                        offset: framingOffset,
                        viewportSize: viewportSize,
                        viewportCenter: viewportCenter,
                        containerSize: geo.size
                    )
                    .gesture(framingGesture(viewportSize: viewportSize))

                    DishRecognitionDarkOverlay(
                        vpWidth: viewportSize.width,
                        vpHeight: viewportSize.height,
                        viewportCenter: viewportCenter,
                        containerSize: geo.size
                    )
                }

                DishRecognitionViewportFrame(
                    vpWidth: viewportSize.width,
                    vpHeight: viewportSize.height
                )
                .position(x: viewportCenter.x, y: viewportCenter.y)

                if let preview = currentPreview {
                    DishRecognitionPreviewCanvas(
                        previewImage: preview.previewImage,
                        viewportSize: viewportSize
                    )
                    .position(x: viewportCenter.x, y: viewportCenter.y)
                    .transition(.opacity)
                } else if let processingImage = currentProcessingImage {
                    DishRecognitionProcessingCanvas(
                        image: processingImage,
                        viewportSize: viewportSize
                    )
                    .position(x: viewportCenter.x, y: viewportCenter.y)
                }

                DishRecognitionBottomPanel(
                    phase: phase,
                    source: source,
                    onPrimaryTap: {
                        handlePrimaryTap(viewportCenter: viewportCenter, viewportSize: viewportSize)
                    },
                    onSecondaryTap: handleSecondaryTap
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                DishRecognitionTopBar(
                    onBack: handleBack,
                    isProcessing: isProcessing
                )
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .task(id: sourceImage) {
                let image = await Task.detached(priority: .userInitiated) {
                    sourceImage.normalizedForCrop()
                }.value
                normalizedImage = image
            }
        }
    }

    private func viewportCenter(in geo: GeometryProxy, viewportSize: CGSize) -> CGPoint {
        let topInset = max(geo.safeAreaInsets.top, 16) + 64
        let bottomInset = max(geo.safeAreaInsets.bottom, 16) + 178
        let availableHeight = geo.size.height - topInset - bottomInset
        let centerY = topInset + max(viewportSize.height / 2, availableHeight / 2)
        return CGPoint(x: geo.size.width / 2, y: centerY)
    }

    private func viewportSize(in geo: GeometryProxy) -> CGSize {
        let topInset = max(geo.safeAreaInsets.top, 16) + 64
        let bottomInset = max(geo.safeAreaInsets.bottom, 16) + 178
        let maxWidth = max(220, geo.size.width - 32)
        let maxHeight = max(220, geo.size.height - topInset - bottomInset)
        let width = min(maxWidth, maxHeight * DishImageSpec.viewportAspectRatio)
        return CGSize(width: width, height: width / DishImageSpec.viewportAspectRatio)
    }

    private func framingGesture(viewportSize: CGSize) -> some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    guard isFraming else { return }
                    framingScale = max(minimumScale, lastFramingScale * value)
                    framingOffset = clampedFramingOffset(framingOffset, viewportSize: viewportSize)
                }
                .onEnded { _ in
                    lastFramingScale = framingScale
                    lastFramingOffset = framingOffset
                },
            DragGesture()
                .onChanged { value in
                    guard isFraming else { return }
                    let proposed = CGSize(
                        width: lastFramingOffset.width + value.translation.width,
                        height: lastFramingOffset.height + value.translation.height
                    )
                    framingOffset = clampedFramingOffset(proposed, viewportSize: viewportSize)
                }
                .onEnded { _ in
                    lastFramingOffset = framingOffset
                }
        )
    }

    private func clampedFramingOffset(_ proposed: CGSize, viewportSize: CGSize) -> CGSize {
        let baseFrame = dishRecognitionAspectFillFrame(for: displayImage.size, viewportSize: viewportSize)

        let maxX = max(0, (baseFrame.width * framingScale - viewportSize.width) / 2)
        let maxY = max(0, (baseFrame.height * framingScale - viewportSize.height) / 2)
        return CGSize(
            width: proposed.width.clamped(to: -maxX...maxX),
            height: proposed.height.clamped(to: -maxY...maxY)
        )
    }

    private func viewportSubimage(viewportCenter: CGPoint, viewportSize: CGSize) -> UIImage? {
        let image = displayImage
        guard let cgImage = image.cgImage, image.size.width > 0, image.size.height > 0 else { return nil }

        let baseFrame = dishRecognitionAspectFillFrame(for: image.size, viewportSize: viewportSize)

        let pixelsPerScreenPoint = image.size.width / (baseFrame.width * framingScale)
        let imageLeft = viewportCenter.x + framingOffset.width - (baseFrame.width * framingScale) / 2
        let imageTop = viewportCenter.y + framingOffset.height - (baseFrame.height * framingScale) / 2
        let viewportLeft = viewportCenter.x - viewportSize.width / 2
        let viewportTop = viewportCenter.y - viewportSize.height / 2

        var cropRect = CGRect(
            x: (viewportLeft - imageLeft) * pixelsPerScreenPoint,
            y: (viewportTop - imageTop) * pixelsPerScreenPoint,
            width: viewportSize.width * pixelsPerScreenPoint,
            height: viewportSize.height * pixelsPerScreenPoint
        )
        cropRect = cropRect.integral.intersection(
            CGRect(origin: .zero, size: CGSize(width: cgImage.width, height: cgImage.height))
        )

        guard cropRect.width >= 1,
              cropRect.height >= 1,
              let cropped = cgImage.cropping(to: cropRect)
        else {
            return nil
        }

        return UIImage(cgImage: cropped, scale: 1, orientation: .up)
    }

    private func handlePrimaryTap(viewportCenter: CGPoint, viewportSize: CGSize) {
        switch phase {
        case .framing:
            guard let subimage = viewportSubimage(viewportCenter: viewportCenter, viewportSize: viewportSize) else { return }
            HapticManager.shared.triggerLightImpact()
            withAnimation(.easeInOut(duration: 0.18)) {
                phase = .processing(subimage)
            }
            Task {
                let composition = await DishImageProcessor.analyzeComposition(from: subimage)
                let finalImage = DishImageProcessor.renderFinalImage(
                    from: composition,
                    transform: composition.suggestedTransform
                )
                let result = PreviewResult(
                    previewImage: composition.foregroundImage,
                    finalImage: finalImage
                )
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        phase = .preview(result)
                    }
                    HapticManager.shared.triggerMediumImpact()
                }
            }
        case .processing:
            break
        case .preview(let result):
            onConfirm(result.finalImage)
        }
    }

    private func handleSecondaryTap() {
        switch phase {
        case .framing:
            onCancel()
        case .processing:
            break
        case .preview:
            withAnimation(.easeInOut(duration: 0.18)) {
                phase = .framing
            }
        }
    }

    private func handleBack() {
        switch phase {
        case .framing:
            onCancel()
        case .processing:
            break
        case .preview:
            withAnimation(.easeInOut(duration: 0.18)) {
                phase = .framing
            }
        }
    }
}

private struct DishRecognitionViewportFrame: View {
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
    }
}

private struct DishRecognitionProcessingCanvas: View {
    let image: UIImage
    let viewportSize: CGSize

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .frame(width: viewportSize.width, height: viewportSize.height)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: DishImageSpec.viewportCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                ZStack {
                    Color.black.opacity(0.36)
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
            }
    }
}

private struct DishRecognitionBottomPanel: View {
    let phase: DishRecognitionView.Phase
    let source: DishRecognitionView.Source
    let onPrimaryTap: () -> Void
    let onSecondaryTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(AppTypography.body)
                    .foregroundStyle(Color.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: AppSpacing.sm) {
                Button(action: onSecondaryTap) {
                    Text(secondaryTitle)
                        .recognitionSecondaryButtonStyle()
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)

                Button(action: onPrimaryTap) {
                    if isProcessing {
                        HStack(spacing: AppSpacing.xs) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(AppComponentColor.Cropper.confirmForeground)
                            Text(primaryTitle)
                        }
                        .recognitionPrimaryButtonStyle()
                    } else {
                        Text(primaryTitle)
                            .recognitionPrimaryButtonStyle()
                    }
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, 20)
    }

    private var isProcessing: Bool {
        if case .processing = phase { return true }
        return false
    }

    private var title: String {
        switch phase {
        case .framing:
            return "框选菜品"
        case .processing:
            return "正在识别框内内容"
        case .preview:
            return "预览识别结果"
        }
    }

    private var subtitle: String {
        switch phase {
        case .framing:
            return "调整图片位置和大小，让要识别的菜品完整落在取景框内。"
        case .processing:
            return "系统正在对取景框内的图像执行 Vision 前景识别。"
        case .preview:
            return "这是根据取景框内容生成的预览图，不满意可以返回重新框选。"
        }
    }

    private var primaryTitle: String {
        switch phase {
        case .framing:
            return "识别"
        case .processing:
            return "处理中"
        case .preview:
            return "确认使用"
        }
    }

    private var secondaryTitle: String {
        switch phase {
        case .framing, .processing:
            return source == .album ? "重新选图" : "重新拍照"
        case .preview:
            return "重新框选"
        }
    }
}

private struct DishRecognitionTopBar: View {
    let onBack: () -> Void
    let isProcessing: Bool

    var body: some View {
        VStack {
            HStack {
                Button(action: onBack) {
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
                .disabled(isProcessing)
                .accessibilityLabel("返回")

                Spacer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.md)

            Spacer()
        }
    }
}

private extension View {
    func recognitionPrimaryButtonStyle() -> some View {
        self
            .font(AppTypography.button)
            .foregroundStyle(AppComponentColor.Cropper.confirmForeground)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(AppComponentColor.Cropper.confirmBackground, in: Capsule())
    }

    func recognitionSecondaryButtonStyle() -> some View {
        self
            .font(AppTypography.button)
            .foregroundStyle(AppComponentColor.Cropper.controlForeground)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(AppComponentColor.Cropper.controlForeground.opacity(0.12), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(AppComponentColor.Cropper.controlBorder, lineWidth: AppBorderWidth.hairline)
            )
    }
}

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
