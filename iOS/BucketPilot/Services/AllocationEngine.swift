import Foundation
import SwiftData

/// Deterministic auto-funding rules engine
/// NOT AI-based - executes rules in priority order with fixed logic
class AllocationEngine {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Main Execution
    
    /// Execute all enabled rules that match the given trigger
    /// Returns proposed allocations (does not apply them)
    func previewRuleExecution(
        trigger: RuleTrigger,
        availableFunds: Decimal
    ) throws -> [ProposedAllocation] {
        let rules = try fetchEnabledRules(for: trigger)
        let sortedRules = rules.sorted { $0.priority < $1.priority }
        
        var proposals: [ProposedAllocation] = []
        var remainingFunds = availableFunds
        
        for rule in sortedRules {
            guard evaluateConditions(rule.conditions, for: trigger) else {
                continue
            }
            
            let ruleProposals = try executeRuleActions(
                rule: rule,
                availableFunds: remainingFunds,
                trigger: trigger
            )
            
            // Calculate how much this rule would consume
            let ruleAmount = ruleProposals.reduce(Decimal.zero) { $0 + abs($1.amount) }
            remainingFunds -= ruleAmount
            
            proposals.append(contentsOf: ruleProposals)
        }
        
        return proposals
    }
    
    /// Execute rules and create AllocationEvents (applies changes)
    func executeRules(
        trigger: RuleTrigger,
        availableFunds: Decimal
    ) throws -> [AllocationEvent] {
        let proposals = try previewRuleExecution(trigger: trigger, availableFunds: availableFunds)
        let events = try applyProposals(proposals, trigger: trigger)
        return events
    }
    
    // MARK: - Rule Evaluation
    
    private func fetchEnabledRules(for trigger: RuleTrigger) throws -> [FundingRule] {
        let descriptor = FetchDescriptor<FundingRule>(
            predicate: #Predicate { $0.enabled == true }
        )
        let allRules = try modelContext.fetch(descriptor)
        
        return allRules.filter { ruleMatchesTrigger($0, trigger: trigger) }
    }
    
    private func ruleMatchesTrigger(_ rule: FundingRule, trigger: RuleTrigger) -> Bool {
        switch (rule.triggerTypeEnum, trigger) {
        case (.onIncomeDetected, .incomeDetected):
            return true
        case (.scheduledDaily, .scheduledDaily):
            return true
        case (.scheduledWeekly, .scheduledWeekly):
            return true
        case (.scheduledMonthly, .scheduledMonthly):
            return true
        case (.manualRun, .manual):
            return true
        case (.balanceThreshold, .balanceThreshold):
            return true
        default:
            return false
        }
    }
    
    private func evaluateConditions(_ conditions: RuleConditions, for trigger: RuleTrigger) -> Bool {
        // Account filter
        if let accountId = conditions.accountId,
           case .incomeDetected(let transaction) = trigger,
           transaction.accountId != accountId {
            return false
        }
        
        // Amount filter
        if let minAmount = conditions.minAmount,
           case .incomeDetected(let transaction) = trigger,
           abs(transaction.amount) < minAmount {
            return false
        }
        
        // Merchant filter
        if let merchantContains = conditions.merchantContains,
           case .incomeDetected(let transaction) = trigger,
           let merchantName = transaction.merchantName?.lowercased(),
           !merchantName.contains(merchantContains.lowercased()) {
            return false
        }
        
        // Day of month filter
        if let dayOfMonth = conditions.dayOfMonth {
            let calendar = Calendar.current
            let today = Date()
            if calendar.component(.day, from: today) != dayOfMonth {
                return false
            }
        }
        
        // Weekday filter
        if let weekday = conditions.weekday {
            let calendar = Calendar.current
            let today = Date()
            // Swift: 1=Sunday, 2=Monday, etc.
            if calendar.component(.weekday, from: today) != weekday {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Action Execution
    
    private func executeRuleActions(
        rule: FundingRule,
        availableFunds: Decimal,
        trigger: RuleTrigger
    ) throws -> [ProposedAllocation] {
        var proposals: [ProposedAllocation] = []
        var remaining = availableFunds
        
        for action in rule.actions {
            switch action {
            case .allocateFixed(let bucketId, let amount):
                guard let bucket = try fetchBucket(id: bucketId) else {
                    continue
                }
                let allocationAmount = min(amount, remaining)
                if allocationAmount > 0 {
                    proposals.append(ProposedAllocation(
                        bucketId: bucketId,
                        bucketName: bucket.name,
                        amount: allocationAmount,
                        ruleId: rule.id,
                        ruleName: rule.name
                    ))
                    remaining -= allocationAmount
                }
                
            case .allocatePercent(let bucketId, let percent):
                guard let bucket = try fetchBucket(id: bucketId) else {
                    continue
                }
                let amount = remaining * Decimal(percent / 100.0)
                if amount > 0 {
                    proposals.append(ProposedAllocation(
                        bucketId: bucketId,
                        bucketName: bucket.name,
                        amount: amount,
                        ruleId: rule.id,
                        ruleName: rule.name
                    ))
                    remaining -= amount
                }
                
            case .fillToTarget(let bucketId):
                guard let bucket = try fetchBucket(id: bucketId) else {
                    continue
                }
                guard let targetAmount = bucket.targetAmount else {
                    continue
                }
                
                // Calculate current assigned + activity
                let currentAssigned = try calculateAssigned(bucketId: bucketId)
                let currentActivity = try calculateActivity(bucketId: bucketId)
                let currentAvailable = currentAssigned + currentActivity
                
                let needed = targetAmount - currentAvailable
                let allocationAmount = min(max(needed, 0), remaining)
                
                if allocationAmount > 0 {
                    proposals.append(ProposedAllocation(
                        bucketId: bucketId,
                        bucketName: bucket.name,
                        amount: allocationAmount,
                        ruleId: rule.id,
                        ruleName: rule.name
                    ))
                    remaining -= allocationAmount
                }
            }
        }
        
        return proposals
    }
    
    // MARK: - Helper Methods
    
    private func fetchBucket(id: UUID) throws -> Bucket? {
        let descriptor = FetchDescriptor<Bucket>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    private func calculateAssigned(bucketId: UUID) throws -> Decimal {
        let descriptor = FetchDescriptor<AllocationEvent>(
            predicate: #Predicate<AllocationEvent> { event in
                event.bucket?.id == bucketId && event.amount > 0
            }
        )
        let events = try modelContext.fetch(descriptor)
        return events.reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    private func calculateActivity(bucketId: UUID) throws -> Decimal {
        let descriptor = FetchDescriptor<TransactionSplit>(
            predicate: #Predicate<TransactionSplit> { split in
                split.bucket?.id == bucketId
            }
        )
        let splits = try modelContext.fetch(descriptor)
        return splits.reduce(Decimal.zero) { $0 + $1.amount }
    }
    
    private func applyProposals(_ proposals: [ProposedAllocation], trigger: RuleTrigger) throws -> [AllocationEvent] {
        let events = proposals.map { proposal in
            let bucket = try? fetchBucket(id: proposal.bucketId)
            return AllocationEvent(
                bucket: bucket,
                amount: proposal.amount,
                sourceType: .rule,
                sourceId: proposal.ruleId.uuidString,
                timestamp: Date(),
                sequence: Int64(Date().timeIntervalSince1970 * 1000) // Simple sequence
            )
        }
        
        for event in events {
            modelContext.insert(event)
        }
        
        try modelContext.save()
        return events
    }
}

// MARK: - Supporting Types

enum RuleTrigger {
    case incomeDetected(Transaction)
    case scheduledDaily
    case scheduledWeekly
    case scheduledMonthly
    case manual
    case balanceThreshold(Decimal)
}

struct ProposedAllocation {
    let bucketId: UUID
    let bucketName: String
    let amount: Decimal
    let ruleId: UUID
    let ruleName: String
}
