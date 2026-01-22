import Foundation
import SwiftData

@Model
final class FundingRule {
    var id: UUID
    var name: String
    var enabled: Bool
    var priority: Int // Lower = higher priority
    var triggerType: String
    var conditionsJSON: String // JSON-encoded RuleConditions
    var actionsJSON: String // JSON-encoded array of RuleAction
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        enabled: Bool = true,
        priority: Int,
        triggerType: TriggerType,
        conditions: RuleConditions = RuleConditions(),
        actions: [RuleAction] = []
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.priority = priority
        self.triggerType = triggerType.rawValue
        self.conditionsJSON = (try? JSONEncoder().encode(conditions))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        self.actionsJSON = (try? JSONEncoder().encode(actions))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Rule Structures

struct RuleConditions: Codable {
    var accountId: String?
    var minAmount: Decimal?
    var merchantContains: String?
    var dayOfMonth: Int? // 1-31
    var weekday: Int? // 1-7, Sunday=1
    
    init(
        accountId: String? = nil,
        minAmount: Decimal? = nil,
        merchantContains: String? = nil,
        dayOfMonth: Int? = nil,
        weekday: Int? = nil
    ) {
        self.accountId = accountId
        self.minAmount = minAmount
        self.merchantContains = merchantContains
        self.dayOfMonth = dayOfMonth
        self.weekday = weekday
    }
}

enum RuleAction: Codable {
    case allocateFixed(bucketId: UUID, amount: Decimal)
    case allocatePercent(bucketId: UUID, percent: Double)
    case fillToTarget(bucketId: UUID)
    
    enum CodingKeys: String, CodingKey {
        case type
        case bucketId
        case amount
        case percent
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let bucketIdString = try container.decode(String.self, forKey: .bucketId)
        guard let bucketId = UUID(uuidString: bucketIdString) else {
            throw DecodingError.dataCorruptedError(forKey: .bucketId, in: container, debugDescription: "Invalid UUID")
        }
        
        switch type {
        case "allocateFixed":
            let amount = try container.decode(Decimal.self, forKey: .amount)
            self = .allocateFixed(bucketId: bucketId, amount: amount)
        case "allocatePercent":
            let percent = try container.decode(Double.self, forKey: .percent)
            self = .allocatePercent(bucketId: bucketId, percent: percent)
        case "fillToTarget":
            self = .fillToTarget(bucketId: bucketId)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown action type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .allocateFixed(let bucketId, let amount):
            try container.encode("allocateFixed", forKey: .type)
            try container.encode(bucketId.uuidString, forKey: .bucketId)
            try container.encode(amount, forKey: .amount)
        case .allocatePercent(let bucketId, let percent):
            try container.encode("allocatePercent", forKey: .type)
            try container.encode(bucketId.uuidString, forKey: .bucketId)
            try container.encode(percent, forKey: .percent)
        case .fillToTarget(let bucketId):
            try container.encode("fillToTarget", forKey: .type)
            try container.encode(bucketId.uuidString, forKey: .bucketId)
        }
    }
}

enum TriggerType: String, Codable, CaseIterable {
    case onIncomeDetected
    case scheduledDaily
    case scheduledWeekly
    case scheduledMonthly
    case manualRun
    case balanceThreshold
}

// MARK: - Extensions

extension FundingRule {
    var conditions: RuleConditions {
        get {
            guard let data = conditionsJSON.data(using: .utf8),
                  let conditions = try? JSONDecoder().decode(RuleConditions.self, from: data) else {
                return RuleConditions()
            }
            return conditions
        }
        set {
            conditionsJSON = (try? JSONEncoder().encode(newValue))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            updatedAt = Date()
        }
    }
    
    var actions: [RuleAction] {
        get {
            guard let data = actionsJSON.data(using: .utf8),
                  let actions = try? JSONDecoder().decode([RuleAction].self, from: data) else {
                return []
            }
            return actions
        }
        set {
            actionsJSON = (try? JSONEncoder().encode(newValue))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            updatedAt = Date()
        }
    }
    
    var triggerTypeEnum: TriggerType {
        TriggerType(rawValue: triggerType) ?? .manualRun
    }
}
