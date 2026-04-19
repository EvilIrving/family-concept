import SwiftUI

struct LoadingBlockStrategy {
    var showsSkeletonOnInitialLoad: Bool = true
    var overlaysRetainedContentOnRefresh: Bool = true
    var overlaysRetainedContentOnFailure: Bool = true
}

struct AppLoadingBlock<Value, Content: View, Empty: View>: View {
    @Environment(\.loadingStyle) private var style

    let phase: LoadingPhase<Value>
    var strategy = LoadingBlockStrategy()
    var retryTitle: String = "重试"
    let emptyView: ((AppFeedback) -> Empty)?
    let content: (Value) -> Content
    let onRetry: (() -> Void)?

    init(
        phase: LoadingPhase<Value>,
        strategy: LoadingBlockStrategy = LoadingBlockStrategy(),
        retryTitle: String = "重试",
        emptyView: ((AppFeedback) -> Empty)? = nil,
        @ViewBuilder content: @escaping (Value) -> Content,
        onRetry: (() -> Void)? = nil
    ) {
        self.phase = phase
        self.strategy = strategy
        self.retryTitle = retryTitle
        self.emptyView = emptyView
        self.content = content
        self.onRetry = onRetry
    }

    var body: some View {
        Group {
            switch phase {
            case .idle:
                Color.clear
            case .loading(let context):
                loadingBody(context: context)
            case .success(let value):
                resolvedSuccess(for: value)
                    .transition(style.defaultTransition)
            case .failure(let feedback, let retainedValue):
                failureBody(feedback: feedback, retainedValue: retainedValue)
            }
        }
    }

    @ViewBuilder
    private func loadingBody(context: LoadingContext<Value>) -> some View {
        if let retainedValue = context.retainedValue, strategy.overlaysRetainedContentOnRefresh {
            content(retainedValue)
                .overlay {
                    overlayLoading(for: context)
                }
        } else if context.mode == .progress, let progress = context.progress {
            VStack(spacing: style.blockSpacing) {
                AppProgressIndicator(progress: progress, label: context.label)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(AppSpacing.md)
        } else if strategy.showsSkeletonOnInitialLoad {
            VStack(spacing: style.blockSpacing) {
                AppSkeletonBlock(height: AppDimension.progressBlockMinHeight)
                AppSkeletonBlock(height: AppDimension.progressBlockMinHeight)
                AppSkeletonBlock(height: AppDimension.progressBlockMinHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(AppSpacing.md)
        } else {
            overlayLoading(for: context)
        }
    }

    @ViewBuilder
    private func failureBody(feedback: AppFeedback, retainedValue: Value?) -> some View {
        if let retainedValue, strategy.overlaysRetainedContentOnFailure {
            content(retainedValue)
                .overlay {
                    failureOverlay(feedback: feedback)
                }
        } else {
            placeholder(for: feedback)
        }
    }

    @ViewBuilder
    private func resolvedSuccess(for value: Value) -> some View {
        content(value)
    }

    private func overlayLoading(for context: LoadingContext<Value>) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(AppSemanticColor.surface.opacity(0.82))
            if context.mode == .progress, let progress = context.progress {
                AppProgressIndicator(progress: progress, label: context.label)
            } else {
                AppLoadingIndicator(label: context.label, tone: .secondary)
            }
        }
        .padding(AppSpacing.md)
    }

    private func failureOverlay(feedback: AppFeedback) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
                .fill(AppSemanticColor.surface.opacity(0.88))
            placeholder(for: feedback)
        }
        .padding(AppSpacing.md)
    }

    @ViewBuilder
    private func placeholder(for feedback: AppFeedback) -> some View {
        if feedback.emptyKind != nil, let emptyView {
            emptyView(feedback)
        } else {
            AppErrorPlaceholder(feedback: feedback, retryTitle: retryTitle, onRetry: onRetry)
        }
    }
}

extension AppLoadingBlock where Empty == EmptyView {
    init(
        phase: LoadingPhase<Value>,
        strategy: LoadingBlockStrategy = LoadingBlockStrategy(),
        retryTitle: String = "重试",
        @ViewBuilder content: @escaping (Value) -> Content,
        onRetry: (() -> Void)? = nil
    ) {
        self.init(
            phase: phase,
            strategy: strategy,
            retryTitle: retryTitle,
            emptyView: nil,
            content: content,
            onRetry: onRetry
        )
    }
}
