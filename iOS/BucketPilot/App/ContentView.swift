import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            BucketsListView()
                .tabItem {
                    Label("Buckets", systemImage: "folder.fill")
                }
                .tag(1)
            
            TransactionsListView()
                .tabItem {
                    Label("Transactions", systemImage: "list.bullet")
                }
                .tag(2)
            
            RulesListView()
                .tabItem {
                    Label("Rules", systemImage: "gearshape.2.fill")
                }
                .tag(3)
            
            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.fill")
                }
                .tag(4)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(5)
        }
        .preferredColorScheme(.dark) // Force dark mode
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Bucket.self, Transaction.self])
}
