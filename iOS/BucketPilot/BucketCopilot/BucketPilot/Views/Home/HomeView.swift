import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var buckets: [Bucket]
    @State private var unassignedBalance: Decimal = 0
    @State private var bucketStates: [BucketState] = []
    @State private var showingAllocationSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Unassigned Balance Card
                    UnassignedBalanceCard(balance: unassignedBalance)
                    
                    // Top Buckets
                    TopBucketsSection(bucketStates: bucketStates)
                    
                    // Overspent Buckets
                    OverspentBucketsSection(bucketStates: bucketStates)
                    
                    // Quick Actions
                    QuickActionsSection(
                        onAllocateFunds: { showingAllocationSheet = true },
                        onRunRules: { runRules() }
                    )
                }
                .padding()
            }
            .navigationTitle("BucketPilot")
            .onAppear {
                refreshState()
            }
            .sheet(isPresented: $showingAllocationSheet) {
                // Allocation sheet
                Text("Allocation UI - Coming soon")
            }
        }
    }
    
    private func refreshState() {
        let ledgerService = BucketLedgerService(modelContext: modelContext)
        
        Task {
            do {
                unassignedBalance = try ledgerService.calculateUnassignedBalance()
                
                let states = try buckets.map { bucket in
                    try ledgerService.getBucketState(bucket: bucket)
                }
                
                await MainActor.run {
                    bucketStates = states.sorted { $0.available > $1.available }
                }
            } catch {
                print("Error refreshing state: \(error)")
            }
        }
    }
    
    private func runRules() {
        // TODO: Implement rule execution
        print("Running rules...")
    }
}

// MARK: - Subviews

struct UnassignedBalanceCard: View {
    let balance: Decimal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available to Budget")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(NumberFormatter.currency.string(from: balance as NSDecimalNumber) ?? "$0.00")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct TopBucketsSection: View {
    let bucketStates: [BucketState]
    
    var topBuckets: [BucketState] {
        bucketStates.prefix(5).sorted { $0.available > $1.available }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Buckets")
                .font(.headline)
            
            if topBuckets.isEmpty {
                Text("No buckets yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(topBuckets, id: \.bucket.id) { state in
                    BucketSummaryRow(state: state)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OverspentBucketsSection: View {
    let bucketStates: [BucketState]
    
    var overspentBuckets: [BucketState] {
        bucketStates.filter { $0.isOverspent }
    }
    
    var body: some View {
        if !overspentBuckets.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Overspent")
                    .font(.headline)
                    .foregroundColor(.red)
                
                ForEach(overspentBuckets, id: \.bucket.id) { state in
                    BucketSummaryRow(state: state)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct BucketSummaryRow: View {
    let state: BucketState
    
    var body: some View {
        HStack {
            Image(systemName: state.bucket.icon)
                .foregroundColor(Color(hex: state.bucket.color))
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(state.bucket.name)
                    .font(.subheadline)
                
                Text(NumberFormatter.currency.string(from: state.available as NSDecimalNumber) ?? "$0.00")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct QuickActionsSection: View {
    let onAllocateFunds: () -> Void
    let onRunRules: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Button(action: onAllocateFunds) {
                Label("Allocate Funds", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            
            Button(action: onRunRules) {
                Label("Run Rules", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
            }
        }
    }
}

// MARK: - Helpers

extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 255) // Default to red on error
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
