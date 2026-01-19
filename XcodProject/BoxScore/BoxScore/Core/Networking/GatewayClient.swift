//
//  GatewayClient.swift
//  BoxScore
//
//  Central networking client for gateway API communication
//

import Foundation

/// Protocol for the gateway client to enable testing
protocol GatewayClientProtocol {
    func fetch<T: Decodable>(_ endpoint: GatewayEndpoint) async throws -> T
    func fetchWithMetadata<T: Decodable>(_ endpoint: GatewayEndpoint) async throws -> (data: T, lastUpdated: Date?)
}

/// Main gateway client for all API communication
actor GatewayClient: GatewayClientProtocol {
    
    // MARK: - Properties
    
    private let session: URLSession
    private let config: AppConfig
    private let decoder: JSONDecoder
    
    // Circuit breaker state
    private var consecutiveFailures = 0
    private var circuitOpenUntil: Date?
    private let maxConsecutiveFailures = 3
    private let circuitResetInterval: TimeInterval = 30
    
    // MARK: - Initialization
    
    init(config: AppConfig = .shared, session: URLSession? = nil) {
        self.config = config
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        
        // Configure URLSession with timeouts
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 60
        sessionConfig.waitsForConnectivity = true
        
        self.session = session ?? URLSession(configuration: sessionConfig)
    }
    
    // MARK: - Public Methods
    
    /// Fetch data from an endpoint
    nonisolated func fetch<T: Decodable>(_ endpoint: GatewayEndpoint) async throws -> T {
        let (data, _) = try await fetchWithMetadata(endpoint) as (T, Date?)
        return data
    }
    
    /// Fetch data with lastUpdated metadata
    nonisolated func fetchWithMetadata<T: Decodable>(_ endpoint: GatewayEndpoint) async throws -> (data: T, lastUpdated: Date?) {
        // Check circuit breaker
        try await checkCircuitBreaker()
        
        // Build request
        let request = try await buildRequest(for: endpoint)
        
        // Execute with retry
        do {
            let result = try await executeWithRetry(request: request, retryCount: 1) as (T, Date?)
            await recordSuccess()
            return result
        } catch {
            await recordFailure()
            throw error
        }
    }
    
    // MARK: - Private Methods
    
    private func buildRequest(for endpoint: GatewayEndpoint) throws -> URLRequest {
        guard let url = endpoint.url(baseURL: config.gatewayBaseURL) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        
        // Standard headers
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("BoxScore/\(config.appVersion)", forHTTPHeaderField: "X-Client-Version")
        request.setValue(config.deviceId, forHTTPHeaderField: "X-Device-ID")
        
        // Add authorization if configured
        if let authToken = config.authToken {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    private func executeWithRetry<T: Decodable>(request: URLRequest, retryCount: Int) async throws -> (T, Date?) {
        do {
            return try await execute(request: request)
        } catch let error as NetworkError where error.isRetryable && retryCount > 0 {
            // Exponential backoff
            let delay = pow(2.0, Double(1 - retryCount)) // 1s, 2s, etc.
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return try await executeWithRetry(request: request, retryCount: retryCount - 1)
        }
    }
    
    private func execute<T: Decodable>(request: URLRequest) async throws -> (T, Date?) {
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw NetworkError.networkUnavailable
            case .timedOut:
                throw NetworkError.timeout
            default:
                throw NetworkError.unknown(urlError)
            }
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(NSError(domain: "InvalidResponse", code: 0))
        }
        
        // Handle HTTP errors
        switch httpResponse.statusCode {
        case 200...299:
            break // Success
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw NetworkError.rateLimited(retryAfter: retryAfter)
        case 400...499:
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        case 500...599:
            let message = try? decoder.decode(GatewayErrorResponse.self, from: data).message
            throw NetworkError.serverError(message: message)
        default:
            throw NetworkError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        
        // Decode response
        do {
            // Try to decode as wrapped response first
            let wrapped = try decoder.decode(GatewayResponse<T>.self, from: data)
            return (wrapped.data, wrapped.lastUpdated)
        } catch {
            // Fall back to direct decode
            do {
                let directData = try decoder.decode(T.self, from: data)
                return (directData, nil)
            } catch let decodingError {
                throw NetworkError.decodingError(decodingError)
            }
        }
    }
    
    // MARK: - Circuit Breaker
    
    private func checkCircuitBreaker() throws {
        if let openUntil = circuitOpenUntil {
            if Date() < openUntil {
                throw NetworkError.circuitBreakerOpen
            } else {
                // Reset circuit breaker
                circuitOpenUntil = nil
                consecutiveFailures = 0
            }
        }
    }
    
    private func recordSuccess() {
        consecutiveFailures = 0
        circuitOpenUntil = nil
    }
    
    private func recordFailure() {
        consecutiveFailures += 1
        if consecutiveFailures >= maxConsecutiveFailures {
            circuitOpenUntil = Date().addingTimeInterval(circuitResetInterval)
        }
    }
}

// MARK: - Shared Instance

extension GatewayClient {
    /// Shared gateway client instance
    static let shared = GatewayClient()
}
