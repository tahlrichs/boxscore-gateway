//
//  KeychainManager.swift
//  BoxScore
//
//  Secure storage for sensitive data using iOS Keychain
//

import Foundation
import Security

/// Manager for securely storing and retrieving data from iOS Keychain
final class KeychainManager {

    // MARK: - Shared Instance

    static let shared = KeychainManager()

    private init() {}

    // MARK: - Public Methods

    /// Save a string value to Keychain
    func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        return save(data, forKey: key)
    }

    /// Save data to Keychain
    func save(_ data: Data, forKey key: String) -> Bool {
        // Delete any existing item
        delete(forKey: key)

        // Create query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Retrieve a string value from Keychain
    func getString(forKey key: String) -> String? {
        guard let data = getData(forKey: key) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// Retrieve data from Keychain
    func getData(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    /// Delete an item from Keychain
    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Check if a key exists in Keychain
    func exists(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Clear all items from Keychain (use with caution)
    func clearAll() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}

// MARK: - Keychain Keys

extension KeychainManager {
    /// Standard keychain keys used by the app
    enum Keys {
        static let authToken = "com.boxscore.authToken"
        static let refreshToken = "com.boxscore.refreshToken"
        static let apiKey = "com.boxscore.apiKey"
    }
}

// MARK: - Convenience Methods

extension KeychainManager {
    /// Save auth token securely
    func saveAuthToken(_ token: String) -> Bool {
        return save(token, forKey: Keys.authToken)
    }

    /// Retrieve auth token
    func getAuthToken() -> String? {
        return getString(forKey: Keys.authToken)
    }

    /// Delete auth token
    func deleteAuthToken() -> Bool {
        return delete(forKey: Keys.authToken)
    }

    /// Save refresh token securely
    func saveRefreshToken(_ token: String) -> Bool {
        return save(token, forKey: Keys.refreshToken)
    }

    /// Retrieve refresh token
    func getRefreshToken() -> String? {
        return getString(forKey: Keys.refreshToken)
    }

    /// Delete refresh token
    func deleteRefreshToken() -> Bool {
        return delete(forKey: Keys.refreshToken)
    }
}
