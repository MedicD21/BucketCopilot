import SwiftUI
import SwiftData

struct InsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingAICopilot = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // AI Copilot Section
                    AICopilotSection(onOpenCopilot: { showingAICopilot = true })
                    
                    // Monthly Spend Chart
                    MonthlySpendSection()
                    
                    // Income vs Expenses
                    IncomeExpensesSection()
                    
                    // Subscription Detection
                    SubscriptionsSection()
                }
                .padding()
            }
            .navigationTitle("Insights")
            .sheet(isPresented: $showingAICopilot) {
                AICopilotView()
            }
        }
    }
}

struct AICopilotSection: View {
    let onOpenCopilot: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI Copilot")
                .font(.headline)
            
            Text("Get budget insights and suggestions powered by AI")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: onOpenCopilot) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Open Copilot")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }
}

struct MonthlySpendSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Spend by Bucket")
                .font(.headline)
            
            Text("Chart coming soon")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

struct IncomeExpensesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Income vs Expenses")
                .font(.headline)
            
            Text("Summary coming soon")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

struct SubscriptionsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscriptions")
                .font(.headline)
            
            Text("Recurring merchant detection coming soon")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

struct AICopilotView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("AI Copilot - Coming soon")
                    .foregroundColor(.secondary)
            }
            .navigationTitle("AI Copilot")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
