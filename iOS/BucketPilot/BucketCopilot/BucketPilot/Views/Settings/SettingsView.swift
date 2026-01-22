import SwiftUI
import SwiftData
#if canImport(LinkKit)
import LinkKit
#endif

struct SettingsView: View {
    @SwiftUI.Environment(\.modelContext) private var modelContext
    @Query private var syncState: [SyncState]
    @Query private var buckets: [Bucket]
    @State private var showingPlaidLink = false
    @AppStorage("bankConnected") private var bankConnected = false
    @State private var syncStatusMessage: String?
    @State private var isSyncing = false
    
    var currentSyncState: SyncState? {
        syncState.first
    }
    
    var body: some View {
        NavigationView {
            List {
                // Bank Connection
                Section("Bank Account") {
                    HStack {
                        Image(systemName: bankConnected ? "checkmark.circle.fill" : "xmark.circle")
                            .foregroundColor(bankConnected ? .green : .red)
                        
                        Text(bankConnected ? "Connected" : "Not Connected")
                        
                        Spacer()
                        
                        Button(bankConnected ? "Disconnect" : "Connect") {
                            if bankConnected {
                                disconnectBank()
                            } else {
                                showingPlaidLink = true
                            }
                        }
                    }
                }
                
                // Sync Settings
                Section("Sync") {
                    Toggle("Enable Sync", isOn: Binding(
                        get: { currentSyncState?.syncEnabled ?? false },
                        set: { newValue in
                            toggleSync(newValue)
                        }
                    ))
                    
                    if currentSyncState?.syncEnabled == true {
                        Button(isSyncing ? "Syncing..." : "Sync Now") {
                            syncNow()
                        }
                        .disabled(isSyncing)
                        
                        if let syncStatusMessage = syncStatusMessage {
                            Text(syncStatusMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Backend URL")
                            Spacer()
                            Text(currentSyncState?.backendUrl ?? "Not set")
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Configure Sync") {
                            // TODO: Show sync config sheet
                        }
                        #if DEBUG
                        Button("Create Test Allocation") {
                            createTestAllocation()
                        }
                        Button("Reset Local Data") {
                            resetLocalData()
                        }
                        #endif
                    }
                }
                
                // Data Export
                Section("Data") {
                    Button("Export Data (JSON)") {
                        exportData(format: .json)
                    }
                    
                    Button("Export Data (CSV)") {
                        exportData(format: .csv)
                    }
                }
                
                // Privacy
                Section("Privacy") {
                    Text("BucketPilot uses read-only bank sync. No money movements are made. All budgeting is virtual.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPlaidLink) {
                PlaidLinkView(isConnected: $bankConnected)
            }
        }
    }
    
    private func toggleSync(_ enabled: Bool) {
        if let state = currentSyncState {
            state.syncEnabled = enabled
            if enabled {
                state.backendUrl = Config.backendURL
            }
        } else {
            let newState = SyncState(
                syncEnabled: enabled,
                backendUrl: enabled ? Config.backendURL : nil
            )
            modelContext.insert(newState)
        }
        try? modelContext.save()
    }

    private func syncNow() {
        guard currentSyncState?.syncEnabled == true else {
            return
        }
        
        isSyncing = true
        syncStatusMessage = nil
        
        Task {
            do {
                let service = SyncService(modelContext: modelContext)
                let summary = try await service.sync()
                await MainActor.run {
                    isSyncing = false
                    syncStatusMessage = "Sync complete: pushed \(summary.pushed), pulled \(summary.pulled), applied \(summary.applied)"
                }
            } catch {
                await MainActor.run {
                    isSyncing = false
                    syncStatusMessage = "Sync failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func disconnectBank() {
        // TODO: Implement bank disconnection
        bankConnected = false
    }
    
    private func exportData(format: ExportFormat) {
        // TODO: Implement data export
        print("Exporting data as \(format)")
    }

    private func createTestAllocation() {
        let bucket: Bucket
        if let existing = buckets.first {
            bucket = existing
        } else {
            let newBucket = Bucket(name: "Test Bucket")
            modelContext.insert(newBucket)
            bucket = newBucket
        }
        
        let event = AllocationEvent(
            bucket: bucket,
            amount: 10,
            sourceType: .manual,
            sourceId: "debug",
            timestamp: Date(),
            sequence: 0,
            synced: false
        )
        
        modelContext.insert(event)
        try? modelContext.save()
        syncStatusMessage = "Created test allocation event"
    }

    private func resetLocalData() {
        do {
            try deleteAll(Bucket.self)
            try deleteAll(Transaction.self)
            try deleteAll(TransactionSplit.self)
            try deleteAll(AllocationEvent.self)
            try deleteAll(FundingRule.self)
            try deleteAll(MerchantMappingRule.self)
            try deleteAll(SyncState.self)
            try modelContext.save()
            syncStatusMessage = "Local data cleared"
        } catch {
            syncStatusMessage = "Reset failed: \(error.localizedDescription)"
        }
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        let items = try modelContext.fetch(descriptor)
        for item in items {
            modelContext.delete(item)
        }
    }
}

enum ExportFormat {
    case json
    case csv
}

struct PlaidLinkView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @Binding var isConnected: Bool
    @State private var linkToken: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingLink = false
    private let plaidService = PlaidService()
    
    var body: some View {
        NavigationView {
            VStack {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                } else if isLoading {
                    ProgressView("Preparing Plaid Link...")
                        .padding()
                }
                
                #if canImport(LinkKit)
                if let linkToken = linkToken {
                    VStack(spacing: 12) {
                        ProgressView("Opening Plaid...")
                        Button("Open Plaid Link") {
                            showingLink = true
                        }
                    }
                    .plaidLink(
                        isPresented: $showingLink,
                        token: linkToken,
                        onSuccess: { success in
                            handleSuccess(publicToken: success.publicToken)
                        },
                        onExit: { exit in
                            handleExit(message: exit.error?.localizedDescription)
                        },
                        onEvent: { _ in },
                        onLoad: { },
                        errorView: AnyView(
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text("Link failed to load")
                                Button("Dismiss") {
                                    showingLink = false
                                }
                            }
                            .padding()
                        )
                    )
                }
                #else
                Text("LinkKit not installed. Add Plaid's LinkKit via Swift Package Manager.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                #endif
            }
            .navigationTitle("Connect Bank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadLinkToken()
        }
    }
    
    private func loadLinkToken() async {
        isLoading = true
        errorMessage = nil
        do {
            linkToken = try await plaidService.createLinkToken()
            showingLink = true
        } catch {
            errorMessage = "Failed to create link token: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func handleSuccess(publicToken: String) {
        Task {
            do {
                try await plaidService.exchangePublicToken(publicToken)
                await MainActor.run {
                    isConnected = true
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to exchange token: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func handleExit(message: String?) {
        if let message = message, !message.isEmpty {
            errorMessage = message
        } else {
            dismiss()
        }
        showingLink = false
    }
}

