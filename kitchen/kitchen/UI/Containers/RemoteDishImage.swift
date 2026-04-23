import Combine
import Nuke
import SwiftUI
import UIKit

struct RemoteDishImage<Content: View>: View {
    let url: URL
    let content: (Image) -> Content

    @StateObject private var loader = Loader()

    var body: some View {
        Group {
            switch loader.phase {
            case .idle:
                AppSkeletonImage(minHeight: AppDimension.dishArtworkHeight)
            case .loading(let context):
                loadingBody(context: context)
            case .success(let image):
                content(image)
                    .transition(.opacity)
            case .failure(let feedback, _):
                AppErrorPlaceholder(feedback: feedback, retryTitle: "重试") {
                    Task {
                        await loader.retry()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: url) {
            await loader.load(from: url)
        }
    }

    @ViewBuilder
    private func loadingBody(context: LoadingContext<Image>) -> some View {
        switch context.mode {
        case .progress:
            if let progress = context.progress {
                AppProgressIndicator(progress: progress, label: context.label)
            } else {
                AppSkeletonImage(minHeight: AppDimension.dishArtworkHeight)
            }
        case .initial, .refresh:
            AppSkeletonImage(minHeight: AppDimension.dishArtworkHeight)
        }
    }
}

extension RemoteDishImage {
    @MainActor
    final class Loader: ObservableObject {
        @Published var phase: LoadingPhase<Image> = .idle
        private let pipeline: ImagePipeline
        private var lastURL: URL?

        init(pipeline: ImagePipeline = .shared) {
            self.pipeline = pipeline
        }

        func load(from url: URL) async {
            if lastURL == url, case .success = phase {
                return
            }

            let retainedValue = phase.retainedValue
            lastURL = url

            if let cached = pipeline.cache[url] {
                phase = .success(Image(uiImage: cached.image))
                return
            }

            if let retainedValue {
                phase = .loading(LoadingContext(mode: .refresh, label: "加载中", retainedValue: retainedValue))
            } else {
                phase = .loading(LoadingContext(mode: .initial, label: "加载中"))
            }

            do {
                let response = try await pipeline.image(for: url)
                phase = .success(Image(uiImage: response))
            } catch {
                if isCancellation(error) { return }
                if isMissingResource(error) {
                    phase = .failure(.empty(kind: .missingResource), retainedValue: retainedValue)
                    return
                }
                #if DEBUG
                print("RemoteDishImage request error: \(url.absoluteString) error=\(error.localizedDescription)")
                #endif
                phase = .failure(.network(message: "图片加载失败"), retainedValue: retainedValue)
            }
        }

        func retry() async {
            guard let lastURL else { return }
            await load(from: lastURL)
        }

        private func isCancellation(_ error: Error) -> Bool {
            if (error as? URLError)?.code == .cancelled { return true }
            if error is CancellationError { return true }
            if case ImagePipeline.Error.pipelineInvalidated = error { return true }
            return false
        }

        private func isMissingResource(_ error: Error) -> Bool {
            guard case let ImagePipeline.Error.dataLoadingFailed(underlying) = error else { return false }
            if let statusError = underlying as? DataLoader.Error,
               case let .statusCodeUnacceptable(code) = statusError {
                return code == 404 || code == 410
            }
            if let urlError = underlying as? URLError {
                return urlError.code == .fileDoesNotExist || urlError.code == .resourceUnavailable
            }
            return false
        }
    }
}
