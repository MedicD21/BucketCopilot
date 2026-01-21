# BucketPilot Data Models

## SwiftData Models (iOS)

### Bucket
```swift
@Model
class Bucket {
    var id: UUID
    var name: String
    var icon: String  // SF Symbol name
    var color: String  // Hex color
    var targetType: TargetType  // none, monthlyTarget, byDateGoal
    var targetAmount: Decimal?
    var targetDate: Date?
    var priority: Int  // 1-10
    var rolloverMode: RolloverMode  // rollover, resetMonthly, cappedRollover
    var rolloverCap: Decimal?
    var allowNegative: Bool
    var createdAt: Date
    var updatedAt: Date
}
```

### Transaction
```swift
@Model
class Transaction {
    var id: UUID
    var plaidTransactionId: String?  // Stable Plaid ID
    var accountId: String
    var merchantName: String?
    var amount: Decimal  // Negative for debits
    var date: Date
    var category: [String]?  // Plaid categories
    var description: String?
    var isPending: Bool
    var createdAt: Date
}
```

### TransactionSplit
```swift
@Model
class TransactionSplit {
    var id: UUID
    var transaction: Transaction
    var bucket: Bucket?
    var amount: Decimal
    var createdAt: Date
}
```

### AllocationEvent
```swift
@Model
class AllocationEvent {
    var id: UUID
    var bucket: Bucket?
    var amount: Decimal  // Positive = allocated TO bucket
    var sourceType: SourceType  // manual, rule, import
    var sourceId: String?  // Rule ID or "manual"
    var timestamp: Date
    var sequence: Int64
    var synced: Bool
}
```

### FundingRule
```swift
@Model
class FundingRule {
    var id: UUID
    var name: String
    var enabled: Bool
    var priority: Int
    var triggerType: TriggerType
    var conditions: RuleConditions
    var actions: [RuleAction]
    var createdAt: Date
    var updatedAt: Date
}
```

### RuleConditions
```swift
struct RuleConditions: Codable {
    var accountId: String?
    var minAmount: Decimal?
    var merchantContains: String?
    var dayOfMonth: Int?
    var weekday: Int?  // 1-7, Sunday=1
}
```

### RuleAction
```swift
enum RuleAction: Codable {
    case allocateFixed(bucketId: UUID, amount: Decimal)
    case allocatePercent(bucketId: UUID, percent: Double)
    case fillToTarget(bucketId: UUID)
}
```

### MerchantMappingRule
```swift
@Model
class MerchantMappingRule {
    var id: UUID
    var merchantContains: String
    var bucket: Bucket
    var priority: Int
    var createdAt: Date
}
```

### SyncState
```swift
@Model
class SyncState {
    var id: UUID
    var lastSyncTimestamp: Date?
    var lastSyncSequence: Int64
    var syncEnabled: Bool
    var backendUrl: String?
    var apiKeyHash: String?  // Not the actual key
}
```

## Database Schema (Backend)

### events
```sql
CREATE TABLE events (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    sequence BIGSERIAL,
    payload JSONB NOT NULL,
    device_id VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_events_user_timestamp ON events(user_id, timestamp, sequence);
```

### buckets (denormalized for queries)
```sql
CREATE TABLE buckets (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    icon VARCHAR(50),
    color VARCHAR(7),
    target_type VARCHAR(20),
    target_amount DECIMAL(12,2),
    target_date DATE,
    priority INT,
    rollover_mode VARCHAR(20),
    rollover_cap DECIMAL(12,2),
    allow_negative BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### transactions
```sql
CREATE TABLE transactions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    plaid_transaction_id VARCHAR(255) UNIQUE,
    account_id VARCHAR(255) NOT NULL,
    merchant_name VARCHAR(255),
    amount DECIMAL(12,2) NOT NULL,
    date DATE NOT NULL,
    category JSONB,
    description TEXT,
    is_pending BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_transactions_user_date ON transactions(user_id, date DESC);
CREATE INDEX idx_transactions_plaid_id ON transactions(plaid_transaction_id);
```

### transaction_splits
```sql
CREATE TABLE transaction_splits (
    id UUID PRIMARY KEY,
    transaction_id UUID NOT NULL REFERENCES transactions(id),
    bucket_id UUID REFERENCES buckets(id),
    amount DECIMAL(12,2) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_splits_transaction ON transaction_splits(transaction_id);
CREATE INDEX idx_splits_bucket ON transaction_splits(bucket_id);
```

### allocation_events (denormalized)
```sql
CREATE TABLE allocation_events (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    bucket_id UUID REFERENCES buckets(id),
    amount DECIMAL(12,2) NOT NULL,
    source_type VARCHAR(20) NOT NULL,
    source_id VARCHAR(255),
    timestamp TIMESTAMPTZ NOT NULL,
    sequence BIGINT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_allocations_user_bucket ON allocation_events(user_id, bucket_id, timestamp);
```

### funding_rules
```sql
CREATE TABLE funding_rules (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    enabled BOOLEAN DEFAULT true,
    priority INT NOT NULL,
    trigger_type VARCHAR(50) NOT NULL,
    conditions JSONB,
    actions JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_rules_user_enabled ON funding_rules(user_id, enabled, priority);
```

### plaid_items
```sql
CREATE TABLE plaid_items (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    item_id VARCHAR(255) UNIQUE NOT NULL,
    access_token_encrypted TEXT NOT NULL,
    institution_id VARCHAR(255),
    institution_name VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### users
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY,
    email VARCHAR(255) UNIQUE,
    api_key_hash VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Ledger Calculations

### Bucket State (Derived from Events)
```swift
struct BucketState {
    let bucket: Bucket
    var assigned: Decimal {
        // Sum of AllocationEvents where bucket == self
        allocationEvents.reduce(0) { $0 + $1.amount }
    }
    var activity: Decimal {
        // Sum of TransactionSplits where bucket == self
        transactionSplits.reduce(0) { $0 + $1.amount }
    }
    var available: Decimal {
        assigned + activity
    }
}
```

### Unassigned Pool
```swift
var unassignedBalance: Decimal {
    // Total allocations FROM unassigned (negative amount events)
    let totalAllocated = allocationEvents
        .filter { $0.bucket != nil }
        .reduce(0) { $0 + $1.amount }
    
    // Plus any income (positive transactions)
    let income = transactions
        .filter { $0.amount > 0 }
        .reduce(0) { $0 + $1.amount }
    
    // Minus all allocations
    return income - totalAllocated
}
```

## Data Relationships

```
Bucket 1---* AllocationEvent
Bucket 1---* TransactionSplit
Bucket 1---* MerchantMappingRule
Bucket *---1 FundingRule (via actions)

Transaction 1---* TransactionSplit
Transaction *---1 Account (Plaid)

FundingRule *---* Bucket (via actions)

AllocationEvent *---1 Bucket (nullable = from Unassigned)
```
