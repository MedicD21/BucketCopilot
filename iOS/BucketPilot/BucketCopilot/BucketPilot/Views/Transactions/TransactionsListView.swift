import SwiftUI
import SwiftData

struct AccountsListView: View {
    @Query(sort: \Account.name) private var accounts: [Account]

    var groupedAccounts: [(name: String, accounts: [Account])] {
        let grouped = Dictionary(grouping: accounts) { account in
            account.institutionName ?? "Other"
        }
        return grouped
            .map { key, value in
                (name: key, accounts: value.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if groupedAccounts.isEmpty {
                    EmptyAccountsView()
                } else {
                    List {
                        ForEach(groupedAccounts, id: \.name) { group in
                            Section(group.name) {
                                ForEach(group.accounts) { account in
                                    NavigationLink(destination: AccountDetailView(account: account)) {
                                        AccountRow(account: account)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Accounts")
        }
    }
}

struct AccountRow: View {
    let account: Account
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName)
                    .font(.headline)
                
                if let subtype = account.subtype {
                    Text(subtype.capitalized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let balance = account.displayBalance {
                    Text(formatCurrency(balance))
                        .font(.headline)
                } else {
                    Text("—")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                if let limit = account.creditLimit {
                    Text("Limit \(formatCurrency(limit))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        NumberFormatter.currency.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

struct AccountDetailView: View {
    let account: Account
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    
    var accountTransactions: [Transaction] {
        transactions.filter { $0.accountId == account.plaidAccountId }
    }
    
    var body: some View {
        List {
            Section {
                AccountSummaryView(account: account)
            }
            
            Section("Transactions") {
                if accountTransactions.isEmpty {
                    Text("No transactions for this account.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(accountTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
        .navigationTitle(account.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AccountSummaryView: View {
    let account: Account
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let institutionName = account.institutionName {
                SummaryTextRow(label: "Institution", value: institutionName)
            }
            if let currentBalance = account.currentBalance {
                SummaryRow(label: "Current Balance", value: currentBalance)
            }
            if let availableBalance = account.availableBalance {
                SummaryRow(label: "Available Balance", value: availableBalance)
            }
            if let creditLimit = account.creditLimit {
                SummaryRow(label: "Credit Limit", value: creditLimit)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SummaryRow: View {
    let label: String
    let value: Decimal
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(formatCurrency(value))
                .foregroundColor(.secondary)
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        NumberFormatter.currency.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

struct SummaryTextRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.merchantName ?? transaction.details ?? "Unknown")
                    .font(.headline)
                
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(abs(transaction.amount)))
                    .font(.headline)
                    .foregroundColor(transaction.isDebit ? .red : .green)
                
                if transaction.isPending {
                    Text("Pending")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        NumberFormatter.currency.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }
}

struct EmptyAccountsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "banknote")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Accounts")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Connect your bank in Settings to import accounts")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
