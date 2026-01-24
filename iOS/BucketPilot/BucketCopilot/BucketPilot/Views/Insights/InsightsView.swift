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
    @Environment(\.modelContext) private var modelContext
    @State private var command = ""
    @State private var isLoading = false
    @State private var response: AICommandResponse?
    @State private var errorMessage: String?
    @State private var actionStates: [String: ActionStatus] = [:]
    
    private let aiService = AIService()
    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    GroupBox("Ask Copilot") {
                        VStack(alignment: .leading, spacing: 10) {
                            ZStack(alignment: .topLeading) {
                                if command.isEmpty {
                                    Text("e.g. Move $50 from Dining Out to Groceries")
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 8)
                                }
                                TextEditor(text: $command)
                                    .frame(minHeight: 110)
                                    .padding(4)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                            
                            Button(action: sendCommand) {
                                HStack {
                                    Image(systemName: "sparkles")
                                    Text(isLoading ? "Thinking..." : "Send to Copilot")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(isLoading ? Color(.systemGray4) : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isLoading || command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.top, 4)
                    }
                    
                    if isLoading {
                        ProgressView()
                    }
                    
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if let response = response {
                        GroupBox("Summary") {
                            Text(response.summary)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        if let warnings = response.warnings, !warnings.isEmpty {
                            GroupBox("Warnings") {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(warnings, id: \.self) { warning in
                                        Text("• \(warning)")
                                            .foregroundColor(.orange)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        GroupBox("Actions") {
                            if response.actions.isEmpty {
                                Text("No actions returned.")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(response.actions) { action in
                                        actionRow(action)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("AI Copilot")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func sendCommand() {
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        response = nil
        actionStates = [:]
        
        Task {
            do {
                let context = try buildContext()
                let response = try await aiService.sendCommand(command, context: context)
                await MainActor.run {
                    self.response = response
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    @ViewBuilder
    private func actionRow(_ action: AIAction) -> some View {
        let status = actionStates[action.id] ?? .idle
        
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(actionTitle(for: action))
                        .font(.headline)
                    Text(actionSubtitle(for: action))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { execute(action: action) }) {
                    Text(status.buttonTitle)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(status.buttonBackground)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(status.isDisabled)
            }
            
            if case .failed(let message) = status {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            let details = actionDetailLines(for: action)
            if !details.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(details, id: \.self) { line in
                        Text(line)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func buildContext() throws -> AIContext {
        let ledger = BucketLedgerService(modelContext: modelContext)
        let unassigned = try ledger.calculateUnassignedBalance()
        
        let bucketDescriptor = FetchDescriptor<Bucket>()
        let buckets = try modelContext.fetch(bucketDescriptor)
        let bucketContexts = buckets.map { bucket in
            let state = try? ledger.getBucketState(bucket: bucket)
            let available = state?.available ?? 0
            return AIContextBucket(
                id: bucket.id.uuidString,
                name: bucket.name,
                available: Double(truncating: available as NSDecimalNumber)
            )
        }
        
        var transactionDescriptor = FetchDescriptor<Transaction>(
            sortBy: [SortDescriptor(\Transaction.date, order: .reverse)]
        )
        transactionDescriptor.fetchLimit = 10
        let transactions = try modelContext.fetch(transactionDescriptor)
        let transactionContexts = transactions.map { transaction in
            AIContextTransaction(
                id: transaction.id.uuidString,
                merchantName: transaction.merchantName ?? transaction.details ?? "Unknown",
                amount: Double(truncating: transaction.amount as NSDecimalNumber),
                date: Self.dateFormatter.string(from: transaction.date)
            )
        }
        
        return AIContext(
            unassignedBalance: Double(truncating: unassigned as NSDecimalNumber),
            buckets: bucketContexts,
            recentTransactions: transactionContexts
        )
    }
}

private enum ActionStatus: Equatable {
    case idle
    case running
    case success
    case failed(String)
    
    var buttonTitle: String {
        switch self {
        case .idle:
            return "Execute"
        case .running:
            return "Running"
        case .success:
            return "Done"
        case .failed:
            return "Retry"
        }
    }
    
    var buttonBackground: Color {
        switch self {
        case .success:
            return .green
        case .failed:
            return .orange
        default:
            return .blue
        }
    }
    
    var isDisabled: Bool {
        switch self {
        case .running, .success:
            return true
        case .idle, .failed:
            return false
        }
    }
}

private extension AICopilotView {
    func execute(action: AIAction) {
        actionStates[action.id] = .running
        Task {
            do {
                try await MainActor.run {
                    try apply(action: action)
                }
                await MainActor.run {
                    actionStates[action.id] = .success
                }
            } catch {
                await MainActor.run {
                    actionStates[action.id] = .failed(error.localizedDescription)
                }
            }
        }
    }
    
    func apply(action: AIAction) throws {
        let type = normalizedType(action.type)
        switch type {
        case "create_bucket":
            try applyCreateBucket(action)
        case "update_bucket":
            try applyUpdateBucket(action)
        case "delete_bucket":
            try applyDeleteBucket(action)
        case "allocate":
            try applyAllocate(action)
        case "move":
            try applyMove(action)
        case "create_rule":
            try applyCreateRule(action)
        case "update_rule":
            try applyUpdateRule(action)
        case "create_merchant_mapping":
            try applyCreateMerchantMapping(action)
        default:
            throw AIActionError.unsupportedAction(type: type)
        }
    }
    
    func applyCreateBucket(_ action: AIAction) throws {
        guard let name = stringValue(
            action,
            keys: ["name", "bucketName", "bucket_name", "budgetName", "budget_name"]
        ) else {
            throw AIActionError.missingField("name")
        }
        let icon = stringValue(action, keys: ["icon"]) ?? "folder.fill"
        let color = stringValue(action, keys: ["color"]) ?? "#007AFF"
        let targetTypeRaw = stringValue(action, keys: ["targetType", "target_type"]) ?? TargetType.none.rawValue
        let targetType = TargetType(rawValue: targetTypeRaw) ?? .none
        let targetAmount = doubleValue(
            action,
            keys: ["targetAmount", "target_amount", "budgetAmount", "budget_amount"]
        ).map { Decimal($0) }
        let priority = intValue(action, keys: ["priority"]) ?? 5
        
        let bucket = Bucket(
            name: name,
            icon: icon,
            color: color,
            targetType: targetType,
            targetAmount: targetAmount,
            priority: priority
        )
        modelContext.insert(bucket)
        try modelContext.save()
    }
    
    func applyUpdateBucket(_ action: AIAction) throws {
        let bucketId = stringValue(action, keys: ["bucketId", "bucket_id"])
        let updatesObject = objectValue(action, keys: ["updates"])
        let nameHint = stringValue(
            updatesObject,
            keys: ["name", "bucketName", "bucket_name", "budgetName", "budget_name"]
        ) ?? stringValue(action, keys: ["name", "bucketName", "bucket_name", "budgetName", "budget_name"])
        
        let bucket = bucketId
            .flatMap { try? fetchBucket(idString: $0) }
            ?? nameHint.flatMap { try? fetchBucketByName($0) }
        
        guard let bucket = bucket else {
            throw AIActionError.missingField("bucketId/name")
        }
        let updates = updatesObject ?? action.raw
        
        if let name = stringValue(updates, keys: ["name"]) {
            bucket.name = name
        }
        if let icon = stringValue(updates, keys: ["icon"]) {
            bucket.icon = icon
        }
        if let color = stringValue(updates, keys: ["color"]) {
            bucket.color = color
        }
        if let targetTypeRaw = stringValue(updates, keys: ["targetType", "target_type", "budgetType", "budget_type"]) {
            bucket.targetType = normalizeTargetType(targetTypeRaw)
        }
        if let targetAmount = doubleValue(updates, keys: ["targetAmount", "target_amount", "budgetAmount", "budget_amount"]) {
            bucket.targetAmount = Decimal(targetAmount)
        }
        if let priority = intValue(updates, keys: ["priority"]) {
            bucket.priority = priority
        }
        if let allowNegative = boolValue(updates, keys: ["allowNegative", "allow_negative"]) {
            bucket.allowNegative = allowNegative
        }
        bucket.updatedAt = Date()
        try modelContext.save()
    }
    
    func applyDeleteBucket(_ action: AIAction) throws {
        guard let bucketId = stringValue(action, keys: ["bucketId", "bucket_id"]),
              let bucket = try fetchBucket(idString: bucketId) else {
            throw AIActionError.missingField("bucketId")
        }
        modelContext.delete(bucket)
        try modelContext.save()
    }
    
    func applyAllocate(_ action: AIAction) throws {
        guard let bucketId = stringValue(action, keys: ["bucketId", "bucket_id"]),
              let bucket = try fetchBucket(idString: bucketId) else {
            throw AIActionError.missingField("bucketId")
        }
        guard let amountValue = doubleValue(action, keys: ["amount"]) else {
            throw AIActionError.missingField("amount")
        }
        let amount = Decimal(amountValue)
        
        if let source = objectValue(action, keys: ["source"]),
           let sourceBucketId = stringValue(source, keys: ["bucketId", "bucket_id"]),
           let sourceBucket = try fetchBucket(idString: sourceBucketId) {
            let fromEvent = AllocationEvent(bucket: sourceBucket, amount: -amount, sourceType: .manual, sourceId: "ai")
            modelContext.insert(fromEvent)
        }
        
        let toEvent = AllocationEvent(bucket: bucket, amount: amount, sourceType: .manual, sourceId: "ai")
        modelContext.insert(toEvent)
        try modelContext.save()
    }
    
    func applyMove(_ action: AIAction) throws {
        guard let fromId = stringValue(action, keys: ["fromBucketId", "from_bucket_id"]),
              let toId = stringValue(action, keys: ["toBucketId", "to_bucket_id"]),
              let amountValue = doubleValue(action, keys: ["amount"]),
              let fromBucket = try fetchBucket(idString: fromId),
              let toBucket = try fetchBucket(idString: toId) else {
            throw AIActionError.missingField("fromBucketId/toBucketId/amount")
        }
        let amount = Decimal(amountValue)
        let fromEvent = AllocationEvent(bucket: fromBucket, amount: -amount, sourceType: .manual, sourceId: "ai")
        let toEvent = AllocationEvent(bucket: toBucket, amount: amount, sourceType: .manual, sourceId: "ai")
        modelContext.insert(fromEvent)
        modelContext.insert(toEvent)
        try modelContext.save()
    }
    
    func applyCreateRule(_ action: AIAction) throws {
        guard let name = stringValue(action, keys: ["name"]) else {
            throw AIActionError.missingField("name")
        }
        let triggerRaw = stringValue(action, keys: ["triggerType", "trigger_type"]) ?? TriggerType.manualRun.rawValue
        let trigger = TriggerType(rawValue: triggerRaw) ?? .manualRun
        let priority = intValue(action, keys: ["priority"]) ?? 5
        
        let conditionsValue = objectValue(action, keys: ["conditions"])
        let conditions = RuleConditions(
            accountId: stringValue(conditionsValue, keys: ["accountId", "account_id"]),
            minAmount: doubleValue(conditionsValue, keys: ["minAmount", "min_amount"]).map { Decimal($0) },
            merchantContains: stringValue(conditionsValue, keys: ["merchantContains", "merchant_contains"]),
            dayOfMonth: intValue(conditionsValue, keys: ["dayOfMonth", "day_of_month"]),
            weekday: intValue(conditionsValue, keys: ["weekday"])
        )
        
        let actionsArray = arrayValue(action, keys: ["actions"]) ?? []
        let ruleActions = actionsArray.compactMap { value -> RuleAction? in
            guard case .object(let object) = value else { return nil }
            return parseRuleAction(object)
        }
        
        let rule = FundingRule(
            name: name,
            priority: priority,
            triggerType: trigger,
            conditions: conditions,
            actions: ruleActions
        )
        modelContext.insert(rule)
        try modelContext.save()
    }
    
    func applyUpdateRule(_ action: AIAction) throws {
        guard let ruleId = stringValue(action, keys: ["ruleId", "rule_id"]),
              let ruleUUID = UUID(uuidString: ruleId) else {
            throw AIActionError.missingField("ruleId")
        }
        
        let descriptor = FetchDescriptor<FundingRule>(
            predicate: #Predicate { $0.id == ruleUUID }
        )
        guard let rule = try modelContext.fetch(descriptor).first else {
            throw AIActionError.notFound("rule")
        }
        
        guard let updates = objectValue(action, keys: ["updates"]) else {
            throw AIActionError.missingField("updates")
        }
        
        if let enabled = boolValue(updates, keys: ["enabled"]) {
            rule.enabled = enabled
        }
        if let priority = intValue(updates, keys: ["priority"]) {
            rule.priority = priority
        }
        if let triggerRaw = stringValue(updates, keys: ["triggerType", "trigger_type"]) {
            rule.triggerType = triggerRaw
        }
        if let conditionsValue = objectValue(updates, keys: ["conditions"]) {
            rule.conditions = RuleConditions(
                accountId: stringValue(conditionsValue, keys: ["accountId", "account_id"]),
                minAmount: doubleValue(conditionsValue, keys: ["minAmount", "min_amount"]).map { Decimal($0) },
                merchantContains: stringValue(conditionsValue, keys: ["merchantContains", "merchant_contains"]),
                dayOfMonth: intValue(conditionsValue, keys: ["dayOfMonth", "day_of_month"]),
                weekday: intValue(conditionsValue, keys: ["weekday"])
            )
        }
        if let actionsArray = arrayValue(updates, keys: ["actions"]) {
            let ruleActions = actionsArray.compactMap { value -> RuleAction? in
                guard case .object(let object) = value else { return nil }
                return parseRuleAction(object)
            }
            rule.actions = ruleActions
        }
        rule.updatedAt = Date()
        try modelContext.save()
    }
    
    func applyCreateMerchantMapping(_ action: AIAction) throws {
        guard let merchantContains = stringValue(action, keys: ["merchantContains", "merchant_contains"]),
              let bucketId = stringValue(action, keys: ["bucketId", "bucket_id"]),
              let bucket = try fetchBucket(idString: bucketId) else {
            throw AIActionError.missingField("merchantContains/bucketId")
        }
        let priority = intValue(action, keys: ["priority"]) ?? 5
        let mapping = MerchantMappingRule(
            merchantContains: merchantContains,
            bucket: bucket,
            priority: priority
        )
        modelContext.insert(mapping)
        try modelContext.save()
    }
    
    func parseRuleAction(_ object: [String: AIJSONValue]) -> RuleAction? {
        let type = stringValue(object, keys: ["type"]) ?? ""
        guard let bucketIdString = stringValue(object, keys: ["bucketId", "bucket_id"]),
              let bucketId = UUID(uuidString: bucketIdString) else {
            return nil
        }
        switch type {
        case "allocateFixed":
            guard let amount = doubleValue(object, keys: ["amount"]) else { return nil }
            return .allocateFixed(bucketId: bucketId, amount: Decimal(amount))
        case "allocatePercent":
            guard let percent = doubleValue(object, keys: ["percent"]) else { return nil }
            return .allocatePercent(bucketId: bucketId, percent: percent)
        case "fillToTarget":
            return .fillToTarget(bucketId: bucketId)
        default:
            return nil
        }
    }
    
    func actionTitle(for action: AIAction) -> String {
        let type = normalizedType(action.type)
        switch type {
        case "create_bucket":
            return "Create bucket"
        case "update_bucket":
            return "Update bucket"
        case "delete_bucket":
            return "Delete bucket"
        case "allocate":
            return "Allocate funds"
        case "move":
            return "Move funds"
        case "create_rule":
            return "Create rule"
        case "update_rule":
            return "Update rule"
        case "create_merchant_mapping":
            return "Create merchant mapping"
        default:
            return displayActionType(action.type)
        }
    }
    
    func actionSubtitle(for action: AIAction) -> String {
        let type = normalizedType(action.type)
        switch type {
        case "create_bucket":
            let name = stringValue(action, keys: ["name"]) ?? "New Bucket"
            let amount = doubleValue(action, keys: ["targetAmount", "target_amount"])
            if let amount = amount {
                return "\(name) • \(formatCurrency(Decimal(amount)))"
            }
            return name
        case "update_bucket":
            if let bucketId = stringValue(action, keys: ["bucketId", "bucket_id"]),
               let bucket = try? fetchBucket(idString: bucketId) {
                return bucket.name
            }
            return "Bucket update"
        case "delete_bucket":
            if let bucketId = stringValue(action, keys: ["bucketId", "bucket_id"]),
               let bucket = try? fetchBucket(idString: bucketId) {
                return bucket.name
            }
            return "Bucket deletion"
        case "allocate":
            let amount = doubleValue(action, keys: ["amount"]) ?? 0
            let bucketLabel = bucketName(for: stringValue(action, keys: ["bucketId", "bucket_id"])) ?? "Bucket"
            if let source = objectValue(action, keys: ["source"]),
               let sourceBucketName = bucketName(for: stringValue(source, keys: ["bucketId", "bucket_id"])) {
                return "\(formatCurrency(Decimal(amount))) from \(sourceBucketName) to \(bucketLabel)"
            }
            return "\(formatCurrency(Decimal(amount))) to \(bucketLabel)"
        case "move":
            let amount = doubleValue(action, keys: ["amount"]) ?? 0
            let fromLabel = bucketName(for: stringValue(action, keys: ["fromBucketId", "from_bucket_id"])) ?? "Bucket"
            let toLabel = bucketName(for: stringValue(action, keys: ["toBucketId", "to_bucket_id"])) ?? "Bucket"
            return "\(formatCurrency(Decimal(amount))) from \(fromLabel) to \(toLabel)"
        case "create_rule":
            return stringValue(action, keys: ["name"]) ?? "New rule"
        case "update_rule":
            return "Rule update"
        case "create_merchant_mapping":
            let merchant = stringValue(action, keys: ["merchantContains", "merchant_contains"]) ?? "Merchant"
            let bucketLabel = bucketName(for: stringValue(action, keys: ["bucketId", "bucket_id"])) ?? "Bucket"
            return "\(merchant) → \(bucketLabel)"
        default:
            let keyCount = action.raw.keys.count
            return keyCount == 0 ? "Action details" : "\(keyCount) fields"
        }
    }

    func actionDetailLines(for action: AIAction) -> [String] {
        let type = normalizedType(action.type)
        switch type {
        case "create_bucket":
            let name = stringValue(action, keys: ["name", "bucketName", "bucket_name", "budgetName", "budget_name"])
            let amount = doubleValue(action, keys: ["targetAmount", "target_amount", "budgetAmount", "budget_amount"])
            let targetType = stringValue(action, keys: ["targetType", "target_type"])
            return [
                name.map { "Name: \($0)" },
                amount.map { "Target: \(formatCurrency(Decimal($0)))" },
                targetType.map { "Type: \($0)" }
            ].compactMap { $0 }
        case "update_bucket":
            let updates = objectValue(action, keys: ["updates"])
            let name = stringValue(updates, keys: ["name", "bucketName", "bucket_name"])
            let amount = doubleValue(updates, keys: ["targetAmount", "target_amount"])
            let targetType = stringValue(updates, keys: ["targetType", "target_type"])
            return [
                name.map { "Name: \($0)" },
                amount.map { "Target: \(formatCurrency(Decimal($0)))" },
                targetType.map { "Type: \($0)" }
            ].compactMap { $0 }
        case "allocate":
            let amount = doubleValue(action, keys: ["amount"]).map { formatCurrency(Decimal($0)) }
            let bucket = bucketName(for: stringValue(action, keys: ["bucketId", "bucket_id"]))
            let source = objectValue(action, keys: ["source"])
            let sourceBucket = bucketName(for: stringValue(source, keys: ["bucketId", "bucket_id"]))
            return [
                amount.map { "Amount: \($0)" },
                bucket.map { "To: \($0)" },
                sourceBucket.map { "From: \($0)" }
            ].compactMap { $0 }
        case "move":
            let amount = doubleValue(action, keys: ["amount"]).map { formatCurrency(Decimal($0)) }
            let fromName = bucketName(for: stringValue(action, keys: ["fromBucketId", "from_bucket_id"]))
            let toName = bucketName(for: stringValue(action, keys: ["toBucketId", "to_bucket_id"]))
            return [
                amount.map { "Amount: \($0)" },
                fromName.map { "From: \($0)" },
                toName.map { "To: \($0)" }
            ].compactMap { $0 }
        case "create_rule":
            let name = stringValue(action, keys: ["name"])
            let trigger = stringValue(action, keys: ["triggerType", "trigger_type"])
            return [
                name.map { "Name: \($0)" },
                trigger.map { "Trigger: \($0)" }
            ].compactMap { $0 }
        case "update_rule":
            let ruleId = stringValue(action, keys: ["ruleId", "rule_id"])
            return ruleId.map { ["Rule ID: \($0)"] } ?? []
        case "create_merchant_mapping":
            let merchant = stringValue(action, keys: ["merchantContains", "merchant_contains"])
            let bucket = bucketName(for: stringValue(action, keys: ["bucketId", "bucket_id"]))
            return [
                merchant.map { "Merchant: \($0)" },
                bucket.map { "Bucket: \($0)" }
            ].compactMap { $0 }
        default:
            let pairs = action.raw
                .sorted { $0.key < $1.key }
                .prefix(4)
                .map { key, value in
                    "• \(key): \(value.stringValue ?? String(describing: value))"
                }
            return pairs
        }
    }
    
    func bucketName(for idString: String?) -> String? {
        guard let idString = idString,
              let bucket = try? fetchBucket(idString: idString) else {
            return nil
        }
        return bucket.name
    }
    
    func fetchBucket(idString: String) throws -> Bucket? {
        guard let uuid = UUID(uuidString: idString) else {
            return nil
        }
        let descriptor = FetchDescriptor<Bucket>(
            predicate: #Predicate { $0.id == uuid }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchBucketByName(_ name: String) throws -> Bucket? {
        let descriptor = FetchDescriptor<Bucket>(
            predicate: #Predicate { $0.name == name }
        )
        return try modelContext.fetch(descriptor).first
    }
    
    func stringValue(_ action: AIAction, keys: [String]) -> String? {
        return stringValue(action.raw, keys: keys)
    }
    
    func doubleValue(_ action: AIAction, keys: [String]) -> Double? {
        return doubleValue(action.raw, keys: keys)
    }
    
    func intValue(_ action: AIAction, keys: [String]) -> Int? {
        if let value = doubleValue(action, keys: keys) {
            return Int(value)
        }
        return nil
    }
    
    func boolValue(_ action: AIAction, keys: [String]) -> Bool? {
        return boolValue(action.raw, keys: keys)
    }
    
    func objectValue(_ action: AIAction, keys: [String]) -> [String: AIJSONValue]? {
        return objectValue(action.raw, keys: keys)
    }
    
    func arrayValue(_ action: AIAction, keys: [String]) -> [AIJSONValue]? {
        return arrayValue(action.raw, keys: keys)
    }
    
    func stringValue(_ object: [String: AIJSONValue]?, keys: [String]) -> String? {
        guard let object = object else { return nil }
        for key in keys {
            if let value = object[key]?.stringValue {
                return value
            }
        }
        return nil
    }
    
    func doubleValue(_ object: [String: AIJSONValue]?, keys: [String]) -> Double? {
        guard let object = object else { return nil }
        for key in keys {
            if case .number(let value)? = object[key] {
                return value
            }
            if let stringValue = object[key]?.stringValue, let doubleValue = Double(stringValue) {
                return doubleValue
            }
        }
        return nil
    }
    
    func intValue(_ object: [String: AIJSONValue]?, keys: [String]) -> Int? {
        if let value = doubleValue(object, keys: keys) {
            return Int(value)
        }
        return nil
    }
    
    func boolValue(_ object: [String: AIJSONValue]?, keys: [String]) -> Bool? {
        guard let object = object else { return nil }
        for key in keys {
            if case .bool(let value)? = object[key] {
                return value
            }
        }
        return nil
    }
    
    func objectValue(_ object: [String: AIJSONValue], keys: [String]) -> [String: AIJSONValue]? {
        for key in keys {
            if case .object(let value)? = object[key] {
                return value
            }
        }
        return nil
    }
    
    func arrayValue(_ object: [String: AIJSONValue], keys: [String]) -> [AIJSONValue]? {
        for key in keys {
            if case .array(let value)? = object[key] {
                return value
            }
        }
        return nil
    }
    
    func formatCurrency(_ amount: Decimal) -> String {
        NumberFormatter.currency.string(from: amount as NSDecimalNumber) ?? "$0.00"
    }

    func normalizeTargetType(_ value: String) -> String {
        let lower = value.lowercased()
        switch lower {
        case "monthly", "monthly_target", "monthlytarget":
            return TargetType.monthlyTarget.rawValue
        case "bydate", "by_date", "date_goal", "bydategoal":
            return TargetType.byDateGoal.rawValue
        case "none", "notarget":
            return TargetType.none.rawValue
        default:
            return value
        }
    }

    func normalizedType(_ type: String) -> String {
        let lower = type.lowercased()
        switch lower {
        case "createbudget", "create_budget":
            return "create_bucket"
        case "updatebudget", "update_budget", "setbudget", "set_budget":
            return "update_bucket"
        case "deletebudget", "delete_budget":
            return "delete_bucket"
        default:
            break
        }
        if lower.contains("_") {
            return lower
        }
        switch type {
        case "createBucket":
            return "create_bucket"
        case "updateBucket":
            return "update_bucket"
        case "deleteBucket":
            return "delete_bucket"
        case "createRule":
            return "create_rule"
        case "updateRule":
            return "update_rule"
        case "createMerchantMapping":
            return "create_merchant_mapping"
        default:
            return lower
        }
    }

    func displayActionType(_ type: String) -> String {
        let normalized = normalizedType(type)
        if normalized == "action" {
            return "Action"
        }
        return normalized
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

private enum AIActionError: LocalizedError {
    case missingField(String)
    case notFound(String)
    case unsupportedAction(type: String)
    
    var errorDescription: String? {
        switch self {
        case .missingField(let field):
            return "Missing field: \(field)"
        case .notFound(let item):
            return "\(item.capitalized) not found"
        case .unsupportedAction(let type):
            return "Unsupported action: \(type)"
        }
    }
}
