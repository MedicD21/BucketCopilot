import Foundation
import SwiftData

@MainActor
final class SyncService {
    struct SyncSummary {
        let pushed: Int
        let pulled: Int
        let applied: Int
    }
    
    private let modelContext: ModelContext
    private let baseURL: URL
    private let urlSession: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    init(
        modelContext: ModelContext,
        baseURL: URL = URL(string: Config.backendURL)!,
        urlSession: URLSession = .shared
    ) {
        self.modelContext = modelContext
        self.baseURL = baseURL
        self.urlSession = urlSession
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            let string = SyncService.iso8601WithFractional.string(from: date)
            try container.encode(string)
        }
        self.encoder = encoder
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = SyncService.iso8601WithFractional.date(from: string) {
                return date
            }
            if let date = SyncService.iso8601.date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(string)")
        }
        self.decoder = decoder
    }
    
    func sync() async throws -> SyncSummary {
        let pushed = try await pushAllocationEvents()
        let pullResponse = try await pullEvents()
        let applied = try apply(events: pullResponse.events)
        try updateCursor(from: pullResponse.nextCursor)
        
        return SyncSummary(
            pushed: pushed,
            pulled: pullResponse.events.count,
            applied: applied
        )
    }
    
    // MARK: - Push
    
    private func pushAllocationEvents() async throws -> Int {
        let descriptor = FetchDescriptor<AllocationEvent>(
            predicate: #Predicate { $0.synced == false }
        )
        let events = try modelContext.fetch(descriptor)
        
        guard !events.isEmpty else {
            return 0
        }
        
        let pushEvents = events.map { event in
            SyncPushEvent(
                eventType: "allocation",
                timestamp: event.timestamp,
                payload: allocationPayload(for: event),
                deviceId: nil
            )
        }
        
        let request = SyncPushRequest(events: pushEvents)
        _ = try await sendRequest(
            path: "sync/pushEvents",
            method: "POST",
            body: request,
            responseType: SyncPushResponse.self
        )
        
        events.forEach { $0.synced = true }
        try modelContext.save()
        
        return events.count
    }
    
    // MARK: - Pull
    
    private func pullEvents() async throws -> SyncPullResponse {
        let state = try loadSyncState()
        var queryItems: [URLQueryItem] = []
        
        if let lastTimestamp = state.lastSyncTimestamp {
            let timestamp = SyncService.iso8601WithFractional.string(from: lastTimestamp)
            queryItems.append(URLQueryItem(name: "sinceTimestamp", value: timestamp))
            queryItems.append(URLQueryItem(name: "sinceSequence", value: String(state.lastSyncSequence)))
        }
        
        return try await sendRequest(
            path: "sync/pullEvents",
            method: "GET",
            queryItems: queryItems,
            responseType: SyncPullResponse.self
        )
    }
    
    private func apply(events: [SyncEvent]) throws -> Int {
        var applied = 0
        
        for event in events {
            if event.eventType == "allocation" || event.eventType == "allocation_event" {
                if try applyAllocationEvent(event) {
                    applied += 1
                }
            }
        }
        
        if applied > 0 {
            try modelContext.save()
        }
        
        return applied
    }
    
    private func applyAllocationEvent(_ event: SyncEvent) throws -> Bool {
        guard let payload = event.payload else {
            return false
        }
        guard let idString = payload.stringValue(for: "id"),
              let id = UUID(uuidString: idString) else {
            return false
        }
        
        let existingDescriptor = FetchDescriptor<AllocationEvent>(
            predicate: #Predicate { $0.id == id }
        )
        if try modelContext.fetch(existingDescriptor).first != nil {
            return false
        }
        
        let bucket: Bucket?
        if let bucketIdString = payload.stringValue(for: "bucketId"),
           let bucketId = UUID(uuidString: bucketIdString) {
            let bucketDescriptor = FetchDescriptor<Bucket>(
                predicate: #Predicate { $0.id == bucketId }
            )
            bucket = try modelContext.fetch(bucketDescriptor).first
        } else {
            bucket = nil
        }
        
        guard let amountValue = payload.doubleValue(for: "amount") else {
            return false
        }
        
        let sourceTypeRaw = payload.stringValue(for: "sourceType") ?? "manual"
        let sourceType = SourceType(rawValue: sourceTypeRaw) ?? (sourceTypeRaw == "import" ? .import_ : .manual)
        let sourceId = payload.stringValue(for: "sourceId")
        let timestamp = event.timestamp
        let sequence = event.sequence ?? 0
        
        let allocationEvent = AllocationEvent(
            id: id,
            bucket: bucket,
            amount: Decimal(amountValue),
            sourceType: sourceType,
            sourceId: sourceId,
            timestamp: timestamp,
            sequence: sequence,
            synced: true
        )
        
        modelContext.insert(allocationEvent)
        return true
    }
    
    private func updateCursor(from cursor: SyncCursor) throws {
        let state = try loadSyncState()
        state.lastSyncTimestamp = cursor.timestamp
        state.lastSyncSequence = cursor.sequence
        state.backendUrl = baseURL.absoluteString
        try modelContext.save()
    }
    
    private func loadSyncState() throws -> SyncState {
        let descriptor = FetchDescriptor<SyncState>()
        if let existing = try modelContext.fetch(descriptor).first {
            return existing
        }
        
        let state = SyncState(syncEnabled: true, backendUrl: baseURL.absoluteString)
        modelContext.insert(state)
        try modelContext.save()
        return state
    }
    
    // MARK: - Networking
    
    private func sendRequest<ResponseBody: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        responseType: ResponseBody.Type
    ) async throws -> ResponseBody {
        return try await sendRequest(
            path: path,
            method: method,
            body: Optional<EmptyRequestBody>.none,
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
            if let updatedURL = components?.url {
                url = updatedURL
            }
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey = Config.getAPIKey() {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }
        
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SyncError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8)
            throw SyncError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
        
        return try decoder.decode(ResponseBody.self, from: data)
    }
    
    // MARK: - Payload Mapping
    
    private func allocationPayload(for event: AllocationEvent) -> [String: JSONValue] {
        var payload: [String: JSONValue] = [
            "id": .string(event.id.uuidString),
            "amount": .number(decimalToDouble(event.amount)),
            "sourceType": .string(event.sourceType),
            "timestamp": .string(SyncService.iso8601WithFractional.string(from: event.timestamp)),
            "sequence": .number(Double(event.sequence))
        ]
        
        if let bucketId = event.bucket?.id {
            payload["bucketId"] = .string(bucketId.uuidString)
        }
        if let sourceId = event.sourceId {
            payload["sourceId"] = .string(sourceId)
        }
        
        return payload
    }
    
    private func decimalToDouble(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
    
    private static let iso8601WithFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

// MARK: - API Types

private struct SyncPushRequest: Codable {
    let events: [SyncPushEvent]
}

private struct EmptyRequestBody: Encodable {}

private struct SyncPushEvent: Codable {
    let eventType: String
    let timestamp: Date
    let payload: [String: JSONValue]
    let deviceId: String?
}

private struct SyncPushResponse: Codable {
    let success: Bool
    let events: [SyncEvent]
}

private struct SyncPullResponse: Codable {
    let events: [SyncEvent]
    let hasMore: Bool
    let nextCursor: SyncCursor
}

private struct SyncCursor: Codable {
    let timestamp: Date
    let sequence: Int64
}

private struct SyncEvent: Codable {
    let id: UUID?
    let userId: UUID?
    let eventType: String
    let timestamp: Date
    let sequence: Int64?
    let payload: [String: JSONValue]?
    let deviceId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case eventType = "event_type"
        case timestamp
        case sequence
        case payload
        case deviceId = "device_id"
    }
}

private enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .number(Double(value))
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid JSON value")
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
    
    fileprivate func stringValue(for key: String) -> String? {
        guard case let .object(object) = self else {
            return nil
        }
        if case let .string(value) = object[key] {
            return value
        }
        return nil
    }
    
    fileprivate func doubleValue(for key: String) -> Double? {
        guard case let .object(object) = self else {
            return nil
        }
        if case let .number(value) = object[key] {
            return value
        }
        if case let .string(value) = object[key], let parsed = Double(value) {
            return parsed
        }
        return nil
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    func stringValue(for key: String) -> String? {
        if case let .string(value) = self[key] {
            return value
        }
        return nil
    }
    
    func doubleValue(for key: String) -> Double? {
        if case let .number(value) = self[key] {
            return value
        }
        if case let .string(value) = self[key], let parsed = Double(value) {
            return parsed
        }
        return nil
    }
}

private enum SyncError: LocalizedError {
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
