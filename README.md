# BucketPilot

An offline-first envelope budgeting iOS app with virtual buckets, deterministic auto-funding rules, Plaid read-only bank sync, and an AI copilot for analysis and suggested changes.

## Architecture Overview

### iOS App (Swift + SwiftUI)
- **Storage**: SwiftData for offline-first SQLite persistence
- **Navigation**: TabView with 5 main tabs
- **Theme**: Dark-first design with dynamic colors
- **Sync**: Event sourcing with optional backend sync

### Backend (Node.js/TypeScript or Python/FastAPI)
- **Database**: Postgres (hosted) or SQLite (user-hosted)
- **Auth**: Single-user with API key stored in iOS Keychain
- **Plaid Integration**: Server-side token management
- **AI Integration**: OpenAI/Anthropic with structured JSON outputs

### Data Flow
1. **Offline-First**: iOS app writes all events to local SwiftData store
2. **Event Sourcing**: All changes are append-only events (AllocationEvents, TransactionImports, etc.)
3. **Sync**: When online, events sync to backend via `/sync/pushEvents` and `/sync/pullEvents`
4. **Conflict Resolution**: Event ordering ensures determinism

## Project Structure

```
BucketPilot/
├── iOS/
│   ├── BucketPilot/
│   │   ├── App/
│   │   │   ├── BucketPilotApp.swift
│   │   │   └── ContentView.swift
│   │   ├── Models/
│   │   │   ├── Bucket.swift
│   │   │   ├── Transaction.swift
│   │   │   ├── FundingRule.swift
│   │   │   └── AllocationEvent.swift
│   │   ├── Views/
│   │   │   ├── Home/
│   │   │   ├── Buckets/
│   │   │   ├── Transactions/
│   │   │   ├── Rules/
│   │   │   ├── Insights/
│   │   │   └── Settings/
│   │   ├── Services/
│   │   │   ├── AllocationEngine.swift
│   │   │   ├── PlaidService.swift
│   │   │   ├── AICopilotService.swift
│   │   │   └── SyncService.swift
│   │   └── Data/
│   │       └── DataModel.swift
│   └── BucketPilot.xcodeproj
├── Backend/
│   ├── src/
│   │   ├── routes/
│   │   │   ├── plaid.ts
│   │   │   ├── sync.ts
│   │   │   └── ai.ts
│   │   ├── services/
│   │   │   ├── plaid.service.ts
│   │   │   ├── ai.service.ts
│   │   │   └── sync.service.ts
│   │   └── db/
│   │       └── schema.sql
│   └── package.json
└── docs/
    ├── ARCHITECTURE.md
    ├── DATA_MODELS.md
    └── IMPLEMENTATION_PLAN.md
```

## Core Concepts

### Virtual Buckets (Envelopes)
- Each bucket tracks: Assigned, Activity, Available
- Ledger math: `Available = Assigned + Activity`
- No real money movement - purely virtual allocations

### Auto-Funding Rules
- Deterministic engine (NOT AI-based)
- Supports triggers: income, scheduled, manual, balance threshold
- Actions: allocateFixed, allocatePercent, fillToTarget
- Priority-based execution order

### AI Copilot
- Advisory only - never auto-applies changes
- Outputs structured JSON actions
- Always requires Review Changes screen with confirmation

## Getting Started

See [IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) for milestone breakdown.
