import SwiftUI
import UIKit
import Combine

struct RemoteDishImage<Content: View, Placeholder: View, Failure: View>: View {
    let url: URL
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    @ViewBuilder let failure: () -> Failure

    @StateObject private var loader = Loader()

    var body: some View {
        Group {
            switch loader.phase {
            case .idle, .loading:
                placeholder()
            case .success(let image):
                content(image)
            case .failure:
                failure()
            }
        }
        .task(id: url) {
            await loader.load(from: url)
        }
    }
}

extension RemoteDishImage {
    @MainActor
    final class Loader: ObservableObject {
        enum Phase {
            case idle
            case loading
            case success(Image)
            case failure
        }

        @Published var phase: Phase = .idle
        private var lastURL: URL?

        func load(from url: URL) async {
            if lastURL == url, case .success = phase {
                return
            }

            lastURL = url

            if let cached = await RemoteDishImagePipeline.shared.cachedImage(for: url) {
                phase = .success(Image(uiImage: cached))
                return
            }

            phase = .loading

            do {
                let uiImage = try await RemoteDishImagePipeline.shared.fetchImage(from: url)
                phase = .success(Image(uiImage: uiImage))
            } catch {
                if (error as? URLError)?.code == .cancelled {
                    phase = .loading
                    return
                }
                #if DEBUG
                print("RemoteDishImage request error: \(url.absoluteString) error=\(error.localizedDescription)")
                #endif
                phase = .failure
            }
        }
    }
}

actor RemoteDishImagePipeline {
    static let shared = RemoteDishImagePipeline()

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

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            #if DEBUG
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("RemoteDishImage load failed: \(url.absoluteString) status=\(statusCode)")
            #endif
            throw URLError(.badServerResponse)
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
