import Foundation

/// Configuration management for BucketPilot iOS app
/// 
/// For API keys and sensitive configuration:
/// - Backend URL: Store in Keychain or UserDefaults (non-sensitive)
/// - API Key: MUST be stored in iOS Keychain (never in code/plist)
/// - Plaid keys: Never stored in iOS app (only on backend)
struct Config {
    
    // MARK: - Backend Configuration
    
    /// Backend API base URL
    /// For development: http://localhost:3000
    /// For production: https://your-backend.com
    static var backendURL: String {
        #if DEBUG
        return ProcessInfo.processInfo.environment["BACKEND_URL"] ?? "http://localhost:3000"
        #else
        // Production URL - set via build configuration or environment variable
        return ProcessInfo.processInfo.environment["BACKEND_URL"] ?? "https://api.bucketpilot.app"
        #endif
    }
    
    // MARK: - Keychain Storage
    
    /// API key for backend authentication
    /// This should be retrieved from iOS Keychain, not stored here
    static func getAPIKey() -> String? {
        return KeychainHelper.shared.get(key: "bucketpilot_api_key")
    }
    
    static func saveAPIKey(_ key: String) {
        KeychainHelper.shared.set(key: "bucketpilot_api_key", value: key)
    }
    
    static func deleteAPIKey() {
        KeychainHelper.shared.delete(key: "bucketpilot_api_key")
    }
}

// MARK: - Keychain Helper

import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    private let service = "com.bucketpilot.app"
    
    private init() {}
    
    func set(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item if present
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
