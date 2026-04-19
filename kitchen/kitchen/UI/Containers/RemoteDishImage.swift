import Combine
import SwiftUI
import UIKit

struct RemoteDishImage<Content: View>: View {
    let url: URL
    var retryTitle: String = "重试"
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
                AppErrorPlaceholder(feedback: feedback, retryTitle: retryTitle) {
                    Task {
                        await loader.load(from: url)
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
        private var lastURL: URL?

        func load(from url: URL) async {
            if lastURL == url, case .success = phase {
                return
            }

            let retainedValue = phase.retainedValue
            lastURL = url

            if let cached = await RemoteDishImagePipeline.shared.cachedImage(for: url) {
                phase = .success(Image(uiImage: cached))
                return
            }

            if let retainedValue {
                phase = .loading(LoadingContext(mode: .refresh, label: "加载中", retainedValue: retainedValue))
            } else {
                phase = .loading(LoadingContext(mode: .initial, label: "加载中"))
            }

            do {
                let uiImage = try await RemoteDishImagePipeline.shared.fetchImage(from: url)
                phase = .success(Image(uiImage: uiImage))
            } catch RemoteDishImagePipeline.PipelineError.missingResource {
                phase = .failure(.empty(kind: .missingResource), retainedValue: retainedValue)
            } catch {
                if (error as? URLError)?.code == .cancelled {
                    return
                }
                #if DEBUG
                print("RemoteDishImage request error: \(url.absoluteString) error=\(error.localizedDescription)")
                #endif
                phase = .failure(.network(message: "图片加载失败"), retainedValue: retainedValue)
            }
        }
    }
}

actor RemoteDishImagePipeline {
    static let shared = RemoteDishImagePipeline()

    enum PipelineError: Error {
        case missingResource
        case badResponse
    }

    private let cache = NSCache<NSURL, UIImage>()
    private let maxConcurrentLoads = 6
    private var activeLoads = 0
    private var waitingContinuations: [CheckedContinuation<Void, Never>] = []

    private init() {
        cache.countLimit = 240
        cache.totalCostLimit = 120 * 1024 * 1024
    }

    func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func fetchImage(from url: URL) async throws -> UIImage {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        await acquireSlot()
        defer { releaseSlot() }

        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 30)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw PipelineError.badResponse
        }

        if http.statusCode == 404 || http.statusCode == 410 {
            #if DEBUG
            print("RemoteDishImage missing resource: \(url.absoluteString) status=\(http.statusCode)")
            #endif
            throw PipelineError.missingResource
        }

        guard (200...299).contains(http.statusCode) else {
            #if DEBUG
            print("RemoteDishImage load failed: \(url.absoluteString) status=\(http.statusCode)")
            #endif
            throw PipelineError.badResponse
        }

        guard let uiImage = UIImage(data: data) else {
            #if DEBUG
            print("RemoteDishImage decode failed: \(url.absoluteString) bytes=\(data.count)")
            #endif
            throw URLError(.cannotDecodeContentData)
        }

        cache.setObject(uiImage, forKey: url as NSURL, cost: data.count)
        return uiImage
    }

    private func acquireSlot() async {
        if activeLoads < maxConcurrentLoads {
            activeLoads += 1
            return
        }

        await withCheckedContinuation { continuation in
            waitingContinuations.append(continuation)
        }
    }

    private func releaseSlot() {
        if waitingContinuations.isEmpty {
            activeLoads = max(0, activeLoads - 1)
            return
        }

        let continuation = waitingContinuations.removeFirst()
        continuation.resume()
    }
}
