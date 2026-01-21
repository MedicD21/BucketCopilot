import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var syncState: [SyncState]
    @State private var showingPlaidLink = false
    @State private var bankConnected = false
    
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
                        HStack {
                            Text("Backend URL")
                            Spacer()
                            Text(currentSyncState?.backendUrl ?? "Not set")
                                .foregroundColor(.secondary)
                        }
                        
                        Button("Configure Sync") {
                            // TODO: Show sync config sheet
                        }
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
                PlaidLinkView()
            }
        }
    }
    
    private func toggleSync(_ enabled: Bool) {
        if let state = currentSyncState {
            state.syncEnabled = enabled
        } else {
            let newState = SyncState(syncEnabled: enabled)
            modelContext.insert(newState)
        }
        try? modelContext.save()
    }
    
    private func disconnectBank() {
        // TODO: Implement bank disconnection
        bankConnected = false
    }
    
    private func exportData(format: ExportFormat) {
        // TODO: Implement data export
        print("Exporting data as \(format)")
    }
}

enum ExportFormat {
    case json
    case csv
}

struct PlaidLinkView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Plaid Link Integration - Coming soon")
                    .foregroundColor(.secondary)
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
    }
}
