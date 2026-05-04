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
        var request = try buildMultipartURLRequest(
            path: path,
            method: method,
            authToken: authToken,
            boundary: boundary
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
        method: String = "POST",
        data: Data,
        contentType: String,
        authToken: String,
        retryPolicy: RetryPolicy? = nil
    ) async throws -> Data? {
        var request = try buildURLRequest(
            path: path,
            method: method,
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

    fileprivate func performRequest(_ request: URLRequest, retryPolicy: RetryPolicy) async throws -> (Data, URLResponse) {
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

    fileprivate func defaultRetryPolicy(for method: String) -> RetryPolicy {
        method.uppercased() == "GET" ? .standard : .none
    }

    fileprivate func buildRequest<T>(_ endpoint: Endpoint<T>, authToken: String?) throws -> URLRequest {
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

    fileprivate func buildURLRequest(
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

    fileprivate func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data, response: URLResponse) throws -> T {
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

    fileprivate func decodeAPIError(statusCode: Int, from data: Data) throws -> APIError {
        if statusCode == 401 {
            return .unauthorized
        }

        if data.isEmpty {
            return .invalidResponse(L10n.tr("Empty server response"))
        }

        if let payload = try? APIClient.decodeJSON(ServerErrorPayload.self, from: data) {
            let message = payload.message.trimmingCharacters(in: .whitespacesAndNewlines)
            if !message.isEmpty {
                return .serverMessage(message)
            }
        }

        if let message = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty {
            if looksLikeHTML(message) {
                return .invalidResponse(L10n.tr("Server error. Try again later."))
            }
            return .serverMessage(message)
        }

        return .invalidResponse(L10n.tr("Unexpected error response format"))
    }

    private func looksLikeHTML(_ message: String) -> Bool {
        let lowercased = message.lowercased()
        return lowercased.hasPrefix("<!doctype html")
            || lowercased.hasPrefix("<html")
            || lowercased.contains("<title>")
            || lowercased.contains("<body")
    }

    private func buildMultipartURLRequest(
        path: String,
        method: String,
        authToken: String?,
        boundary: String
    ) throws -> URLRequest {
        try buildURLRequest(
            path: path,
            method: method,
            authToken: authToken,
            contentType: "multipart/form-data; boundary=\(boundary)"
        )
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
}

private struct ServerErrorPayload: Decodable {
    let message: String
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
            return L10n.tr("Invalid request URL")
        case .network:
            return L10n.tr("Network error. Check your connection.")
        case .unauthorized:
            return L10n.tr("Session expired. Sign in again.")
        case .invalidResponse(let msg), .serverMessage(let msg):
            return msg
        case .decoding(let error):
            return L10n.tr("Failed to parse data: %@", error.localizedDescription)
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
