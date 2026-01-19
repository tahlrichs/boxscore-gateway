//
//  HealthCheck.swift
//  BoxScore
//
//  Gateway health monitoring
//

import Foundation

/// Health check result from the gateway
struct HealthCheckResult: Codable {
    let status: String
    let timestamp: String
    let version: String?
    let uptime: TimeInterval?

    var isHealthy: Bool {
        status == "ok" || status == "healthy"
    }
}

/// Manager for checking gateway health
actor HealthCheckManager {

    // MARK: - Shared Instance

    static let shared = HealthCheckManager()

    // MARK: - Properties

    private let client: GatewayClient
    private let config: AppConfig

    private var lastHealthCheck: Date?
    private var lastHealthStatus: HealthCheckResult?
    private var isHealthy: Bool = true

    // MARK: - Initialization

    init(client: GatewayClient = .shared, config: AppConfig = .shared) {
        self.client = client
        self.config = config
    }

    // MARK: - Public Methods

    /// Perform a health check on the gateway
    /// Returns true if the gateway is healthy, false otherwise
    func checkHealth() async -> Bool {
        do {
            let result: HealthCheckResult = try await client.fetch(.health)
            lastHealthCheck = Date()
            lastHealthStatus = result
            isHealthy = result.isHealthy

            if config.debugNetworkLogging {
                print("HealthCheck: Gateway is \(result.status)")
            }

            return result.isHealthy
        } catch {
            lastHealthCheck = Date()
            lastHealthStatus = nil
            isHealthy = false

            if config.debugNetworkLogging {
                print("HealthCheck: Gateway health check failed: \(error)")
            }

            return false
        }
    }

    /// Get the current health status without performing a new check
    func getCurrentStatus() -> (isHealthy: Bool, lastCheck: Date?) {
        return (isHealthy, lastHealthCheck)
    }

    /// Get the last health check result
    func getLastResult() -> HealthCheckResult? {
        return lastHealthStatus
    }

    /// Check if we should perform a health check
    /// Returns true if we haven't checked in the last 5 minutes
    func shouldPerformHealthCheck() -> Bool {
        guard let lastCheck = lastHealthCheck else {
            return true
        }

        let timeSinceLastCheck = Date().timeIntervalSince(lastCheck)
        return timeSinceLastCheck > 300 // 5 minutes
    }
}
