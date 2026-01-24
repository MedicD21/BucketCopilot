import Foundation
import SwiftData

/// Service for calculating bucket ledger state (assigned, activity, available)
class BucketLedgerService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Calculate total assigned to a bucket
    func calculateAssigned(bucket: Bucket) throws -> Decimal {
        let bucketId: UUID? = bucket.id
        let descriptor = FetchDescriptor<AllocationEvent>(
            predicate: #Predicate<AllocationEvent> { event in
                event.bucket?.id == bucketId
            }
        )
        let events = try modelContext.fetch(descriptor)
        return events.reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    /// Calculate total activity for a bucket (transaction splits)
    func calculateActivity(bucket: Bucket) throws -> Decimal {
        let bucketId: UUID? = bucket.id
        let descriptor = FetchDescriptor<TransactionSplit>(
            predicate: #Predicate<TransactionSplit> { split in
                split.bucket?.id == bucketId
            }
        )
        let splits = try modelContext.fetch(descriptor)
        return splits.reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    /// Calculate available balance for a bucket
    func calculateAvailable(bucket: Bucket) throws -> Decimal {
        let assigned = try calculateAssigned(bucket: bucket)
        let activity = try calculateActivity(bucket: bucket)
        return assigned + activity
    }
    
    /// Calculate unassigned pool balance
    func calculateUnassignedBalance() throws -> Decimal {
        // Get all positive transactions (income)
        let incomeDescriptor = FetchDescriptor<Transaction>(
            predicate: #Predicate { $0.amount > 0 }
        )
        let incomeTransactions = try modelContext.fetch(incomeDescriptor)
        let totalIncome = incomeTransactions
            .filter { !$0.isTransferLike }
            .reduce(Decimal.zero) { $0 + $1.amount }
        
        // Get all allocations TO buckets
        let allocationDescriptor = FetchDescriptor<AllocationEvent>(
            predicate: #Predicate { $0.bucket != nil && $0.amount > 0 }
        )
        let allocations = try modelContext.fetch(allocationDescriptor)
        let totalAllocated = allocations.reduce(Decimal.zero) { $0 + $1.amount }
        
        // Unassigned = Income - Allocations
        return totalIncome - totalAllocated
    }
    
    /// Get bucket state summary
    func getBucketState(bucket: Bucket) throws -> BucketState {
        let assigned = try calculateAssigned(bucket: bucket)
        let activity = try calculateActivity(bucket: bucket)
        let available = assigned + activity
        
        return BucketState(
            bucket: bucket,
            assigned: assigned,
            activity: activity,
            available: available
        )
    }
}

struct BucketState {
    let bucket: Bucket
    let assigned: Decimal
    let activity: Decimal
    let available: Decimal
    
    var isOverspent: Bool {
        available < 0 && !bucket.allowNegative
    }
    
    var progressToTarget: Double? {
        guard let target = bucket.targetAmount, target > 0 else {
            return nil
        }
        return Double(truncating: (available / target) as NSDecimalNumber)
    }
}
