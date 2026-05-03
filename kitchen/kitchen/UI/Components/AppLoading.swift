import SwiftUI

struct LoadingStyle {
    var indicatorSpacing: CGFloat = AppSpacing.xs
    var blockSpacing: CGFloat = AppSpacing.sm
    var placeholderCornerRadius: CGFloat = AppRadius.md
    var shimmerBaseOpacity: Double = 0.12
    var shimmerHighlightOpacity: Double = 0.22
    var defaultTransition: AnyTransition = .opacity
}

private struct LoadingStyleKey: EnvironmentKey {
    static let defaultValue = LoadingStyle()
}

struct EmptyFeedbackStyle {
    var icon: (AppEmptyKind) -> String = { kind in
        switch kind {
        case .noData:
            return "tray"
        case .noSearchResult:
            return "magnifyingglass"
        case .noPermission:
            return "lock.slash"
        case .missingResource:
            return "photo"
        }
    }

    var title: (AppEmptyKind) -> String = { kind in
        switch kind {
        case .noData:
            return L10n.tr("暂无内容")
        case .noSearchResult:
            return L10n.tr("没有找到结果")
        case .noPermission:
            return L10n.tr("暂无访问权限")
        case .missingResource:
            return L10n.tr("内容不存在")
        }
    }

    var message: (AppEmptyKind) -> String? = { kind in
        switch kind {
        case .noData:
            return nil
        case .noSearchResult:
            return L10n.tr("换个关键词试试")
        case .noPermission:
            return L10n.tr("请确认当前账号权限")
        case .missingResource:
            return L10n.tr("资源暂时不可用")
        }
    }
}

private struct EmptyFeedbackStyleKey: EnvironmentKey {
    static let defaultValue = EmptyFeedbackStyle()
}

extension EnvironmentValues {
    var loadingStyle: LoadingStyle {
        get { self[LoadingStyleKey.self] }
        set { self[LoadingStyleKey.self] = newValue }
    }

    var emptyFeedbackStyle: EmptyFeedbackStyle {
        get { self[EmptyFeedbackStyleKey.self] }
        set { self[EmptyFeedbackStyleKey.self] = newValue }
    }
}

extension View {
    func loadingStyle(_ style: LoadingStyle) -> some View {
        environment(\.loadingStyle, style)
    }

    func emptyFeedbackStyle(_ style: EmptyFeedbackStyle) -> some View {
        environment(\.emptyFeedbackStyle, style)
    }
}

struct AppLoadingIndicator: View {
    enum Tone {
        case primary
        case secondary
        case inverse

        var tintColor: Color {
            switch self {
            case .primary:
                return AppSemanticColor.primary
            case .secondary:
                return AppSemanticColor.textSecondary
            case .inverse:
                return AppSemanticColor.surface
            }
        }

        var labelColor: Color {
            switch self {
            case .inverse:
                return AppSemanticColor.surface
            case .primary, .secondary:
                return AppSemanticColor.textSecondary
            }
        }
    }

    @Environment(\.loadingStyle) private var style

    var label: String? = nil
    var tone: Tone = .primary
    var controlSize: ControlSize = .regular

    var body: some View {
        HStack(spacing: style.indicatorSpacing) {
            ProgressView()
                .tint(tone.tintColor)
                .controlSize(controlSize)

            if let label {
                Text(label)
                    .font(AppTypography.micro)
                    .foregroundStyle(tone.labelColor)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct AppProgressIndicator: View {
    var progress: Double
    var label: String? = nil
    var tone: AppLoadingIndicator.Tone = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            if let label {
                Text(label)
                    .font(AppTypography.micro)
                    .foregroundStyle(AppSemanticColor.textSecondary)
            }
            ProgressView(value: progress)
                .tint(tone.tintColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("\(Int(progress * 100))%"))
    }
}

struct SkeletonPrimitive: View {
    @Environment(\.loadingStyle) private var style
    @State private var shimmerOffset: CGFloat = -1.2

    var cornerRadius: CGFloat? = nil

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius ?? style.placeholderCornerRadius, style: .continuous)
            .fill(AppSemanticColor.textSecondary.opacity(style.shimmerBaseOpacity))
            .overlay {
                GeometryReader { proxy in
                    LinearGradient(
                        colors: [
                            .clear,
                            AppSemanticColor.surface.opacity(style.shimmerHighlightOpacity),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .rotationEffect(.degrees(18))
                    .offset(x: shimmerOffset * max(proxy.size.width, 1))
                }
                .clipped()
            }
            .onAppear {
                shimmerOffset = -1.2
                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                    shimmerOffset = 1.2
                }
            }
    }
}

struct AppSkeletonBlock: View {
    var height: CGFloat

    var body: some View {
        SkeletonPrimitive()
            .frame(maxWidth: .infinity)
            .frame(height: height)
    }
}

struct AppSkeletonImage: View {
    var aspectRatio: CGFloat? = nil
    var minHeight: CGFloat? = nil

    var body: some View {
        Group {
            if let aspectRatio {
                SkeletonPrimitive()
                    .aspectRatio(aspectRatio, contentMode: .fit)
            } else {
                SkeletonPrimitive()
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight)
    }
}

struct AppErrorPlaceholder: View {
    @Environment(\.emptyFeedbackStyle) private var emptyStyle

    let feedback: AppFeedback
    var retryTitle: String? = nil
    var onRetry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: resolvedSystemImage)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(AppSemanticColor.textSecondary)

            Text(resolvedTitle)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(AppSemanticColor.textPrimary)

            if let message = resolvedMessage {
                Text(message)
                    .font(AppTypography.micro)
                    .foregroundStyle(AppSemanticColor.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let retryTitle, let onRetry {
                Button(retryTitle, action: onRetry)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppSemanticColor.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.md)
    }

    private var resolvedTitle: String {
        if let title = feedback.title {
            return title
        }
        if let emptyKind = feedback.emptyKind {
            return emptyStyle.title(emptyKind)
        }
        return L10n.tr("加载失败")
    }

    private var resolvedMessage: String? {
        if let message = feedback.message {
            return message
        }
        if let emptyKind = feedback.emptyKind {
            return emptyStyle.message(emptyKind)
        }
        return L10n.tr("请稍后重试")
    }

    private var resolvedSystemImage: String {
        if let systemImage = feedback.systemImage {
            return systemImage
        }
        if let emptyKind = feedback.emptyKind {
            return emptyStyle.icon(emptyKind)
        }
        return "exclamationmark.triangle"
    }
}
