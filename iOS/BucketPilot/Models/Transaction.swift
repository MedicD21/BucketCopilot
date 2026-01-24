import Foundation
import SwiftData

@Model
final class Account {
    var id: UUID
    var plaidAccountId: String
    var name: String
    var officialName: String?
    var type: String?
    var subtype: String?
    var mask: String?
    var institutionId: String?
    var institutionName: String?
    var currentBalance: Decimal?
    var availableBalance: Decimal?
    var creditLimit: Decimal?
    var isoCurrencyCode: String?
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        plaidAccountId: String,
        name: String,
        officialName: String? = nil,
        type: String? = nil,
        subtype: String? = nil,
        mask: String? = nil,
        institutionId: String? = nil,
        institutionName: String? = nil,
        currentBalance: Decimal? = nil,
        availableBalance: Decimal? = nil,
        creditLimit: Decimal? = nil,
        isoCurrencyCode: String? = nil
    ) {
        self.id = id
        self.plaidAccountId = plaidAccountId
        self.name = name
        self.officialName = officialName
        self.type = type
        self.subtype = subtype
        self.mask = mask
        self.institutionId = institutionId
        self.institutionName = institutionName
        self.currentBalance = currentBalance
        self.availableBalance = availableBalance
        self.creditLimit = creditLimit
        self.isoCurrencyCode = isoCurrencyCode
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

extension Account {
    var displayName: String {
        if let mask = mask, !mask.isEmpty {
            return "\(name) ••\(mask)"
        }
        return name
    }
    
    var displayBalance: Decimal? {
        if let currentBalance = currentBalance {
            return currentBalance
        }
        return availableBalance
    }
}

@Model
final class Transaction {
    var id: UUID
    var plaidTransactionId: String? // Stable Plaid ID for deduplication
    var accountId: String
    var merchantName: String?
    var amount: Decimal // Negative for debits, positive for credits
    var date: Date
    var category: String? // JSON array stored as string
    var details: String?
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
        details: String? = nil,
        isPending: Bool = false
    ) {
        self.id = id
        self.plaidTransactionId = plaidTransactionId
        self.accountId = accountId
        self.merchantName = merchantName
        self.amount = amount
        self.date = date
        self.category = category.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) }
        self.details = details
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

    var isTransferLike: Bool {
        let categoryTokens = categoryArray?.map { $0.lowercased() } ?? []
        if categoryTokens.contains(where: { $0.contains("transfer") || $0.contains("payment") }) {
            return true
        }
        let name = (merchantName ?? details ?? "").lowercased()
        return name.contains("transfer") || name.contains("payment")
    }
}
