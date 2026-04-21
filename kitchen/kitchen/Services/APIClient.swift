import Foundation

/// `Endpoint` 是纯请求描述符。
/// 不包含重试、缓存、mock、解码策略或分析行为。
struct Endpoint<Response: Decodable> {
    let path: String
    let method: String
    let headers: [String: String]
    let queryItems: [URLQueryItem]
    let body: Encodable?
    let requiresAuth: Bool

    init(
        path: String,
        method: String = "GET",
        headers: [String: String] = [:],
        queryItems: [URLQueryItem] = [],
        body: Encodable? = nil,
        requiresAuth: Bool = false
    ) {
        self.path = path
        self.method = method
        self.headers = headers
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
    private static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    init(baseURL: String? = nil) {
        self.baseURL = baseURL ?? Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String ?? "https://api.kitchen.onecat.dev"
    }

    // MARK: - Request Core

    func request<T: Decodable>(_ endpoint: Endpoint<T>, authToken: String? = nil) async throws -> T {
        let request = try buildRequest(endpoint, authToken: authToken)
        let (data, response) = try await URLSession.shared.data(for: request)
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
        authToken: String
    ) async throws -> T {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = method

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        request.httpBody = buildMultipartBody(
            fields: fields,
            repeatedFields: repeatedFields,
            fileField: fileField,
            fileName: fileName,
            fileData: fileData,
            fileContentType: fileContentType,
            boundary: boundary
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        return try decodeResponse(T.self, from: data, response: response)
    }

    func uploadBinaryAllowingEmptyBody(
        _ path: String,
        data: Data,
        contentType: String,
        authToken: String
    ) async throws -> Data? {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 300 {
            throw try decodeAPIError(from: data)
        }

        return data.isEmpty ? nil : data
    }

    // MARK: - Private Helpers

    private func buildRequest<T>(_ endpoint: Endpoint<T>, authToken: String?) throws -> URLRequest {
        var components = URLComponents(string: baseURL + endpoint.path)
        components?.queryItems = endpoint.queryItems.isEmpty ? nil : endpoint.queryItems

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = authToken, endpoint.requiresAuth {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            request.httpBody = try JSONEncoder().encode(body)
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

        if httpResponse.statusCode >= 400 {
            throw try decodeAPIError(from: data)
        }

        do {
            return try APIClient.jsonDecoder.decode(T.self, from: data)
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

    private func decodeAPIError(from data: Data) throws -> APIError {
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
