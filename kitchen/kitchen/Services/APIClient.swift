import Foundation

/// `Endpoint` 是纯请求描述符。
/// 不包含重试、缓存、mock、解码策略或分析行为。
struct Endpoint<Response: Decodable> {
    let path: String
    let method: String
    let queryItems: [URLQueryItem]
    let body: Encodable?
    let requiresAuth: Bool

    init(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem] = [],
        body: Encodable? = nil,
        requiresAuth: Bool = false
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
        self.requiresAuth = requiresAuth
    }
}

/// API 命名空间
enum APIEndpoints {}

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

/// API 客户端核心类
/// 负责请求执行、认证头注入、响应解码和错误处理
final class APIClient {
    private let baseURL: String
    private let requestExecutor: RequestExecutor
    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    static func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try jsonDecoder.decode(type, from: data)
    }

    init(
        baseURL: String? = nil,
        session: URLSession = .shared,
        requestExecutor: RequestExecutor? = nil
    ) {
        self.baseURL = baseURL ?? Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String ?? "https://api.kitchen.onecat.dev"
        self.requestExecutor = requestExecutor ?? RequestExecutor(session: session)
    }

    // MARK: - Request Core

    func request<T: Decodable>(
        _ endpoint: Endpoint<T>,
        authToken: String? = nil,
        retryPolicy: RetryPolicy? = nil
    ) async throws -> T {
        let request = try buildRequest(endpoint, authToken: authToken)
        let (data, response) = try await performRequest(request, retryPolicy: retryPolicy ?? defaultRetryPolicy(for: endpoint.method))
        return try decodeResponse(T.self, from: data, response: response)
    }

    func requestMultipart<T: Decodable>(
        _ path: String,
        method: String,
        fields: [String: String],
        repeatedFields: [String: [String]],
        fileField: String,
        fileName: String,
        fileData: Data,
        fileContentType: String,
        authToken: String,
        retryPolicy: RetryPolicy? = nil
    ) async throws -> T {
        let boundary = UUID().uuidString
        var request = try buildURLRequest(
            path: path,
            method: method,
            authToken: authToken,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )

        request.httpBody = buildMultipartBody(
            fields: fields,
            repeatedFields: repeatedFields,
            fileField: fileField,
            fileName: fileName,
            fileData: fileData,
            fileContentType: fileContentType,
            boundary: boundary
        )

        let (data, response) = try await performRequest(request, retryPolicy: retryPolicy ?? defaultRetryPolicy(for: method))
        return try decodeResponse(T.self, from: data, response: response)
    }

    func uploadBinaryAllowingEmptyBody(
        _ path: String,
        data: Data,
        contentType: String,
        authToken: String,
        retryPolicy: RetryPolicy? = nil
    ) async throws -> Data? {
        var request = try buildURLRequest(
            path: path,
            method: "POST",
            authToken: authToken,
            contentType: contentType
        )
        request.httpBody = data

        let (data, response) = try await performRequest(request, retryPolicy: retryPolicy ?? .none)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 300 {
            throw try decodeAPIError(statusCode: httpResponse.statusCode, from: data)
        }

        return data.isEmpty ? nil : data
    }

    // MARK: - Private Helpers

    private func performRequest(_ request: URLRequest, retryPolicy: RetryPolicy) async throws -> (Data, URLResponse) {
        do {
            return try await requestExecutor.perform(request, policy: retryPolicy)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code != .cancelled {
            throw APIError.network
        } catch {
            throw error
        }
    }

    private func defaultRetryPolicy(for method: String) -> RetryPolicy {
        method.uppercased() == "GET" ? .standard : .none
    }

    private func buildRequest<T>(_ endpoint: Endpoint<T>, authToken: String?) throws -> URLRequest {
        var request = try buildURLRequest(
            path: endpoint.path,
            method: endpoint.method,
            authToken: endpoint.requiresAuth ? authToken : nil,
            contentType: "application/json",
            queryItems: endpoint.queryItems
        )

        if let body = endpoint.body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        return request
    }

    private func buildURLRequest(
        path: String,
        method: String,
        authToken: String?,
        contentType: String,
        queryItems: [URLQueryItem] = []
    ) throws -> URLRequest {
        var components = URLComponents(string: baseURL + path)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func buildMultipartBody(
        fields: [String: String],
        repeatedFields: [String: [String]],
        fileField: String,
        fileName: String,
        fileData: Data,
        fileContentType: String,
        boundary: String
    ) -> Data {
        var body = Data()
        let crlf = "\r\n"

        for (key, value) in fields {
            body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\(crlf)\(crlf)".data(using: .utf8)!)
            body.append("\(value)\(crlf)".data(using: .utf8)!)
        }

        for (key, values) in repeatedFields {
            for value in values {
                body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\(crlf)\(crlf)".data(using: .utf8)!)
                body.append("\(value)\(crlf)".data(using: .utf8)!)
            }
        }

        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: \(fileContentType)\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(fileData)
        body.append("\(crlf)--\(boundary)--\(crlf)".data(using: .utf8)!)

        return body
    }

    private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data, response: URLResponse) throws -> T {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.network
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        if httpResponse.statusCode >= 400 {
            throw try decodeAPIError(statusCode: httpResponse.statusCode, from: data)
        }

        do {
            return try APIClient.decodeJSON(T.self, from: data)
        } catch {
            #if DEBUG
            if let jsonString = String(data: data, encoding: .utf8) {
                print("⚠️ 解码失败，原始响应：\(jsonString)")
                print("⚠️ 期望类型：\(T.self)")
                print("⚠️ 错误详情：\(error.localizedDescription)")
            }
            #endif
            throw APIError.decoding(error)
        }
    }

    private func decodeAPIError(statusCode: Int, from data: Data) throws -> APIError {
        if statusCode == 401 {
            return .unauthorized
        }

        if data.isEmpty {
            return .invalidResponse("服务器返回为空")
        }

        if let message = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty {
            return .serverMessage(message)
        }

        return .invalidResponse("错误响应格式异常")
    }
}

// MARK: - APIError

enum APIError: LocalizedError {
    case invalidURL
    case network
    case unauthorized
    case invalidResponse(String)
    case serverMessage(String)
    case decoding(Error)

    var userMessage: String {
        switch self {
        case .invalidURL:
            return "请求地址无效"
        case .network:
            return "网络错误，请检查连接"
        case .unauthorized:
            return "登录已过期，请重新登录"
        case .invalidResponse(let msg), .serverMessage(let msg):
            return msg
        case .decoding(let error):
            return "数据解析失败：\(error.localizedDescription)"
        }
    }
}

extension APIError: Equatable {
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL), (.network, .network), (.unauthorized, .unauthorized):
            return true
        case (.invalidResponse(let lhsMessage), .invalidResponse(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.serverMessage(let lhsMessage), .serverMessage(let rhsMessage)):
            return lhsMessage == rhsMessage
        case (.decoding, .decoding):
            return true
        default:
            return false
        }
    }
}
