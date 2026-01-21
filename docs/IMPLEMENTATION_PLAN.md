# BucketPilot Implementation Plan

## Milestone 1: MVP Core (Week 1-2)

### Phase 1.1: Data Models & Storage
- [ ] Create SwiftData models (Bucket, Transaction, TransactionSplit, AllocationEvent)
- [ ] Implement data persistence layer
- [ ] Create basic CRUD operations
- [ ] Add ledger calculation helpers (assigned, activity, available)

### Phase 1.2: Basic UI Structure
- [ ] Set up TabView with 5 tabs
- [ ] Implement dark theme with dynamic colors
- [ ] Create Home tab with unassigned balance
- [ ] Create Buckets list view (empty state)
- [ ] Create Transactions list view (empty state)
- [ ] Create Settings tab (placeholder)

### Phase 1.3: Bucket Management
- [ ] Add/Edit/Delete buckets
- [ ] Bucket detail view showing ledger math
- [ ] Manual allocation UI (move money from Unassigned to Bucket)
- [ ] Visual indicators (overspent, on-target)

**Deliverable**: Working offline app with manual bucket management

---

## Milestone 2: Transaction Handling (Week 3)

### Phase 2.1: Manual Transaction Entry
- [ ] Add transaction form
- [ ] Transaction → Bucket assignment (single bucket)
- [ ] Transaction splitting (multiple buckets)
- [ ] Transaction list with filters

### Phase 2.2: Merchant Mapping
- [ ] Create MerchantMappingRule model
- [ ] Merchant mapping UI (create/edit rules)
- [ ] Auto-assignment on transaction entry
- [ ] Rule priority system

**Deliverable**: Full transaction management without bank sync

---

## Milestone 3: Funding Rules Engine (Week 4)

### Phase 3.1: Rule Models & Storage
- [ ] FundingRule SwiftData model
- [ ] RuleConditions and RuleAction structures
- [ ] Rule CRUD operations

### Phase 3.2: Allocation Engine
- [ ] Deterministic rule evaluation algorithm
- [ ] Priority-based execution
- [ ] Support all trigger types (scheduled, manual, income, threshold)
- [ ] Support all action types (fixed, percent, fillToTarget)

### Phase 3.3: Rule UI
- [ ] Rule list view
- [ ] Rule creation/editing form
- [ ] Manual rule execution ("Run Rules Now")
- [ ] Preview mode (show proposed allocations)

**Deliverable**: Automated funding rules working offline

---

## Milestone 4: Plaid Integration (Week 5-6)

### Phase 4.1: Backend Setup
- [ ] Create backend project structure
- [ ] Set up Plaid client library
- [ ] Implement `/plaid/create_link_token` endpoint
- [ ] Implement `/plaid/exchange_public_token` endpoint
- [ ] Secure token storage (encrypted)

### Phase 4.2: iOS Plaid Link
- [ ] Integrate Plaid Link SDK
- [ ] Implement Link flow in Settings
- [ ] Handle public token exchange
- [ ] Store connection state

### Phase 4.3: Transaction Sync
- [ ] Backend: `/plaid/accounts` endpoint
- [ ] Backend: `/plaid/transactions` endpoint
- [ ] iOS: Fetch accounts and balances
- [ ] iOS: Fetch transactions (incremental)
- [ ] Deduplicate transactions (Plaid transaction_id)
- [ ] Show last sync time

**Deliverable**: Read-only bank account sync working

---

## Milestone 5: Event Sync (Week 7)

### Phase 5.1: Backend Event Storage
- [ ] Create events table (append-only log)
- [ ] Implement `/sync/pushEvents` endpoint
- [ ] Implement `/sync/pullEvents` endpoint
- [ ] Sequence number assignment
- [ ] Conflict resolution logic

### Phase 5.2: iOS Sync Service
- [ ] Create SyncService
- [ ] Event queue for offline writes
- [ ] Background sync task
- [ ] Cursor management (lastSyncTimestamp, lastSyncSequence)
- [ ] Merge remote events locally

### Phase 5.3: Sync UI
- [ ] Sync status indicator in Settings
- [ ] Manual sync trigger
- [ ] Sync error handling
- [ ] Toggle sync on/off

**Deliverable**: Multi-device sync working

---

## Milestone 6: AI Copilot (Week 8-9)

### Phase 6.1: AI Service Backend
- [ ] Set up OpenAI/Anthropic client
- [ ] Design JSON action schema
- [ ] Implement `/ai/command` endpoint
- [ ] Function calling setup (structured outputs)
- [ ] Guardrails (no deletions without confirmation)

### Phase 6.2: Action Schema
- [ ] Define action types (allocate, updateBucket, createRule, etc.)
- [ ] Validation functions
- [ ] Action diff calculation

### Phase 6.3: iOS AI Integration
- [ ] AICopilotService (API client)
- [ ] Insights tab with chat UI
- [ ] Command input
- [ ] Review Changes screen (diff view)
- [ ] Confirm/Reject actions
- [ ] Apply confirmed actions locally

**Deliverable**: AI copilot working with confirmation flow

---

## Milestone 7: Insights & Polish (Week 10)

### Phase 7.1: Insights Tab
- [ ] Monthly spend by bucket (chart)
- [ ] Income vs expenses overview
- [ ] Subscription detection (recurring merchants)
- [ ] Overspending alerts
- [ ] Trend analysis

### Phase 7.2: Home Dashboard
- [ ] Total available to budget
- [ ] Top buckets summary
- [ ] Overspent buckets badge
- [ ] Safe-to-spend calculation
- [ ] Recent activity feed

### Phase 7.3: UX Improvements
- [ ] Skeleton loaders
- [ ] Empty states for all views
- [ ] Error handling and retry logic
- [ ] Loading states
- [ ] Toast notifications
- [ ] Export data (JSON/CSV)

**Deliverable**: Polished app ready for beta

---

## Milestone 8: Advanced Features (Future)

### Phase 8.1: Additional Features
- [ ] Budget goals and progress tracking
- [ ] Monthly rollover handling
- [ ] Capped rollover logic
- [ ] Balance threshold rules
- [ ] Plaid webhook support (real-time updates)

### Phase 8.2: User Experience
- [ ] iOS Widget support
- [ ] Apple Watch companion
- [ ] Receipt scanning (OCR)
- [ ] Push notifications for overspending
- [ ] Multi-currency support

---

## Technical Debt & Maintenance

### Testing
- Unit tests for AllocationEngine
- Integration tests for sync
- UI tests for critical flows

### Documentation
- Code comments
- API documentation
- User guide

### Performance
- Optimize SwiftData queries
- Pagination for large transaction lists
- Background processing optimization

---

## Risk Mitigation

1. **Plaid Integration Complexity**
   - Start with sandbox environment
   - Handle all error cases
   - Test incremental sync thoroughly

2. **Sync Conflicts**
   - Use event sourcing (append-only)
   - Server-assigned sequence numbers
   - Test multi-device scenarios

3. **AI Accuracy**
   - Strict JSON schema validation
   - Always require confirmation
   - Log all AI actions for review

4. **Offline Reliability**
   - Test all features offline
   - Queue all writes locally
   - Graceful degradation

---

## Success Metrics

- ✅ App works fully offline
- ✅ All money movement is virtual (no real transfers)
- ✅ AI never auto-applies changes
- ✅ Sync resolves conflicts correctly
- ✅ Plaid integration is read-only
- ✅ Rules engine is deterministic
