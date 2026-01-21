import SwiftUI
import SwiftData

@main
struct BucketPilotApp: App {
    let modelContainer: ModelContainer
    
    init() {
        do {
            let schema = Schema([
                Bucket.self,
                Transaction.self,
                TransactionSplit.self,
                AllocationEvent.self,
                FundingRule.self,
                MerchantMappingRule.self,
                SyncState.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not initialize ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
    }
}
