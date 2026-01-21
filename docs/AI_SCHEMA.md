# AI Copilot JSON Schema & Review Changes Flow

## Overview

The AI copilot provides budget analysis and suggestions through structured JSON actions. **All actions require user confirmation** before being applied.

## AI Command Flow

```
User Input
    |
    v
Backend AI Service
    |
    v
Structured JSON Actions
    |
    v
iOS App (Preview)
    |
    v
Review Changes Screen
    |
    v
User Confirms/Rejects
    |
    v
Apply Confirmed Actions (or discard)
```

## JSON Action Schema

### Action Types

```typescript
type Action = 
    | AllocateAction
    | MoveFundsAction
    | UpdateBucketAction
    | CreateBucketAction
    | DeleteBucketAction
    | CreateRuleAction
    | UpdateRuleAction
    | CreateMerchantMappingAction;

interface AllocateAction {
    type: "allocate";
    bucketId: string;
    amount: number;
    source: "unassigned" | { bucketId: string };
}

interface MoveFundsAction {
    type: "move";
    fromBucketId: string;
    toBucketId: string;
    amount: number;
}

interface UpdateBucketAction {
    type: "update_bucket";
    bucketId: string;
    updates: {
        name?: string;
        targetAmount?: number;
        targetDate?: string; // ISO date
        priority?: number;
        // ... other fields
    };
}

interface CreateBucketAction {
    type: "create_bucket";
    name: string;
    icon?: string;
    color?: string;
    targetType?: "none" | "monthlyTarget" | "byDateGoal";
    targetAmount?: number;
    priority?: number;
}

interface DeleteBucketAction {
    type: "delete_bucket";
    bucketId: string;
    confirmationRequired: true; // Always true for deletions
}

interface CreateRuleAction {
    type: "create_rule";
    name: string;
    triggerType: TriggerType;
    conditions: RuleConditions;
    actions: RuleAction[];
    priority: number;
}

interface UpdateRuleAction {
    type: "update_rule";
    ruleId: string;
    updates: {
        enabled?: boolean;
        priority?: number;
        conditions?: RuleConditions;
        actions?: RuleAction[];
    };
}

interface CreateMerchantMappingAction {
    type: "create_merchant_mapping";
    merchantContains: string;
    bucketId: string;
    priority?: number;
}
```

## Example AI Responses

### Example 1: Move Funds
User: "Move $50 from Dining Out to Groceries"

```json
{
    "actions": [
        {
            "type": "move",
            "fromBucketId": "bucket-123",
            "toBucketId": "bucket-456",
            "amount": 50.00
        }
    ],
    "summary": "Move $50.00 from Dining Out to Groceries"
}
```

### Example 2: Create Paycheck Rule
User: "Create a paycheck rule to fund rent then bills then savings"

```json
{
    "actions": [
        {
            "type": "create_rule",
            "name": "Paycheck Allocation",
            "triggerType": "onIncomeDetected",
            "conditions": {
                "minAmount": 1000.00
            },
            "actions": [
                {
                    "type": "allocateFixed",
                    "bucketId": "rent-bucket-id",
                    "amount": 1200.00
                },
                {
                    "type": "allocateFixed",
                    "bucketId": "bills-bucket-id",
                    "amount": 300.00
                },
                {
                    "type": "allocatePercent",
                    "bucketId": "savings-bucket-id",
                    "percent": 20.0
                }
            ],
            "priority": 1
        }
    ],
    "summary": "Created rule to allocate $1200 to rent, $300 to bills, and 20% to savings when income >= $1000 is detected"
}
```

### Example 3: Budget Adjustment
User: "Set groceries to $450/mo and lower eating out"

```json
{
    "actions": [
        {
            "type": "update_bucket",
            "bucketId": "groceries-bucket-id",
            "updates": {
                "targetAmount": 450.00,
                "targetType": "monthlyTarget"
            }
        },
        {
            "type": "update_bucket",
            "bucketId": "dining-out-bucket-id",
            "updates": {
                "targetAmount": 200.00
            }
        }
    ],
    "summary": "Updated groceries monthly target to $450 and dining out to $200"
}
```

### Example 4: Deletion (Requires Confirmation)
User: "Delete my old vacation bucket"

```json
{
    "actions": [
        {
            "type": "delete_bucket",
            "bucketId": "vacation-bucket-id",
            "confirmationRequired": true
        }
    ],
    "summary": "Delete the 'Vacation' bucket (this action requires confirmation)",
    "warnings": ["This will delete all allocation history for this bucket"]
}
```

## Backend AI Service

### Function Calling Schema (OpenAI)

```typescript
// OpenAI function calling schema
const aiFunctions = [
    {
        name: "allocate_funds",
        description: "Allocate funds from Unassigned pool to a bucket",
        parameters: {
            type: "object",
            properties: {
                bucketId: { type: "string" },
                amount: { type: "number" },
            },
            required: ["bucketId", "amount"],
        },
    },
    {
        name: "move_funds",
        description: "Move funds from one bucket to another",
        parameters: {
            type: "object",
            properties: {
                fromBucketId: { type: "string" },
                toBucketId: { type: "string" },
                amount: { type: "number" },
            },
            required: ["fromBucketId", "toBucketId", "amount"],
        },
    },
    // ... more functions
];

// Guardrails
const GUARDRAILS = {
    NO_AUTO_DELETE: "Never delete budget data without explicit confirmation",
    NO_SECRETS: "Never request Plaid secrets or credentials",
    NO_MONEY_MOVEMENT: "Never suggest real money transfers - only virtual allocations",
    STRUCTURED_ONLY: "Always return structured JSON actions, never freeform text",
};
```

### Backend Endpoint

```typescript
// POST /ai/command
router.post('/ai/command', async (req, res) => {
    const { command, context } = req.body;
    // context includes: buckets, recent transactions, unassigned balance
    
    const systemPrompt = `
        You are a budget advisor for BucketPilot, an envelope budgeting app.
        
        Rules:
        - Never auto-apply changes - always return structured JSON actions
        - Never delete data without explicit confirmation
        - Never request sensitive credentials
        - All money movement is virtual (envelope allocations)
        - Be helpful but conservative with suggestions
        
        User budget context:
        - Unassigned: $${context.unassignedBalance}
        - Buckets: ${JSON.stringify(context.buckets)}
        - Recent activity: ${JSON.stringify(context.recentTransactions)}
    `;
    
    const response = await openai.chat.completions.create({
        model: "gpt-4",
        messages: [
            { role: "system", content: systemPrompt },
            { role: "user", content: command },
        ],
        functions: aiFunctions,
        function_call: "auto",
    });
    
    const actions = parseAIResponse(response);
    res.json({ actions, summary: generateSummary(actions) });
});
```

## iOS Review Changes UI

### ReviewChangesView

```swift
struct ReviewChangesView: View {
    let actions: [AIAction]
    let onConfirm: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Summary
                    Text(actionsSummary)
                        .font(.headline)
                    
                    // Action Diffs
                    ForEach(actions, id: \.id) { action in
                        ActionDiffCard(action: action)
                    }
                    
                    // Warnings
                    if hasDeletions {
                        WarningCard(
                            message: "This action includes deletions and requires confirmation",
                            icon: "exclamationmark.triangle.fill"
                        )
                    }
                    
                    // Confirm/Reject Buttons
                    HStack(spacing: 16) {
                        Button("Reject", action: onReject)
                            .buttonStyle(.bordered)
                        
                        Button("Confirm & Apply", action: onConfirm)
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                    }
                }
                .padding()
            }
            .navigationTitle("Review Changes")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ActionDiffCard: View {
    let action: AIAction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: actionIcon)
                    .foregroundColor(actionColor)
                
                Text(actionTitle)
                    .font(.headline)
            }
            
            // Show diff details based on action type
            switch action.type {
            case .allocate:
                Text("Allocate \(formatCurrency(action.amount)) to \(action.bucketName)")
            case .move:
                Text("Move \(formatCurrency(action.amount)) from \(action.fromBucketName) to \(action.toBucketName)")
            case .updateBucket:
                showBucketUpdates(action)
            case .deleteBucket:
                Text("⚠️ Delete bucket: \(action.bucketName)")
            // ... more cases
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
```

### Applying Confirmed Actions

```swift
func applyAIActions(_ actions: [AIAction]) throws {
    for action in actions {
        switch action.type {
        case .allocate:
            try allocateFunds(
                amount: action.amount,
                toBucketId: action.bucketId
            )
        case .move:
            try moveFunds(
                amount: action.amount,
                fromBucketId: action.fromBucketId,
                toBucketId: action.toBucketId
            )
        case .updateBucket:
            try updateBucket(
                id: action.bucketId,
                updates: action.updates
            )
        case .deleteBucket:
            // Requires extra confirmation
            try deleteBucket(id: action.bucketId)
        // ... handle other actions
        }
    }
}
```

## Guardrails Implementation

1. **No Auto-Apply**: All actions go through ReviewChangesView
2. **Deletion Confirmation**: Double confirmation for delete actions
3. **Secret Protection**: Backend validates AI never requests secrets
4. **Validation**: All amounts/bucketIds validated before application
5. **Error Handling**: Graceful failure with user feedback

## Future Enhancements

- Conversation history
- Multi-turn refinements ("Actually make it $500 instead")
- Undo/redo support
- Action templates
- Scheduled suggestions
