import SwiftUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

struct DishConfirmDissolveView: View {
    let image: UIImage
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var foreground: UIImage?
    @State private var particles: [Particle] = []
    @State private var phase: Phase = .identifying
    @State private var startTime: Date = .now
    @State private var glowOpacity: CGFloat = 0
    @State private var glowScale: CGFloat = 1
    @State private var bgOpacity: CGFloat = 1
    @State private var fgScale: CGFloat = 1
    @State private var scanOpacity: CGFloat = 0.6

    private enum Phase { case identifying, glowing, dissolving, done }

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
                AppComponentColor.Cropper.backdrop.ignoresSafeArea()

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: stage.width, height: stage.height)
                        .opacity(bgOpacity)
                        .clipped()

                    if phase == .dissolving {
                        TimelineView(.animation) { ctx in
                            Canvas { gctx, size in
                                let t = ctx.date.timeIntervalSince(startTime)
                                drawDust(gctx, size: size, elapsed: t)
                            }
                            .frame(width: stage.width, height: stage.height)
                            .allowsHitTesting(false)
                        }
                    }

                    if phase == .identifying {
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.18), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(width: stage.width, height: stage.height * 0.35)
                        .offset(y: stage.height * (scanOpacity - 0.5))
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                    }

                    if let fg = foreground, phase != .identifying {
                        Image(uiImage: fg)
                            .resizable()
                            .scaledToFill()
                            .frame(width: stage.width, height: stage.height)
                            .scaleEffect(fgScale)
                            .clipped()
                    }

                    if let fg = foreground, phase == .glowing || phase == .dissolving {
                        Image(uiImage: fg)
                            .resizable()
                            .scaledToFill()
                            .frame(width: stage.width, height: stage.height)
                            .colorMultiply(.white)
                            .blur(radius: 18)
                            .opacity(glowOpacity)
                            .scaleEffect(glowScale)
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: stage.width, height: stage.height)
                .clipShape(RoundedRectangle(cornerRadius: DishImageSpec.viewportCornerRadius))
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .task {
            if reduceMotion {
                onFinish()
                return
            }
            await runSequence()
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

    private func runSequence() async {
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            scanOpacity = 0.95
        }

        async let fg = Self.extractForeground(from: image)
        async let dust = Self.sampleParticles(from: image)
        let (extracted, sampled) = await (fg, dust)
        foreground = extracted
        particles = sampled

        phase = .glowing
        glowOpacity = 0
        glowScale = 0.96
        withAnimation(.easeOut(duration: 0.3)) {
            glowOpacity = 1.0
            glowScale = 1.04
        }
        try? await Task.sleep(nanoseconds: 300_000_000)
        withAnimation(.easeInOut(duration: 0.2)) {
            glowScale = 1.0
        }
        try? await Task.sleep(nanoseconds: 180_000_000)

        startTime = .now
        phase = .dissolving
        withAnimation(.easeIn(duration: 0.7)) { bgOpacity = 0 }
        withAnimation(.easeOut(duration: 0.9).delay(0.4)) { glowOpacity = 0 }
        withAnimation(.easeOut(duration: 0.6).delay(0.7)) { fgScale = 1.02 }
        try? await Task.sleep(nanoseconds: 1_350_000_000)

        phase = .done
        withAnimation(.easeInOut(duration: 0.15)) { fgScale = 1.0 }
        try? await Task.sleep(nanoseconds: 150_000_000)
        onFinish()
    }

    // MARK: - Canvas

    private func drawDust(_ gctx: GraphicsContext, size: CGSize, elapsed: TimeInterval) {
        let life: Double = 1.25
        let sx = size.width / CGFloat(Self.sampleGridSize.width)
        let sy = size.height / CGFloat(Self.sampleGridSize.height)
        let cx = size.width / 2
        let cy = size.height / 2

        for p in particles {
            let delay = Double(p.seed) * 0.18
            let age = elapsed - delay
            guard age > 0 else { continue }
            if age > life { continue }
            let n = age / life
            // 扩散：先慢后快（accelerating）
            let spread = n * n
            // 消失：先快后慢（decelerating）
            let opacity = pow(1 - n, 2) * 0.9
            let baseX = p.origin.x * sx
            let baseY = p.origin.y * sy
            let radialX = (baseX - cx) / max(1, cx) * 48
            let radialY = (baseY - cy) / max(1, cy) * 48
            let px = baseX + (radialX + p.driftX) * CGFloat(spread)
            let py = baseY + (radialY + p.driftY - 44) * CGFloat(spread)
            let r: CGFloat = 1.1 + (1 - CGFloat(n)) * 0.7
            let rect = CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)
            gctx.fill(Path(ellipseIn: rect), with: .color(p.color.opacity(opacity)))
        }
    }

    // MARK: - Data prep

    private static let sampleGridSize = (width: 72, height: 48)

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

    private static func extractForeground(from image: UIImage) async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let cg = image.cgImage else { return nil }
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            let request = VNGenerateForegroundInstanceMaskRequest()
            do {
                try handler.perform([request])
                guard let obs = request.results?.first else { return nil }
                let buffer = try obs.generateMaskedImage(
                    ofInstances: obs.allInstances,
                    from: handler,
                    croppedToInstancesExtent: false
                )
                let ci = CIImage(cvPixelBuffer: buffer)
                let ctx = CIContext()
                guard let cgOut = ctx.createCGImage(ci, from: ci.extent) else { return nil }
                return UIImage(cgImage: cgOut)
            } catch {
                return nil
            }
        }.value
    }
}
