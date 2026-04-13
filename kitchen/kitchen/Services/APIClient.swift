import Foundation

enum APIError: LocalizedError {
    case network(Error)
    case server(Int, String)
    case decoding(Error)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .network: "网络连接失败，请检查网络"
        case .server(_, let msg): msg
        case .decoding: "数据解析失败"
        case .unauthorized: "未授权，请重新入驻"
        }
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
            baseURL = "http://localhost:8787"
        }
    }

    func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: Encodable? = nil,
        deviceId: String? = nil
    ) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let deviceId {
            request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
        }

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }

        if http.statusCode == 401 || http.statusCode == 403 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(http.statusCode) else {
            let msg = (try? decoder.decode(APIErrorMessage.self, from: data))?.message
                ?? "请求失败 (\(http.statusCode))"
            throw APIError.server(http.statusCode, msg)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}

private struct APIErrorMessage: Decodable {
    let message: String
}
