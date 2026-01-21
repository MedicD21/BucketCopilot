# BucketPilot Architecture

## System Overview

BucketPilot is an offline-first envelope budgeting app that follows event sourcing principles for data consistency and conflict-free sync.

## iOS Architecture

### Technology Stack
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Persistence**: SwiftData (SQLite-backed)
- **Network**: URLSession with async/await
- **Dependency Management**: Swift Package Manager

### Architecture Pattern
- **MVVM**: Models, Views, ViewModels
- **Repository Pattern**: Services abstract data access
- **Event Sourcing**: All state changes via events

### Key Components

#### Data Layer
- `DataModel.swift`: SwiftData schema definitions
- `AllocationEngine.swift`: Deterministic rule execution
- `SyncService.swift`: Event sync with backend

#### Service Layer
- `PlaidService.swift`: iOS-side Plaid Link integration
- `AICopilotService.swift`: AI command processing (structured JSON)
- `SyncService.swift`: Bi-directional event sync

#### UI Layer
- Tab-based navigation
- Dark-first theme with dynamic colors
- Empty states and skeleton loaders

### Offline-First Strategy
1. All writes go to local SwiftData store immediately
2. Events are queued for sync when online
3. Conflict resolution via event ordering (timestamp + sequence)
4. Sync is optional - app works fully offline

## Backend Architecture

### Technology Stack (Node.js Option)
- **Runtime**: Node.js 20+
- **Framework**: Express or Fastify
- **Database**: PostgreSQL (default) or SQLite (user-hosted)
- **ORM**: Prisma or Drizzle
- **Auth**: Simple API key validation

### Technology Stack (Python Option)
- **Runtime**: Python 3.11+
- **Framework**: FastAPI
- **Database**: PostgreSQL via asyncpg or SQLite via aiosqlite
- **ORM**: SQLAlchemy or raw SQL
- **Auth**: API key in header

### API Design
- RESTful endpoints
- JSON request/response
- Event-based sync model
- Single-user auth (API key)

### Plaid Integration
- Server-side only (tokens never leave server)
- Webhook support for transaction updates
- Incremental sync via cursor-based pagination

### AI Integration
- Structured function calling (OpenAI or Anthropic)
- Strict JSON schema for actions
- Never auto-apply - always return proposals

## Data Flow

### Transaction Flow
1. User connects bank via Plaid Link (iOS)
2. Public token sent to backend
3. Backend exchanges for access token (stored server-side)
4. Backend fetches transactions
5. Transactions sent to iOS app
6. iOS app stores locally, assigns to buckets

### Allocation Flow
1. Trigger fires (income detected, scheduled, manual)
2. `AllocationEngine` evaluates rules in priority order
3. Creates `AllocationEvent` records (local write)
4. UI updates from local state
5. Events queued for sync

### Sync Flow
1. iOS app periodically checks connectivity
2. Pulls events from backend since last cursor
3. Applies remote events locally (merge)
4. Pushes local events to backend
5. Backend stores events in event log table

## Security

### iOS Side
- API key stored in iOS Keychain
- Plaid Link handles token exchange (public token only)
- No secrets in app bundle

### Backend Side
- Plaid access tokens encrypted at rest
- API key validation on all endpoints
- No logging of tokens or secrets
- HTTPS only

## Event Sourcing

### Event Types
- `AllocationEvent`: Money moved from Unassigned to Bucket
- `TransactionImportEvent`: New transaction imported
- `TransactionSplitEvent`: Transaction assigned to bucket(s)
- `BucketUpdateEvent`: Bucket properties changed
- `RuleUpdateEvent`: Funding rule changed

### Event Schema
```json
{
  "id": "uuid",
  "type": "allocation",
  "timestamp": "ISO8601",
  "sequence": 123,
  "userId": "user-uuid",
  "payload": {...}
}
```

### Replay Strategy
- Events ordered by (timestamp, sequence)
- Replay builds current state
- No update operations - only append

## Sync Strategy

### Event Cursor
- Each device maintains cursor: `{lastTimestamp, lastSequence}`
- Pull: `GET /sync/pullEvents?sinceTimestamp=X&sinceSequence=Y`
- Push: `POST /sync/pushEvents` with array of events

### Conflict Resolution
- Events have monotonic sequence numbers
- Last-write-wins within same timestamp
- Server assigns sequence numbers to resolve conflicts

## Database Schema

### SwiftData Models
- `Bucket`: Virtual envelope
- `Transaction`: Bank transaction
- `TransactionSplit`: Transaction → Bucket mapping
- `AllocationEvent`: Money allocation record
- `FundingRule`: Auto-funding rule definition
- `MerchantMappingRule`: Auto-assignment rule
- `SyncState`: Sync cursor and metadata

### Backend Tables
- `events`: Event log (append-only)
- `plaid_items`: Plaid access tokens (encrypted)
- `users`: Single user record (API key hash)

## Performance Considerations

### iOS
- SwiftData lazy loading for large lists
- Background sync tasks
- Debounced search/filter

### Backend
- Event log indexed by (timestamp, sequence)
- Cursor-based pagination for sync
- Plaid transaction polling interval: 15-30 minutes

## Future Enhancements
- Multi-device sync (already supported via events)
- Cloud backup (export/import events)
- Widget support (iOS)
- Watch app companion
- Receipt scanning (OCR)
