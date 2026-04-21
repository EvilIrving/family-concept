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
        let lifetime: Double
        let curvatureX: CGFloat
        let curvatureY: CGFloat
        let sizeClass: SizeClass
        let hasGlow: Bool
    }

    private enum SizeClass {
        case small   // 1.1-1.8pt
        case medium  // 2.0-3.0pt
        case large   // 3.5-5.0pt

        var radiusRange: ClosedRange<CGFloat> {
            switch self {
            case .small: return 1.1...1.8
            case .medium: return 2.0...3.0
            case .large: return 3.5...5.0
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let stage = stageSize(in: geo.size)
            ZStack {
                // T7: Radial gradient backdrop (warm dark center, cooler edges)
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        AppComponentColor.Cropper.backdropGradientCenter.opacity(0.3),
                        AppComponentColor.Cropper.backdropGradientEdge
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: max(geo.size.width, geo.size.height) * 0.7
                )
                .ignoresSafeArea()

                Color(AppComponentColor.Cropper.backdrop)
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

        async let sampled: [Particle] = Self.sampleParticles(from: sourceImage)
        async let visionResult: UIImage = produceFinal()
        particles = await sampled
        startTime = .now

        let minParticleDuration: UInt64 = 700_000_000
        async let wait: () = Task.sleep(nanoseconds: minParticleDuration)
        let (_, extracted) = try await (wait, visionResult)
        finalImage = extracted

        phase = .revealing
        // T9: reduced from 0.45s to 0.4s to stay within 0.2-0.4s range
        withAnimation(.easeIn(duration: 0.4)) {
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
        let sx = size.width / CGFloat(Self.sampleGridSize.width)
        let sy = size.height / CGFloat(Self.sampleGridSize.height)
        let cx = size.width / 2
        let cy = size.height / 2

        for p in particles {
            // T6: Staggered fade-in — brief opacity ramp per particle
            let fadeInDelay = Double(p.seed) * 0.25
            let age = elapsed - fadeInDelay
            guard age > 0 else { continue }

            // T6: Per-particle lifetime (0.8-1.8s)
            guard age <= p.lifetime else { continue }

            let n = age / p.lifetime
            let spread = n * n

            // T6: Staggered fade-in — opacity ramps from 0 to 1 in first 10% of life
            let fadeInProgress = min(n / 0.1, 1.0)
            // T6: Staggered fade-out — opacity fades in last 20% of life
            let fadeOutProgress = n > 0.8 ? (1.0 - n) / 0.2 : 1.0
            let opacity = fadeInProgress * fadeOutProgress * 0.9

            let baseX = p.origin.x * sx
            let baseY = p.origin.y * sy

            // T6: Curved trajectories — sine-based arc offset in addition to radial drift
            let curveOffsetX = sin(n * .pi * 1.5) * p.curvatureX
            let curveOffsetY = cos(n * .pi * 1.2) * p.curvatureY
            let radialX = (baseX - cx) / max(1, cx) * 52
            let radialY = (baseY - cy) / max(1, cy) * 52
            let px = baseX + (radialX + p.driftX) * CGFloat(spread) + curveOffsetX
            let py = baseY + (radialY + p.driftY - 44) * CGFloat(spread) + curveOffsetY

            // T5: Size variation from size class
            let r: CGFloat = p.sizeClass.radiusRange.lowerBound
                + (p.sizeClass.radiusRange.upperBound - p.sizeClass.radiusRange.lowerBound)
                * (1 - CGFloat(n))

            let rect = CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)

            // T5: Glow halo on ~15% of particles
            if p.hasGlow {
                let glowRect = CGRect(x: px - r * 2.5, y: py - r * 2.5, width: r * 5, height: r * 5)
                gctx.fill(Path(ellipseIn: glowRect), with: .color(p.color.opacity(opacity * 0.2)))
            }

            gctx.fill(Path(ellipseIn: rect), with: .color(p.color.opacity(opacity)))
        }
    }

    // MARK: - Data prep

    // T5: Increased grid from 72x72 to 96x96
    nonisolated private static let sampleGridSize = (width: 96, height: 96)
    // T5: Hard cap at 4000 particles for performance on older devices
    private static let maxParticles = 4000

    nonisolated private static func sampleParticles(from image: UIImage) async -> [Particle] {
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
            out.reserveCapacity(min(gw * gh, maxParticles))
            for y in 0..<gh {
                for x in 0..<gw {
                    let i = (y * gw + x) * 4
                    let r = Double(pixels[i]) / 255.0
                    let g = Double(pixels[i + 1]) / 255.0
                    let b = Double(pixels[i + 2]) / 255.0

                    // Skip near-black background pixels
                    let luminance = 0.299 * r + 0.587 * g + 0.114 * b
                    guard luminance > 0.08 else { continue }

                    let id = y * gw + x
                    let jitterX = CGFloat.random(in: -6...6)
                    let jitterY = CGFloat.random(in: -10...2)
                    let seedSeq = CGFloat(x + y) / CGFloat(gw + gh)
                    let seed = seedSeq + CGFloat.random(in: 0...0.35)

                    // T5: Random size class (small/medium/large)
                    let sizeRoll = CGFloat.random(in: 0...1)
                    let sizeClass: SizeClass = sizeRoll < 0.5 ? .small
                        : sizeRoll < 0.8 ? .medium
                        : .large

                    // T5: ~15% glow
                    let hasGlow = CGFloat.random(in: 0...1) < 0.15

                    // T6: Random lifetime in 0.8-1.8s range
                    let lifetime = Double.random(in: 0.8...1.8)

                    // T6: Curvature for arc trajectories
                    let curvatureX = CGFloat.random(in: -30...30)
                    let curvatureY = CGFloat.random(in: -30...30)

                    out.append(Particle(
                        id: id,
                        origin: CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5),
                        color: Color(red: r, green: g, blue: b),
                        seed: seed,
                        driftX: jitterX,
                        driftY: jitterY,
                        lifetime: lifetime,
                        curvatureX: curvatureX,
                        curvatureY: curvatureY,
                        sizeClass: sizeClass,
                        hasGlow: hasGlow
                    ))
                }
            }

            // T5: Cap at maxParticles for performance
            if out.count > maxParticles {
                out.shuffle()
                out = Array(out.prefix(maxParticles))
            }

            return out
        }.value
    }
}
