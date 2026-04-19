import SwiftUI

/// 识别阶段过渡动画：接收取景框子图与异步成品图生成器，在一次连续动画内完成
/// "半透明→不透明 + 粒子扩散 + 揭示成品图 + 缩放到 80% 主体尺寸"。
struct DishConfirmDissolveView: View {
    let sourceImage: UIImage
    let produceFinal: @Sendable () async -> UIImage
    let onFinish: (UIImage) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var finalImage: UIImage?
    @State private var particles: [Particle] = []
    @State private var phase: Phase = .identifying
    @State private var startTime: Date = .now
    @State private var bgOpacity: CGFloat = 1
    @State private var fgOpacity: CGFloat = 0
    @State private var fgScale: CGFloat = 0.92
    @State private var backdropOpacity: CGFloat = 0.5

    private enum Phase { case identifying, revealing, done }

    private struct Particle: Identifiable {
        let id: Int
        let origin: CGPoint
        let color: Color
        let seed: CGFloat
        let driftX: CGFloat
        let driftY: CGFloat
    }

    var body: some View {
        GeometryReader { geo in
            let stage = stageSize(in: geo.size)
            ZStack {
                AppComponentColor.Cropper.backdrop
                    .opacity(backdropOpacity)
                    .ignoresSafeArea()

                ZStack {
                    Image(uiImage: sourceImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: stage.width, height: stage.height)
                        .opacity(bgOpacity)
                        .clipped()

                    if phase == .identifying {
                        TimelineView(.animation) { ctx in
                            Canvas { gctx, size in
                                let t = ctx.date.timeIntervalSince(startTime)
                                drawDust(gctx, size: size, elapsed: t)
                            }
                            .frame(width: stage.width, height: stage.height)
                            .allowsHitTesting(false)
                        }
                    }

                    if let fg = finalImage, phase != .identifying {
                        Image(uiImage: fg)
                            .resizable()
                            .scaledToFit()
                            .frame(width: stage.width, height: stage.height)
                            .opacity(fgOpacity)
                            .scaleEffect(fgScale)
                    }
                }
                .frame(width: stage.width, height: stage.height)
                .clipShape(RoundedRectangle(cornerRadius: DishImageSpec.viewportCornerRadius))
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .task {
            try? await runSequence()
        }
    }

    // MARK: - Layout

    private func stageSize(in container: CGSize) -> CGSize {
        let aspect = DishImageSpec.viewportAspectRatio
        let maxW = max(160, container.width - 32)
        let maxH = max(160, container.height - 160)
        let w = min(maxW, maxH * aspect)
        return CGSize(width: w, height: w / aspect)
    }

    // MARK: - Sequence

    private func runSequence() async throws {
        if reduceMotion {
            let result = await produceFinal()
            onFinish(result)
            return
        }

        withAnimation(.easeInOut(duration: 0.25)) {
            backdropOpacity = 1.0
        }

        async let visionResult: UIImage = produceFinal()
        async let sampled: [Particle] = Self.sampleParticles(from: sourceImage)
        particles = await sampled
        startTime = .now

        let minParticleDuration: UInt64 = 700_000_000
        async let wait: () = Task.sleep(nanoseconds: minParticleDuration)
        let (_, extracted) = try await (wait, visionResult)
        finalImage = extracted

        phase = .revealing
        withAnimation(.easeIn(duration: 0.45)) {
            bgOpacity = 0
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
            fgOpacity = 1
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.1)) {
            fgScale = 1.0
        }
        try? await Task.sleep(nanoseconds: 800_000_000)

        phase = .done
        onFinish(extracted)
    }

    // MARK: - Canvas

    private func drawDust(_ gctx: GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let life: Double = 1.4
        let sx = size.width / CGFloat(Self.sampleGridSize.width)
        let sy = size.height / CGFloat(Self.sampleGridSize.height)
        let cx = size.width / 2
        let cy = size.height / 2

        for p in particles {
            let delay = Double(p.seed) * 0.2
            let age = elapsed - delay
            guard age > 0 else { continue }
            if age > life { continue }
            let n = age / life
            let spread = n * n
            let opacity = pow(1 - n, 2) * 0.9
            let baseX = p.origin.x * sx
            let baseY = p.origin.y * sy
            let radialX = (baseX - cx) / max(1, cx) * 52
            let radialY = (baseY - cy) / max(1, cy) * 52
            let px = baseX + (radialX + p.driftX) * CGFloat(spread)
            let py = baseY + (radialY + p.driftY - 44) * CGFloat(spread)
            let r: CGFloat = 1.1 + (1 - CGFloat(n)) * 0.7
            let rect = CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)
            gctx.fill(Path(ellipseIn: rect), with: .color(p.color.opacity(opacity)))
        }
    }

    // MARK: - Data prep

    nonisolated private static let sampleGridSize = (width: 72, height: 72)

    private static func sampleParticles(from image: UIImage) async -> [Particle] {
        await Task.detached(priority: .userInitiated) {
            let gw = sampleGridSize.width
            let gh = sampleGridSize.height
            guard let cg = image.cgImage else { return [] }

            let cs = CGColorSpaceCreateDeviceRGB()
            var pixels = [UInt8](repeating: 0, count: gw * gh * 4)
            guard let ctx = CGContext(
                data: &pixels,
                width: gw,
                height: gh,
                bitsPerComponent: 8,
                bytesPerRow: gw * 4,
                space: cs,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return [] }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: gw, height: gh))

            var out: [Particle] = []
            out.reserveCapacity(gw * gh)
            for y in 0..<gh {
                for x in 0..<gw {
                    let i = (y * gw + x) * 4
                    let r = Double(pixels[i]) / 255.0
                    let g = Double(pixels[i + 1]) / 255.0
                    let b = Double(pixels[i + 2]) / 255.0
                    let id = y * gw + x
                    let jitterX = CGFloat.random(in: -6...6)
                    let jitterY = CGFloat.random(in: -10...2)
                    let seedSeq = CGFloat(x + y) / CGFloat(gw + gh)
                    let seed = seedSeq + CGFloat.random(in: 0...0.35)
                    out.append(Particle(
                        id: id,
                        origin: CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5),
                        color: Color(red: r, green: g, blue: b),
                        seed: seed,
                        driftX: jitterX,
                        driftY: jitterY
                    ))
                }
            }
            return out
        }.value
    }
}
