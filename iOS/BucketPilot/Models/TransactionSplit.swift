import Foundation
import SwiftData

@Model
final class TransactionSplit {
    var id: UUID
    var transaction: Transaction?
    var bucket: Bucket? // nil = Unassigned
    var amount: Decimal
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        transaction: Transaction? = nil,
        bucket: Bucket? = nil,
        amount: Decimal
    ) {
        self.id = id
        self.transaction = transaction
        self.bucket = bucket
        self.amount = amount
        self.createdAt = Date()
    }
}
