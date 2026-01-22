import Foundation

final class PlaidService {
    private let baseURL: URL
    private let urlSession: URLSession
    private let decoder = JSONDecoder()
    
    init(
        baseURL: URL = URL(string: Config.backendURL)!,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }
    
    func createLinkToken() async throws -> String {
        let response: LinkTokenResponse = try await sendRequest(
            path: "plaid/create_link_token",
            method: "POST",
            body: EmptyBody(),
            responseType: LinkTokenResponse.self
        )
        
        return response.linkToken
    }
    
    func exchangePublicToken(_ publicToken: String) async throws {
        let request = ExchangePublicTokenRequest(publicToken: publicToken)
        _ = try await sendRequest(
            path: "plaid/exchange_public_token",
            method: "POST",
            body: request,
            responseType: ExchangePublicTokenResponse.self
        )
    }
    
    private func sendRequest<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        method: String,
        body: RequestBody,
        responseType: ResponseBody.Type
    ) async throws -> ResponseBody {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = Config.getAPIKey() {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PlaidServiceError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw PlaidServiceError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
        
        return try decoder.decode(ResponseBody.self, from: data)
    }
}

private struct LinkTokenResponse: Decodable {
    let linkToken: String
    
    enum CodingKeys: String, CodingKey {
        case linkToken = "link_token"
    }
}

private struct ExchangePublicTokenRequest: Encodable {
    let publicToken: String
    
    enum CodingKeys: String, CodingKey {
        case publicToken = "public_token"
    }
}

private struct ExchangePublicTokenResponse: Decodable {
    let success: Bool
}

private struct EmptyBody: Encodable {}

private enum PlaidServiceError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            if let message = message, !message.isEmpty {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server error (\(statusCode))"
        }
    }
}
