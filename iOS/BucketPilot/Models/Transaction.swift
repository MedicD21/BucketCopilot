import Foundation
import SwiftData

@Model
final class Transaction {
    var id: UUID
    var plaidTransactionId: String? // Stable Plaid ID for deduplication
    var accountId: String
    var merchantName: String?
    var amount: Decimal // Negative for debits, positive for credits
    var date: Date
    var category: String? // JSON array stored as string
    var description: String?
    var isPending: Bool
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        plaidTransactionId: String? = nil,
        accountId: String,
        merchantName: String? = nil,
        amount: Decimal,
        date: Date = Date(),
        category: [String]? = nil,
        description: String? = nil,
        isPending: Bool = false
    ) {
        self.id = id
        self.plaidTransactionId = plaidTransactionId
        self.accountId = accountId
        self.merchantName = merchantName
        self.amount = amount
        self.date = date
        self.category = category.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
        self.description = description
        self.isPending = isPending
        self.createdAt = Date()
    }
}

extension Transaction {
    var categoryArray: [String]? {
        guard let category = category,
              let data = category.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return nil
        }
        return array
    }
    
    var displayAmount: Decimal {
        abs(amount)
    }
    
    var isDebit: Bool {
        amount < 0
    }
    
    var isCredit: Bool {
        amount > 0
    }
}
