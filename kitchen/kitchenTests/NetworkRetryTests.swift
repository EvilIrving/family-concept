import Foundation
import Testing
import UIKit
@testable import kitchen

struct NetworkRetryTests {
    @Test("网络超时后自动重试并成功")
    func retriesTransportFailureThenSucceeds() async throws {
        let session = makeMockSession()
        let executor = RequestExecutor(
            session: session,
            sleep: { _ in },
            randomJitter: { _ in 0 }
        )
        let client = APIClient(baseURL: "https://example.com", session: session, requestExecutor: executor)

        MockURLProtocol.configure { request, attempt in
            #expect(request.url?.absoluteString == "https://example.com/dishes")
            if attempt == 1 {
                throw URLError(.timedOut)
            }

            return (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("{\"value\":1}".utf8)
            )
        }

        let response: RetryPayload = try await client.request(Endpoint(path: "/dishes"))

        #expect(response.value == 1)
        #expect(MockURLProtocol.requestCount == 2)
    }

    @Test("重试达到上限后返回最终失败")
    func stopsAfterMaxAttempts() async throws {
        let session = makeMockSession()
        let executor = RequestExecutor(
            session: session,
            sleep: { _ in },
            randomJitter: { _ in 0 }
        )
        let client = APIClient(baseURL: "https://example.com", session: session, requestExecutor: executor)

        MockURLProtocol.configure { request, _ in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 500, httpVersion: nil, headerFields: nil)!,
                Data("服务器忙".utf8)
            )
        }

        do {
            let _: RetryPayload = try await client.request(Endpoint(path: "/dishes"))
            Issue.record("预期应该在最大重试次数后失败")
        } catch let error as APIError {
            #expect(error == .serverMessage("服务器忙"))
        }
        #expect(MockURLProtocol.requestCount == 3)
    }

    @Test("401 不重试并映射为 unauthorized")
    func doesNotRetryUnauthorized() async throws {
        let session = makeMockSession()
        let executor = RequestExecutor(
            session: session,
            sleep: { _ in },
            randomJitter: { _ in 0 }
        )
        let client = APIClient(baseURL: "https://example.com", session: session, requestExecutor: executor)

        MockURLProtocol.configure { request, _ in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 401, httpVersion: nil, headerFields: nil)!,
                Data("unauthorized".utf8)
            )
        }

        do {
            let _: RetryPayload = try await client.request(Endpoint(path: "/auth"))
            Issue.record("401 应立即失败")
        } catch let error as APIError {
            #expect(error == .unauthorized)
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test("404 和解码失败都不重试")
    func doesNotRetryMissingResourceOrDecodingFailure() async throws {
        let session = makeMockSession()
        let executor = RequestExecutor(
            session: session,
            sleep: { _ in },
            randomJitter: { _ in 0 }
        )
        let client = APIClient(baseURL: "https://example.com", session: session, requestExecutor: executor)

        MockURLProtocol.configure { request, _ in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 404, httpVersion: nil, headerFields: nil)!,
                Data("missing".utf8)
            )
        }

        do {
            let _: RetryPayload = try await client.request(Endpoint(path: "/missing"))
            Issue.record("404 不应被重试")
        } catch let error as APIError {
            #expect(error == .serverMessage("missing"))
        }
        #expect(MockURLProtocol.requestCount == 1)

        MockURLProtocol.configure { request, _ in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data("{\"unexpected\":1}".utf8)
            )
        }

        do {
            let _: RetryPayload = try await client.request(Endpoint(path: "/decode"))
            Issue.record("解码失败不应被吞掉")
        } catch let error as APIError {
            if case .decoding = error {
                #expect(true)
            } else {
                Issue.record("预期为 decoding，实际为 \(error)")
            }
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test("取消会中断退避等待且不进入下一次请求")
    func cancellationStopsBeforeNextAttempt() async throws {
        let session = makeMockSession()
        let sleepProbe = SleepProbe()
        let executor = RequestExecutor(
            session: session,
            sleep: { delay in
                try await sleepProbe.wait(delay: delay)
            },
            randomJitter: { _ in 0 }
        )
        let client = APIClient(baseURL: "https://example.com", session: session, requestExecutor: executor)

        MockURLProtocol.configure { request, _ in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 500, httpVersion: nil, headerFields: nil)!,
                Data("retry later".utf8)
            )
        }

        let task = Task {
            let _: RetryPayload = try await client.request(Endpoint(path: "/cancel"))
        }

        await sleepProbe.waitUntilSleeping()
        task.cancel()
        await sleepProbe.resume()

        do {
            _ = try await task.value
            Issue.record("取消后不应继续完成请求")
        } catch is CancellationError {
            #expect(true)
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test("图片 404 视为缺失资源且不重试")
    func remoteImageMaps404ToMissingResource() async throws {
        let session = makeMockSession()
        let executor = RequestExecutor(
            session: session,
            sleep: { _ in },
            randomJitter: { _ in 0 }
        )
        let pipeline = RemoteDishImagePipeline(requestExecutor: executor)

        MockURLProtocol.configure { request, _ in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 404, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        do {
            _ = try await pipeline.fetchImage(from: URL(string: "https://example.com/image.png")!)
            Issue.record("404 应映射为 missingResource")
        } catch let error as RemoteDishImagePipeline.PipelineError {
            #expect(error == .missingResource)
        }
        #expect(MockURLProtocol.requestCount == 1)
    }

    @Test("图片 500 会重试后再失败")
    func remoteImageRetriesServerFailures() async throws {
        let session = makeMockSession()
        let executor = RequestExecutor(
            session: session,
            sleep: { _ in },
            randomJitter: { _ in 0 }
        )
        let pipeline = RemoteDishImagePipeline(requestExecutor: executor)

        MockURLProtocol.configure { request, _ in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 500, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        do {
            _ = try await pipeline.fetchImage(from: URL(string: "https://example.com/image.png")!)
            Issue.record("500 应在重试耗尽后失败")
        } catch let error as RemoteDishImagePipeline.PipelineError {
            #expect(error == .badResponse)
        }
        #expect(MockURLProtocol.requestCount == 3)
    }
}

private struct RetryPayload: Decodable {
    let value: Int
}

private actor SleepProbe {
    private var continuation: CheckedContinuation<Void, Never>?
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var sleptDelays: [TimeInterval] = []

    func wait(delay: TimeInterval) async throws {
        sleptDelays.append(delay)
        notifyWaiters()
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        try Task.checkCancellation()
    }

    func waitUntilSleeping() async {
        if continuation != nil {
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }

    private func notifyWaiters() {
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }
}

private final class MockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    private static var handler: ((URLRequest, Int) throws -> (HTTPURLResponse, Data))?
    private static var count = 0

    static var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    static func configure(_ handler: @escaping (URLRequest, Int) throws -> (HTTPURLResponse, Data)) {
        lock.lock()
        self.handler = handler
        count = 0
        lock.unlock()
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.lock.lock()
        Self.count += 1
        let attempt = Self.count
        let handler = Self.handler
        Self.lock.unlock()

        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request, attempt)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeMockSession() -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: configuration)
}
