import SwiftUI

/// 启动页动画状态初始值
private enum LaunchAnimationConstants {
    // 背景呼吸动画
    static let initialScale: CGFloat = 0.8
    static let initialOpacity: Double = 0.6
    static let targetScale: CGFloat = 1.1
    static let targetOpacity: Double = 1.0

    // 3D 旋转动画
    static let rotationStart: Double = 0
    static let rotationEnd: Double = 360
    static let rotateDuration: Double = 1.2

    // 3D 透视
    static let perspective: CGFloat = 0.5

    // 加载点动画基数
    static let dotBaseScale: CGFloat = 0.6
    static let dotBaseOpacity: Double = 0.4
    static let dotScaleOffset: CGFloat = 0.2
    static let dotOpacityOffset: Double = 0.15
    static let dotBottomPadding: CGFloat = 56

    // 辅助计算常量
    static let scaleBlend: CGFloat = 0.5
    static let opacityBlend: CGFloat = 0.3
}

struct LaunchScreenView: View {
    @State private var scale: CGFloat = LaunchAnimationConstants.initialScale
    @State private var opacity: Double = LaunchAnimationConstants.initialOpacity
    @State private var rotate3D: Double = LaunchAnimationConstants.rotationStart

    var body: some View {
        VStack(spacing: AppGap.block) {
            Spacer()

            logoSection

            taglineSection

            Spacer()

            loadingIndicator
                .padding(.bottom, LaunchAnimationConstants.dotBottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appPageBackground()
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        ZStack {
            // 深色背景圆形
            Circle()
                .fill(AppSemanticColor.primary)
                .frame(width: AppDimension.launchLogoSize, height: AppDimension.launchLogoSize)
                .scaleEffect(scale)
                .opacity(opacity)

            // 白色叉子图标，3D 旋转 + 跟随外圈呼吸缩放
            Image(systemName: "fork.knife")
                .font(.system(size: AppDimension.launchIconSize))
                .foregroundStyle(AppSemanticColor.onPrimary)
                .scaleEffect(scale)
                .rotation3DEffect(
                    .degrees(rotate3D),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: LaunchAnimationConstants.perspective
                )
        }
    }

    // MARK: - Tagline Section

    private var taglineSection: some View {
        Text("Home flavors are worth the wait")
            .font(AppTypography.bodyStrong)
            .foregroundStyle(AppSemanticColor.textPrimary)
    }

    // MARK: - Loading Indicator

    private var loadingIndicator: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(AppSemanticColor.primary)
                    .frame(width: AppDimension.launchDotSize, height: AppDimension.launchDotSize)
                    .scaleEffect(scaleEffect(for: index))
                    .opacity(opacityValue(for: index))
            }
        }
    }

    // MARK: - Helpers

    private func scaleEffect(for index: Int) -> CGFloat {
        let offset = CGFloat(index) * LaunchAnimationConstants.dotScaleOffset
        return LaunchAnimationConstants.dotBaseScale + (scale - LaunchAnimationConstants.initialScale) * (1 + offset * LaunchAnimationConstants.scaleBlend)
    }

    private func opacityValue(for index: Int) -> Double {
        let offset = Double(index) * LaunchAnimationConstants.dotOpacityOffset
        return LaunchAnimationConstants.dotBaseOpacity + (opacity - LaunchAnimationConstants.initialOpacity) * (1 + offset * LaunchAnimationConstants.opacityBlend)
    }

    private func startAnimations() {
        // 背景呼吸动画
        withAnimation(AppMotion.launchPulse) {
            scale = LaunchAnimationConstants.targetScale
            opacity = LaunchAnimationConstants.targetOpacity
        }

        // 3D 旋转动画（颠勺翻转）- 使用线性动画保持流畅
        withAnimation(
            Animation.linear(duration: LaunchAnimationConstants.rotateDuration)
                .repeatForever(autoreverses: false)
        ) {
            rotate3D = LaunchAnimationConstants.rotationEnd
        }
    }
}

#Preview {
    LaunchScreenView()
        .environmentObject(AppStore())
}
