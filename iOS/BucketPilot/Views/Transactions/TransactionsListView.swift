import SwiftUI
import SwiftData

struct TransactionsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]
    @State private var showingAddTransaction = false
    @State private var filter: TransactionFilter = .all
    
    var filteredTransactions: [Transaction] {
        switch filter {
        case .all:
            return transactions
        case .unassigned:
            // Filter transactions with no splits or splits to nil bucket
            return transactions.filter { transaction in
                // TODO: Check if transaction has unassigned splits only
                true // Placeholder
            }
        case .pending:
            return transactions.filter { $0.isPending }
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if filteredTransactions.isEmpty {
                    EmptyTransactionsView(onAddTransaction: { showingAddTransaction = true })
                } else {
                    List {
                        Picker("Filter", selection: $filter) {
                            ForEach(TransactionFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowInsets(EdgeInsets())
                        
                        ForEach(filteredTransactions) { transaction in
                            TransactionRow(transaction: transaction)
                        }
                    }
                }
            }
            .navigationTitle("Transactions")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddTransaction = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTransaction) {
                AddTransactionView()
            }
        }
    }
}

enum TransactionFilter: String, CaseIterable {
    case all = "All"
    case unassigned = "Unassigned"
    case pending = "Pending"
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

struct EmptyTransactionsView: View {
    let onAddTransaction: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Transactions")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add transactions manually or connect your bank account")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: onAddTransaction) {
                Label("Add Transaction", systemImage: "plus.circle.fill")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
        .padding()
    }
}

struct AddTransactionView: View {
    var body: some View {
        Text("Add Transaction View - Coming soon")
    }
}
