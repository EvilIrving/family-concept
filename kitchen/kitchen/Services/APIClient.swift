import Foundation

enum APIError: LocalizedError {
    case network(Error)
    case server(Int, String)
    case decoding(Error)
    case invalidResponse(String)
    case unauthorized

    var userMessage: String {
        switch self {
        case .network:
            return "网络连接失败，请检查网络"
        case .server(_, let msg):
            return msg
        case .decoding:
            return "数据解析失败"
        case .invalidResponse(let message):
            return message
        case .unauthorized:
            return "未授权，请重新登录"
        }
    }

    var errorDescription: String? { userMessage }
}

extension Error {
    var userMessage: String {
        if let apiError = self as? APIError {
            return apiError.userMessage
        }
        return localizedDescription
    }
}

@MainActor
final class APIClient {
    private let baseURL: String

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    init() {
        if let url = Bundle.main.infoDictionary?["APIBaseURL"] as? String, !url.isEmpty {
            baseURL = url
        } else {
            baseURL = "https://api.kitchen.onecat.dev"
        }
    }

    func request<T: Decodable>(_ endpoint: Endpoint<T>, authToken: String? = nil) async throws -> T {
        let request = try makeURLRequest(for: endpoint, authToken: authToken)
        let (data, response) = try await perform(request)
        try validate(response: response, data: data, fallbackMessage: "请求失败")

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw decodeError(error, data: data)
        }
    }

    func uploadBinary<T: Decodable>(
        _ path: String,
        data: Data,
        contentType: String,
        authToken: String? = nil
    ) async throws -> T {
        let url: URL
        if let absoluteURL = URL(string: path), absoluteURL.scheme != nil {
            url = absoluteURL
        } else {
            url = URL(string: "\(baseURL)\(path)")!
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if let authToken, !authToken.isEmpty {
            req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = data

        let (responseData, response) = try await perform(req)
        try validate(response: response, data: responseData, fallbackMessage: "上传失败")
        do {
            return try decoder.decode(T.self, from: responseData)
        } catch {
            throw decodeError(error, data: responseData)
        }
    }

    func uploadBinaryAllowingEmptyBody(
        _ path: String,
        data: Data,
        contentType: String,
        authToken: String? = nil
    ) async throws -> Data? {
        let url: URL
        if let absoluteURL = URL(string: path), absoluteURL.scheme != nil {
            url = absoluteURL
        } else {
            url = URL(string: "\(baseURL)\(path)")!
        }
        var req = URLRequest(url: url)
        req.httpMethod = "PUT"
        req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if let authToken, !authToken.isEmpty {
            req.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = data

        let (responseData, response) = try await perform(req)
        try validate(response: response, data: responseData, fallbackMessage: "上传失败")

        return responseData.isEmpty ? nil : responseData
    }

    func requestMultipart<T: Decodable>(
        _ path: String,
        method: String = "POST",
        fields: [String: String],
        repeatedFields: [String: [String]] = [:],
        fileField: String? = nil,
        fileName: String? = nil,
        fileData: Data? = nil,
        fileContentType: String? = nil,
        authToken: String? = nil
    ) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let authToken, !authToken.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n".utf8Data)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".utf8Data)
            body.append("\(value)\r\n".utf8Data)
        }

        for (key, values) in repeatedFields {
            for value in values {
                body.append("--\(boundary)\r\n".utf8Data)
                body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".utf8Data)
                body.append("\(value)\r\n".utf8Data)
            }
        }

        if let fileField, let fileName, let fileData, let fileContentType {
            body.append("--\(boundary)\r\n".utf8Data)
            body.append(
                "Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n".utf8Data
            )
            body.append("Content-Type: \(fileContentType)\r\n\r\n".utf8Data)
            body.append(fileData)
            body.append("\r\n".utf8Data)
        }

        body.append("--\(boundary)--\r\n".utf8Data)
        request.httpBody = body

        let (data, response) = try await perform(request)
        try validate(response: response, data: data, fallbackMessage: "请求失败")

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw decodeError(error, data: data)
        }
    }

    fileprivate func makeURLRequest<T: Decodable>(for endpoint: Endpoint<T>, authToken: String?) throws -> URLRequest {
        var components = URLComponents(string: "\(baseURL)\(endpoint.path)")
        if !endpoint.queryItems.isEmpty {
            components?.queryItems = endpoint.queryItems
        }

        guard let url = components?.url else {
            throw APIError.invalidResponse("接口地址无效")
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method

        let needsJSONBody = endpoint.body != nil
        if needsJSONBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        for (header, value) in endpoint.headers {
            request.setValue(value, forHTTPHeaderField: header)
        }

        if endpoint.requiresAuth, let authToken, !authToken.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        return request
    }

    fileprivate func perform(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.network(error)
        }
    }

    fileprivate func validate(response: URLResponse, data: Data, fallbackMessage: String) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let msg = (try? decoder.decode(APIErrorMessage.self, from: data))?.message
                ?? "\(fallbackMessage) (\(http.statusCode))"
            throw APIError.server(http.statusCode, msg)
        }
    }

    fileprivate func decodeError(_ error: Error, data: Data) -> APIError {
        if data.isEmpty {
            return .invalidResponse("接口返回为空")
        }

        if let text = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            let preview = String(text.prefix(120))
            return .invalidResponse("接口返回格式异常：\(preview)")
        }

        return .decoding(error)
    }
}

private struct APIErrorMessage: Decodable {
    let message: String
}

private extension String {
    var utf8Data: Data { Data(utf8) }
}
