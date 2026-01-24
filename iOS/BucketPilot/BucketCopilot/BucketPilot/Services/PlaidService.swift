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

    func isConnected() async -> Bool {
        do {
            let response: AccountsResponse = try await sendRequest(
                path: "plaid/accounts",
                method: "GET",
                queryItems: [],
                responseType: AccountsResponse.self
            )
            return !response.accounts.isEmpty
        } catch {
            return false
        }
    }

    func fetchAccounts() async throws -> [PlaidAccount] {
        let response: AccountsResponse = try await sendRequest(
            path: "plaid/accounts",
            method: "GET",
            responseType: AccountsResponse.self
        )
        return response.accounts
    }

    func fetchTransactions(
        startDate: Date = Calendar.current.date(byAdding: .year, value: -2, to: Date())
            ?? Date(timeIntervalSinceNow: -60 * 60 * 24 * 365 * 2),
        endDate: Date = Date()
    ) async throws -> [PlaidTransaction] {
        let queryItems = [
            URLQueryItem(name: "start_date", value: Self.plaidDateFormatter.string(from: startDate)),
            URLQueryItem(name: "end_date", value: Self.plaidDateFormatter.string(from: endDate))
        ]
        let response: TransactionsResponse = try await sendRequest(
            path: "plaid/transactions",
            method: "GET",
            queryItems: queryItems,
            responseType: TransactionsResponse.self
        )
        return response.transactions
    }

    private func sendRequest<ResponseBody: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        responseType: ResponseBody.Type
    ) async throws -> ResponseBody {
        return try await sendRequest(
            path: path,
            method: method,
            body: Optional<EmptyBody>.none,
            queryItems: queryItems,
            responseType: responseType
        )
    }
    
    private func sendRequest<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        method: String,
        body: RequestBody?,
        queryItems: [URLQueryItem] = [],
        responseType: ResponseBody.Type
    ) async throws -> ResponseBody {
        var url = baseURL.appendingPathComponent(path)
        if !queryItems.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = queryItems
            if let withQuery = components?.url {
                url = withQuery
            }
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = Config.getAPIKey() {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }
        
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

private struct AccountsResponse: Decodable {
    let accounts: [PlaidAccount]
}

struct PlaidAccount: Decodable {
    let accountId: String
    let name: String
    let officialName: String?
    let type: String?
    let subtype: String?
    let mask: String?
    let institutionId: String?
    let institutionName: String?
    let balances: PlaidBalances
    
    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case name
        case officialName = "official_name"
        case type
        case subtype
        case mask
        case institutionId = "institution_id"
        case institutionName = "institution_name"
        case balances
    }
}

struct PlaidBalances: Decodable {
    let available: Double?
    let current: Double?
    let limit: Double?
    let isoCurrencyCode: String?
    
    enum CodingKeys: String, CodingKey {
        case available
        case current
        case limit
        case isoCurrencyCode = "iso_currency_code"
    }
}

private struct EmptyBody: Encodable {}

struct PlaidTransaction: Decodable {
    let transactionId: String
    let accountId: String
    let name: String
    let merchantName: String?
    let amount: Double
    let date: String
    let category: [String]?
    let pending: Bool
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case accountId = "account_id"
        case name
        case merchantName = "merchant_name"
        case amount
        case date
        case category
        case pending
    }
}

private struct TransactionsResponse: Decodable {
    let transactions: [PlaidTransaction]
    let totalTransactions: Int?
    let nextCursor: String?
    
    enum CodingKeys: String, CodingKey {
        case transactions
        case totalTransactions = "total_transactions"
        case nextCursor = "next_cursor"
    }
}

private extension PlaidService {
    static let plaidDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

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
