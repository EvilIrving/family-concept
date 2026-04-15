import SwiftUI

struct DishPhotoCropView: View {
    let sourceImage: UIImage
    let onConfirm: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let vpWidth = geo.size.width
            let vpHeight = vpWidth / DishImageSpec.viewportAspectRatio
            let vpY = (geo.size.height - vpHeight) / 2

            ZStack {
                Color.black.ignoresSafeArea()

                Image(uiImage: sourceImage)
                    .resizable()
                    .scaledToFill()
                    .frame(
                        width: vpWidth * scale,
                        height: vpHeight * scale
                    )
                    .offset(offset)
                    .clipped()
                    .contentShape(Rectangle())
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = max(1.0, lastScale * value)
                                }
                                .onEnded { _ in
                                    lastScale = scale
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
                    .allowsHitTesting(false)
                VStack(spacing: 0) {
                    HStack {
                        Button("取消") { onCancel() }
                            .foregroundStyle(.white)
                            .frame(minWidth: 44, minHeight: 44)

                        Spacer()

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
                }
            }
        }
    }

    private func clamped(_ proposed: CGSize, vpWidth: CGFloat, vpHeight: CGFloat) -> CGSize {
        let maxX = max(0, (vpWidth * scale - vpWidth) / 2)
        let maxY = max(0, (vpHeight * scale - vpHeight) / 2)
        return CGSize(
            width: proposed.width.clamped(to: -maxX...maxX),
            height: proposed.height.clamped(to: -maxY...maxY)
        )
    }

    /// 与 `Image` + `scaledToFill` 一致：先按比例铺满画布，再按视口与偏移裁切，避免 `draw(in:)` 拉伸整张图导致变形。
    private func crop(geo: GeometryProxy, vpY: CGFloat, vpWidth: CGFloat, vpHeight: CGFloat) {
        let normalized = sourceImage.normalizedForCrop()
        let canvasW = vpWidth * scale
        let canvasH = vpHeight * scale

        let w = geo.size.width
        let h = geo.size.height
        let imageLeft = w / 2 + offset.width - canvasW / 2
        let imageTop = h / 2 + offset.height - canvasH / 2

        let vLeft: CGFloat = 0
        let vTop = vpY
        let vRight = vpWidth
        let vBottom = vpY + vpHeight

        let intLeft = max(vLeft, imageLeft)
        let intTop = max(vTop, imageTop)
        let intRight = min(vRight, imageLeft + canvasW)
        let intBottom = min(vBottom, imageTop + canvasH)
        let intW = intRight - intLeft
        let intH = intBottom - intTop

        guard intW > 0.5, intH > 0.5 else { return }

        let localX = intLeft - imageLeft
        let localY = intTop - imageTop

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = true

        let canvasSize = CGSize(width: canvasW, height: canvasH)
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let canvasImage = renderer.image { _ in
            normalized.drawAspectFill(in: CGRect(origin: .zero, size: canvasSize))
        }

        guard let cgFull = canvasImage.cgImage else { return }

        let px = CGFloat(cgFull.width) / canvasW
        var cropPx = CGRect(
            x: localX * px,
            y: localY * px,
            width: intW * px,
            height: intH * px
        ).integral

        cropPx.origin.x = max(0, cropPx.origin.x)
        cropPx.origin.y = max(0, cropPx.origin.y)
        if cropPx.maxX > CGFloat(cgFull.width) { cropPx.size.width -= cropPx.maxX - CGFloat(cgFull.width) }
        if cropPx.maxY > CGFloat(cgFull.height) { cropPx.size.height -= cropPx.maxY - CGFloat(cgFull.height) }

        guard cropPx.width > 0, cropPx.height > 0,
              let cgCropped = cgFull.cropping(to: cropPx) else { return }

        let out = UIImage(cgImage: cgCropped, scale: canvasImage.scale, orientation: .up)
        onConfirm(out)
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
