import Foundation

final class AIService {
    private let baseURL: URL
    private let urlSession: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    init(
        baseURL: URL = URL(string: Config.backendURL)!,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }
    
    func sendCommand(_ command: String, context: AIContext) async throws -> AICommandResponse {
        let requestBody = AICommandRequest(command: command, context: context)
        let url = baseURL.appendingPathComponent("ai/command")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = Config.getAPIKey() {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try encoder.encode(requestBody)
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw AIServiceError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
        
        return try decoder.decode(AICommandResponse.self, from: data)
    }
}

struct AIContext: Encodable {
    let unassignedBalance: Double
    let buckets: [AIContextBucket]
    let recentTransactions: [AIContextTransaction]
}

struct AIContextBucket: Encodable {
    let id: String
    let name: String
    let available: Double
}

struct AIContextTransaction: Encodable {
    let id: String
    let merchantName: String
    let amount: Double
    let date: String
}

struct AICommandRequest: Encodable {
    let command: String
    let context: AIContext
}

struct AICommandResponse: Decodable {
    let actions: [AIAction]
    let summary: String
    let warnings: [String]?
}

struct AIAction: Decodable, Identifiable {
    let raw: [String: AIJSONValue]
    let id: String
    
    var type: String {
        raw["type"]?.stringValue
            ?? raw["action"]?.stringValue
            ?? raw["actionType"]?.stringValue
            ?? raw["action_type"]?.stringValue
            ?? "action"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var raw: [String: AIJSONValue] = [:]
        for key in container.allKeys {
            raw[key.stringValue] = try container.decode(AIJSONValue.self, forKey: key)
        }
        self.raw = raw
        self.id = raw["id"]?.stringValue ?? UUID().uuidString
    }
    
    var prettyPrinted: String {
        guard let jsonObject = AIJSONValue.object(raw).toAny() as? [String: Any],
              let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
              let string = String(data: data, encoding: .utf8) else {
            return String(describing: raw)
        }
        return string
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

enum AIJSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: AIJSONValue])
    case array([AIJSONValue])
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .number(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([AIJSONValue].self) {
            self = .array(arrayValue)
        } else if let objectValue = try? container.decode([String: AIJSONValue].self) {
            self = .object(objectValue)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
    
    var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }
    
    func toAny() -> Any {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value
        case .bool(let value):
            return value
        case .object(let value):
            return value.mapValues { $0.toAny() }
        case .array(let value):
            return value.map { $0.toAny() }
        case .null:
            return NSNull()
        }
    }
}

private enum AIServiceError: LocalizedError {
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
