import Foundation
import SwiftData

@Model
final class Bucket {
    var id: UUID
    var name: String
    var icon: String // SF Symbol name
    var color: String // Hex color (#RRGGBB)
    var targetType: String // "none", "monthlyTarget", "byDateGoal"
    var targetAmount: Decimal?
    var targetDate: Date?
    var priority: Int // 1-10
    var rolloverMode: String // "rollover", "resetMonthly", "cappedRollover"
    var rolloverCap: Decimal?
    var allowNegative: Bool
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        icon: String = "folder.fill",
        color: String = "#007AFF",
        targetType: TargetType = .none,
        targetAmount: Decimal? = nil,
        targetDate: Date? = nil,
        priority: Int = 5,
        rolloverMode: RolloverMode = .rollover,
        rolloverCap: Decimal? = nil,
        allowNegative: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.targetType = targetType.rawValue
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.priority = priority
        self.rolloverMode = rolloverMode.rawValue
        self.rolloverCap = rolloverCap
        self.allowNegative = allowNegative
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Enums

enum TargetType: String, Codable, CaseIterable {
    case none
    case monthlyTarget
    case byDateGoal
}

enum RolloverMode: String, Codable, CaseIterable {
    case rollover
    case resetMonthly
    case cappedRollover
}

// MARK: - Computed Properties (non-persisted)

extension Bucket {
    /// Computed: Total allocated to this bucket (from AllocationEvents)
    var assigned: Decimal {
        // This will be calculated from AllocationEvents in the view/repository
        return 0
    }
    
    /// Computed: Total activity (from TransactionSplits)
    var activity: Decimal {
        // This will be calculated from TransactionSplits in the view/repository
        return 0
    }
    
    /// Computed: Available = Assigned + Activity
    var available: Decimal {
        return assigned + activity
    }
    
    /// Helper to get TargetType enum
    var targetTypeEnum: TargetType {
        TargetType(rawValue: targetType) ?? .none
    }
    
    /// Helper to get RolloverMode enum
    var rolloverModeEnum: RolloverMode {
        RolloverMode(rawValue: rolloverMode) ?? .rollover
    }
}
