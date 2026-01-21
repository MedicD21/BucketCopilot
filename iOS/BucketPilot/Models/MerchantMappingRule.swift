import Foundation
import SwiftData

@Model
final class MerchantMappingRule {
    var id: UUID
    var merchantContains: String
    var bucket: Bucket?
    var priority: Int // Lower = higher priority
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        merchantContains: String,
        bucket: Bucket? = nil,
        priority: Int = 5
    ) {
        self.id = id
        self.merchantContains = merchantContains
        self.bucket = bucket
        self.priority = priority
        self.createdAt = Date()
    }
}
