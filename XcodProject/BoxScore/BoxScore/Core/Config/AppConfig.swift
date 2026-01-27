//
//  AppConfig.swift
//  BoxScore
//
//  Application configuration with feature flags and base URLs
//

import Foundation

/// Application configuration
final class AppConfig {
    
    // MARK: - Shared Instance
    
    static let shared = AppConfig()
    
    // MARK: - Environment
    
    enum Environment: String {
        case development
        case staging
        case production
    }
    
    /// Current environment (can be changed for testing)
    var environment: Environment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }
    
    // MARK: - Gateway Configuration
    
    /// Base URL for the data gateway
    var gatewayBaseURL: URL {
        switch environment {
        case .development:
            // Use Railway for all builds (no local gateway needed)
            return URL(string: gatewayBaseURLOverride ?? "https://boxscore-gateway-production.up.railway.app")!
        case .staging:
            return URL(string: gatewayBaseURLOverride ?? "https://staging-gateway.boxscore.app")!
        case .production:
            return URL(string: gatewayBaseURLOverride ?? "https://boxscore-gateway-production.up.railway.app")!
        }
    }
    
    /// Override for gateway base URL (for feature flags)
    var gatewayBaseURLOverride: String? {
        get { UserDefaults.standard.string(forKey: Keys.gatewayBaseURLOverride) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.gatewayBaseURLOverride) }
    }
    
    /// Auth token for gateway (if required)
    var authToken: String? {
        get { 
            // In production, this should come from Keychain
            UserDefaults.standard.string(forKey: Keys.authToken)
        }
        set { 
            UserDefaults.standard.set(newValue, forKey: Keys.authToken)
        }
    }
    
    // MARK: - App Info
    
    /// App version string
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    /// Build number
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    /// Unique device identifier (persisted)
    var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: Keys.deviceId) {
            return existing
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: Keys.deviceId)
        return newId
    }
    
    // MARK: - Feature Flags

    /// Enable debug logging for network requests
    var debugNetworkLogging: Bool {
        get { 
            #if DEBUG
            return UserDefaults.standard.object(forKey: Keys.debugNetworkLogging) as? Bool ?? true
            #else
            return false
            #endif
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.debugNetworkLogging) }
    }
    
    /// Enable paid tier features
    var isPaidUser: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.isPaidUser) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.isPaidUser) }
    }
    
    // MARK: - Cache TTL Configuration
    
    /// TTL for live game data (seconds)
    var liveGameTTL: TimeInterval {
        isPaidUser ? 10 : 30
    }
    
    /// TTL for scoreboard data (seconds)
    var scoreboardTTL: TimeInterval {
        isPaidUser ? 15 : 60
    }
    
    /// TTL for box score data (live games, seconds)
    var liveBoxScoreTTL: TimeInterval {
        isPaidUser ? 30 : 60
    }
    
    /// TTL for box score data (final games, seconds)
    var finalBoxScoreTTL: TimeInterval {
        7 * 24 * 60 * 60 // 7 days
    }
    
    /// TTL for standings data (seconds)
    var standingsTTL: TimeInterval {
        24 * 60 * 60 // 24 hours
    }
    
    /// TTL for roster data (seconds)
    var rosterTTL: TimeInterval {
        7 * 24 * 60 * 60 // 7 days
    }
    
    /// TTL for schedule data (seconds)
    var scheduleTTL: TimeInterval {
        24 * 60 * 60 // 24 hours
    }
    
    // MARK: - Initialization

    private init() {
        // Set default values for first launch
        registerDefaults()
    }

    private func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            Keys.debugNetworkLogging: true,
            Keys.isPaidUser: false
        ])
    }
    
    // MARK: - Keys

    private enum Keys {
        static let gatewayBaseURLOverride = "com.boxscore.gatewayBaseURLOverride"
        static let authToken = "com.boxscore.authToken"
        static let deviceId = "com.boxscore.deviceId"
        static let debugNetworkLogging = "com.boxscore.debugNetworkLogging"
        static let isPaidUser = "com.boxscore.isPaidUser"
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension AppConfig {
    /// Reset all configuration to defaults (for testing)
    func resetToDefaults() {
        let keys = [
            Keys.gatewayBaseURLOverride,
            Keys.authToken,
            Keys.debugNetworkLogging,
            Keys.isPaidUser
        ]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        registerDefaults()
    }

    /// Set environment for testing
    func setTestGatewayURL(_ urlString: String) {
        gatewayBaseURLOverride = urlString
    }
}
#endif
