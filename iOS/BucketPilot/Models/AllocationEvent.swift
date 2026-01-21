import Foundation
import SwiftData

@Model
final class AllocationEvent {
    var id: UUID
    var bucket: Bucket? // nil = allocated FROM Unassigned (source)
    var amount: Decimal // Positive = allocated TO bucket, Negative = removed FROM bucket
    var sourceType: String // "manual", "rule", "import"
    var sourceId: String? // Rule ID or "manual" or nil
    var timestamp: Date
    var sequence: Int64
    var synced: Bool
    
    init(
        id: UUID = UUID(),
        bucket: Bucket? = nil,
        amount: Decimal,
        sourceType: SourceType,
        sourceId: String? = nil,
        timestamp: Date = Date(),
        sequence: Int64 = 0,
        synced: Bool = false
    ) {
        self.id = id
        self.bucket = bucket
        self.amount = amount
        self.sourceType = sourceType.rawValue
        self.sourceId = sourceId
        self.timestamp = timestamp
        self.sequence = sequence
        self.synced = synced
    }
}

enum SourceType: String, Codable {
    case manual
    case rule
    case import_
}
