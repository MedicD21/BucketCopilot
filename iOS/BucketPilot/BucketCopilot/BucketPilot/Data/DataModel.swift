import Foundation
import SwiftData

let dataModel: ModelContainer = {
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
    
    do {
        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()
