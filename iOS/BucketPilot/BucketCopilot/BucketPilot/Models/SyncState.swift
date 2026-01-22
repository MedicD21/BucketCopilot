import Foundation
import SwiftData

@Model
final class SyncState {
    var id: UUID
    var lastSyncTimestamp: Date?
    var lastSyncSequence: Int64
    var syncEnabled: Bool
    var backendUrl: String?
    var apiKeyHash: String? // Hash for display only, actual key in Keychain
    
    init(
        id: UUID = UUID(),
        lastSyncTimestamp: Date? = nil,
        lastSyncSequence: Int64 = 0,
        syncEnabled: Bool = false,
        backendUrl: String? = nil,
        apiKeyHash: String? = nil
    ) {
        self.id = id
        self.lastSyncTimestamp = lastSyncTimestamp
        self.lastSyncSequence = lastSyncSequence
        self.syncEnabled = syncEnabled
        self.backendUrl = backendUrl
        self.apiKeyHash = apiKeyHash
    }
}
