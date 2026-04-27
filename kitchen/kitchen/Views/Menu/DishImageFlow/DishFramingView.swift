import SwiftUI
import UIKit

struct DishFramingView: View {
    enum InputSource { case album, camera }

    private let minimumScale: CGFloat = 0.5

    let sourceImage: UIImage
    let inputSource: InputSource
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var framingScale: CGFloat = 1
    @State private var lastFramingScale: CGFloat = 1
    @State private var framingOffset: CGSize = .zero
    @State private var lastFramingOffset: CGSize = .zero
    @State private var normalizedImage: UIImage?

    private var displayImage: UIImage { normalizedImage ?? sourceImage }

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
                    RoundedRectangle(
                        cornerRadius: DishImageSpec.viewportCornerRadius,
                        style: .continuous
                    )
                    .frame(width: viewportSize.width, height: viewportSize.height)
                    .position(x: viewportCenter.x, y: viewportCenter.y)
                    .blendMode(.destinationOut)
                }
                .compositingGroup()

                DishFramingCanvas(
                    displayImage: displayImage,
                    scale: framingScale,
                    offset: framingOffset,
                    viewportCenter: viewportCenter,
                    containerSize: geo.size
                )
                .gesture(framingGesture(viewportSize: viewportSize, containerSize: geo.size))

                DishFramingMaskOverlay(
                    vpWidth: viewportSize.width,
                    vpHeight: viewportSize.height,
                    viewportCenter: viewportCenter,
                    containerSize: geo.size
                )

                DishFramingViewportFrame(
                    vpWidth: viewportSize.width,
                    vpHeight: viewportSize.height
                )
                .position(x: viewportCenter.x, y: viewportCenter.y)

                DishFramingBottomPanel(
                    inputSource: inputSource,
                    onPrimaryTap: {
                        handlePrimaryTap(
                            viewportCenter: viewportCenter,
                            viewportSize: viewportSize,
                            containerSize: geo.size
                        )
                    },
                    onSecondaryTap: handleSecondaryTap
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                DishFramingTopBar(
                    onBack: handleBack,
                    isProcessing: false
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
        let targetWidth = geo.size.width * 0.7
        let maxWidth = max(220, targetWidth)
        let maxHeight = max(220, geo.size.height - topInset - bottomInset)
        let width = min(maxWidth, maxHeight * DishImageSpec.viewportAspectRatio)
        return CGSize(width: width, height: width / DishImageSpec.viewportAspectRatio)
    }

    private func framingGesture(viewportSize: CGSize, containerSize: CGSize) -> some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    framingScale = max(minimumScale, lastFramingScale * value)
                    framingOffset = clampedFramingOffset(
                        framingOffset,
                        viewportSize: viewportSize,
                        containerSize: containerSize
                    )
                }
                .onEnded { _ in
                    lastFramingScale = framingScale
                    lastFramingOffset = framingOffset
                },
            DragGesture()
                .onChanged { value in
                    let proposed = CGSize(
                        width: lastFramingOffset.width + value.translation.width,
                        height: lastFramingOffset.height + value.translation.height
                    )
                    framingOffset = clampedFramingOffset(
                        proposed,
                        viewportSize: viewportSize,
                        containerSize: containerSize
                    )
                }
                .onEnded { _ in
                    lastFramingOffset = framingOffset
                }
        )
    }

    private func clampedFramingOffset(_ proposed: CGSize, viewportSize: CGSize, containerSize: CGSize) -> CGSize {
        let baseFrame = dishFramingAspectFillSize(for: displayImage.size, containerSize: containerSize)

        let maxX = max(0, (baseFrame.width * framingScale - viewportSize.width) / 2)
        let maxY = max(0, (baseFrame.height * framingScale - viewportSize.height) / 2)
        return CGSize(
            width: proposed.width.clamped(to: -maxX...maxX),
            height: proposed.height.clamped(to: -maxY...maxY)
        )
    }

    private func viewportSubimage(viewportCenter: CGPoint, viewportSize: CGSize, containerSize: CGSize) -> UIImage? {
        let image = displayImage
        guard let cgImage = image.cgImage, image.size.width > 0, image.size.height > 0 else { return nil }

        let baseFrame = dishFramingAspectFillSize(for: image.size, containerSize: containerSize)

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

    private func handlePrimaryTap(viewportCenter: CGPoint, viewportSize: CGSize, containerSize: CGSize) {
        guard let subimage = viewportSubimage(
            viewportCenter: viewportCenter,
            viewportSize: viewportSize,
            containerSize: containerSize
        ) else { return }
        HapticManager.shared.triggerMediumImpact()
        onConfirm(subimage)
    }

    private func handleSecondaryTap() {
        onCancel()
    }

    private func handleBack() {
        onCancel()
    }
}

private struct DishFramingViewportFrame: View {
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

private struct DishFramingBottomPanel: View {
    let inputSource: DishFramingView.InputSource
    let onPrimaryTap: () -> Void
    let onSecondaryTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                AppButton(title: secondaryTitle, role: .ghost, haptic: .custom(.selection)) {
                    onSecondaryTap()
                }

                AppButton(title: primaryTitle, role: .primary, haptic: .custom(.light)) {
                    onPrimaryTap()
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.lg)
        .padding(.bottom, 20)
    }

    private var primaryTitle: String {
        "使用框内图片"
    }

    private var secondaryTitle: String {
        inputSource == .album ? "重新选图" : "重新拍照"
    }
}

private struct DishFramingTopBar: View {
    let onBack: () -> Void
    let isProcessing: Bool

    var body: some View {
        VStack {
            HStack {
                AppIconActionButton(systemImage: "chevron.left", tone: .neutral, size: .lg) {
                    onBack()
                }
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
