# Plaid Integration Flow

## Overview

BucketPilot uses Plaid Link for read-only bank account connection. All Plaid API calls (including access token management) happen on the backend to ensure security.

## Architecture

```
iOS App                    Backend                  Plaid API
  |                           |                        |
  |-- Plaid Link (SDK) -------|                        |
  |                           |-- create_link_token -->|
  |<-- link_token ------------|                        |
  |                           |                        |
  |-- Open Link UI -----------|                        |
  |                           |                        |
  |-- public_token -----------|                        |
  |                           |-- exchange_token ----->|
  |                           |<-- access_token -------|
  |                           |                        |
  |-- Request accounts -------|                        |
  |                           |-- get_accounts ------->|
  |<-- accounts --------------|                        |
  |                           |                        |
  |-- Request transactions ---|                        |
  |                           |-- get_transactions --->|
  |<-- transactions ----------|                        |
```

## iOS Implementation

### 1. Plaid Link SDK Setup

Add to `Package.swift` or Xcode:
```swift
dependencies: [
    .package(url: "https://github.com/plaid/plaid-link-ios", from: "4.0.0")
]
```

### 2. PlaidService

```swift
import Plaid

class PlaidService: ObservableObject {
    private let backendUrl: String
    private let apiKey: String
    
    func createLinkToken() async throws -> String {
        let url = URL(string: "\(backendUrl)/plaid/create_link_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(CreateLinkTokenResponse.self, from: data)
        return response.linkToken
    }
    
    func exchangePublicToken(_ publicToken: String) async throws {
        let url = URL(string: "\(backendUrl)/plaid/exchange_public_token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["public_token": publicToken]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw PlaidError.exchangeFailed
        }
    }
    
    func fetchAccounts() async throws -> [PlaidAccount] {
        // Similar implementation
    }
    
    func fetchTransactions(cursor: String?) async throws -> PlaidTransactionsResponse {
        // Similar implementation with cursor support
    }
}

struct CreateLinkTokenResponse: Codable {
    let linkToken: String
}

struct PlaidAccount: Codable, Identifiable {
    let id: String
    let name: String
    let type: String
    let balances: AccountBalances
}

struct AccountBalances: Codable {
    let available: Decimal?
    let current: Decimal
}
```

### 3. PlaidLinkView Implementation

```swift
import SwiftUI
import Plaid

struct PlaidLinkView: View {
    @StateObject private var plaidService = PlaidService()
    @State private var linkToken: String?
    @State private var isPresentingLink = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            if linkToken == nil {
                ProgressView("Initializing...")
            } else {
                // Plaid Link will be presented via PlaidLink delegate
            }
        }
        .task {
            await loadLinkToken()
        }
        .onAppear {
            isPresentingLink = true
        }
    }
    
    private func loadLinkToken() async {
        do {
            let token = try await plaidService.createLinkToken()
            await MainActor.run {
                linkToken = token
            }
        } catch {
            print("Error loading link token: \(error)")
        }
    }
}

// Plaid Link Delegate
extension PlaidLinkView: LinkDelegate {
    func linkViewController(_ linkViewController: LinkViewController, didSucceedWithPublicToken publicToken: String, metadata: LinkSuccessMetadata) {
        Task {
            do {
                try await plaidService.exchangePublicToken(publicToken)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error exchanging token: \(error)")
            }
        }
    }
    
    func linkViewController(_ linkViewController: LinkViewController, didExitWithError error: Error?, metadata: LinkExitMetadata?) {
        // Handle error or cancellation
        dismiss()
    }
}
```

## Backend Implementation

### 1. Environment Variables

```bash
PLAID_CLIENT_ID=your_client_id
PLAID_SECRET=sandbox_secret  # or production_secret
PLAID_ENVIRONMENT=sandbox    # or production
```

### 2. Backend Routes (Node.js/Express example)

```typescript
// routes/plaid.ts
import express from 'express';
import { Configuration, PlaidApi, PlaidEnvironments, LinkTokenCreateRequest } from 'plaid';
import { encrypt, decrypt } from '../utils/encryption';

const router = express.Router();

const configuration = new Configuration({
    basePath: PlaidEnvironments[process.env.PLAID_ENVIRONMENT],
    baseOptions: {
        headers: {
            'PLAID-CLIENT-ID': process.env.PLAID_CLIENT_ID,
            'PLAID-SECRET': process.env.PLAID_SECRET,
        },
    },
});

const client = new PlaidApi(configuration);

// Create Link Token
router.post('/create_link_token', async (req, res) => {
    try {
        const userId = req.user.id; // From auth middleware
        
        const request: LinkTokenCreateRequest = {
            user: {
                client_user_id: userId,
            },
            client_name: 'BucketPilot',
            products: ['transactions'],
            country_codes: ['US'],
            language: 'en',
        };
        
        const response = await client.linkTokenCreate(request);
        res.json({ link_token: response.data.link_token });
    } catch (error) {
        console.error('Error creating link token:', error);
        res.status(500).json({ error: 'Failed to create link token' });
    }
});

// Exchange Public Token
router.post('/exchange_public_token', async (req, res) => {
    try {
        const { public_token } = req.body;
        const userId = req.user.id;
        
        const response = await client.itemPublicTokenExchange({
            public_token,
        });
        
        const { access_token, item_id } = response.data;
        
        // Encrypt and store access_token
        const encryptedToken = encrypt(access_token);
        
        await db.plaidItems.upsert({
            where: { userId },
            update: {
                itemId: item_id,
                accessTokenEncrypted: encryptedToken,
                updatedAt: new Date(),
            },
            create: {
                userId,
                itemId: item_id,
                accessTokenEncrypted: encryptedToken,
            },
        });
        
        res.json({ success: true });
    } catch (error) {
        console.error('Error exchanging token:', error);
        res.status(500).json({ error: 'Failed to exchange token' });
    }
});

// Get Accounts
router.get('/accounts', async (req, res) => {
    try {
        const userId = req.user.id;
        const item = await db.plaidItems.findUnique({ where: { userId } });
        
        if (!item) {
            return res.status(404).json({ error: 'No connected account' });
        }
        
        const accessToken = decrypt(item.accessTokenEncrypted);
        const response = await client.accountsGet({
            access_token: accessToken,
        });
        
        res.json({ accounts: response.data.accounts });
    } catch (error) {
        console.error('Error fetching accounts:', error);
        res.status(500).json({ error: 'Failed to fetch accounts' });
    }
});

// Get Transactions
router.get('/transactions', async (req, res) => {
    try {
        const userId = req.user.id;
        const { cursor, start_date, end_date } = req.query;
        
        const item = await db.plaidItems.findUnique({ where: { userId } });
        if (!item) {
            return res.status(404).json({ error: 'No connected account' });
        }
        
        const accessToken = decrypt(item.accessTokenEncrypted);
        
        const response = await client.transactionsGet({
            access_token: accessToken,
            start_date: start_date || getDefaultStartDate(),
            end_date: end_date || new Date().toISOString().split('T')[0],
            cursor: cursor || undefined,
            count: 500,
        });
        
        res.json({
            transactions: response.data.transactions,
            total_transactions: response.data.total_transactions,
            next_cursor: response.data.next_cursor,
        });
    } catch (error) {
        console.error('Error fetching transactions:', error);
        res.status(500).json({ error: 'Failed to fetch transactions' });
    }
});

export default router;
```

## Transaction Sync Flow

### 1. Initial Sync
- iOS app calls `/plaid/transactions` without cursor
- Backend returns transactions + `next_cursor`
- iOS stores transactions locally with `plaidTransactionId` for deduplication

### 2. Incremental Sync
- iOS app calls `/plaid/transactions` with cursor from last sync
- Backend returns only new/updated transactions
- iOS app merges transactions (dedupe by `plaidTransactionId`)

### 3. Duplicate Handling
```swift
func syncTransactions() async throws {
    let cursor = getLastSyncCursor()
    let response = try await plaidService.fetchTransactions(cursor: cursor)
    
    for plaidTransaction in response.transactions {
        // Check if transaction already exists
        let existing = try findTransaction(plaidTransactionId: plaidTransaction.id)
        if existing == nil {
            let transaction = Transaction(
                plaidTransactionId: plaidTransaction.id,
                accountId: plaidTransaction.account_id,
                merchantName: plaidTransaction.merchant_name,
                amount: Decimal(plaidTransaction.amount),
                date: parseDate(plaidTransaction.date),
                isPending: plaidTransaction.pending
            )
            modelContext.insert(transaction)
        }
    }
    
    saveLastSyncCursor(response.nextCursor)
    try modelContext.save()
}
```

## Security Considerations

1. **Never store Plaid secrets in iOS app** - only in backend
2. **Encrypt access tokens at rest** on backend
3. **Use HTTPS only** for all API calls
4. **Store API key in iOS Keychain** (not UserDefaults)
5. **Implement token refresh** if needed (Plaid handles this)

## Error Handling

Common Plaid errors:
- `ITEM_LOGIN_REQUIRED`: User needs to re-authenticate
- `RATE_LIMIT_EXCEEDED`: Too many requests, retry with backoff
- `INSTITUTION_DOWN`: Bank temporarily unavailable

Handle gracefully in UI with retry options.
