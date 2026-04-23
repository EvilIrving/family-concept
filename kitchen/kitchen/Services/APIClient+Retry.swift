import Foundation

struct RetryContext {
    let attempt: Int
    let request: URLRequest
    let response: URLResponse?
    let error: Error?
}

enum RetryDecision {
    case stop
    case retry(after: TimeInterval)
}

struct RetryPolicy {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let jitterRatioRange: ClosedRange<Double>
    let retryableStatusCodes: Set<Int>
    let retryableStatusCodeRanges: [ClosedRange<Int>]
    let retryableURLErrorCodes: Set<URLError.Code>

    nonisolated static let none = RetryPolicy(maxAttempts: 1)
    nonisolated static let standard = RetryPolicy(
        maxAttempts: 3,
        baseDelay: 0.4,
        jitterRatioRange: 0...0.2,
        retryableStatusCodes: [429],
        retryableStatusCodeRanges: [500...599],
        retryableURLErrorCodes: [
            .timedOut,
            .networkConnectionLost,
            .notConnectedToInternet,
            .cannotConnectToHost,
            .cannotFindHost,
            .dnsLookupFailed
        ]
    )

    nonisolated init(
        maxAttempts: Int,
        baseDelay: TimeInterval = 0.4,
        jitterRatioRange: ClosedRange<Double> = 0...0.2,
        retryableStatusCodes: Set<Int> = [],
        retryableStatusCodeRanges: [ClosedRange<Int>] = [],
        retryableURLErrorCodes: Set<URLError.Code> = []
    ) {
        self.maxAttempts = max(1, maxAttempts)
        self.baseDelay = max(0, baseDelay)
        self.jitterRatioRange = jitterRatioRange
        self.retryableStatusCodes = retryableStatusCodes
        self.retryableStatusCodeRanges = retryableStatusCodeRanges
        self.retryableURLErrorCodes = retryableURLErrorCodes
    }

    nonisolated func decision(for context: RetryContext, randomJitter: Double) -> RetryDecision {
        guard context.attempt < maxAttempts else {
            return .stop
        }

        if let error = context.error {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                return .stop
            }
            guard let urlError = error as? URLError, retryableURLErrorCodes.contains(urlError.code) else {
                return .stop
            }
            return .retry(after: delay(for: context.attempt, randomJitter: randomJitter))
        }

        guard let httpResponse = context.response as? HTTPURLResponse else {
            return .stop
        }

        let statusCode = httpResponse.statusCode
        guard retryableStatusCodes.contains(statusCode) || retryableStatusCodeRanges.contains(where: { $0.contains(statusCode) }) else {
            return .stop
        }

        return .retry(after: delay(for: context.attempt, randomJitter: randomJitter))
    }

    nonisolated private func delay(for attempt: Int, randomJitter: Double) -> TimeInterval {
        let exponent = max(0, attempt - 1)
        let base = baseDelay * pow(2, Double(exponent))
        let clampedJitter = min(max(randomJitter, jitterRatioRange.lowerBound), jitterRatioRange.upperBound)
        return base * (1 + clampedJitter)
    }
}

final class RequestExecutor {
    typealias Sleep = @Sendable (TimeInterval) async throws -> Void
    typealias RandomJitter = @Sendable (ClosedRange<Double>) -> Double

    private let session: URLSession
    private let sleep: Sleep
    private let randomJitter: RandomJitter

    nonisolated init(
        session: URLSession = .shared,
        sleep: @escaping Sleep = RequestExecutor.defaultSleep,
        randomJitter: @escaping RandomJitter = { Double.random(in: $0) }
    ) {
        self.session = session
        self.sleep = sleep
        self.randomJitter = randomJitter
    }

    nonisolated func perform(_ request: URLRequest, policy: RetryPolicy = .none) async throws -> (Data, URLResponse) {
        var attempt = 1

        while true {
            try Task.checkCancellation()

            do {
                let result = try await session.data(for: request)
                let context = RetryContext(attempt: attempt, request: request, response: result.1, error: nil)

                switch policy.decision(for: context, randomJitter: randomJitter(policy.jitterRatioRange)) {
                case .stop:
                    return result
                case .retry(let delay):
                    try await sleep(delay)
                    attempt += 1
                }
            } catch {
                let context = RetryContext(attempt: attempt, request: request, response: nil, error: error)

                switch policy.decision(for: context, randomJitter: randomJitter(policy.jitterRatioRange)) {
                case .stop:
                    throw error
                case .retry(let delay):
                    try await sleep(delay)
                    attempt += 1
                }
            }
        }
    }

    nonisolated private static func defaultSleep(_ delay: TimeInterval) async throws {
        let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
