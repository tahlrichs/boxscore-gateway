//
//  NetworkError.swift
//  BoxScore
//
//  Network error types for the gateway client
//

import Foundation

/// Errors that can occur during network operations
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError(Error)
    case httpError(statusCode: Int, data: Data?)
    case networkUnavailable
    case timeout
    case rateLimited(retryAfter: TimeInterval?)
    case serverError(message: String?)
    case circuitBreakerOpen
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .httpError(let statusCode, _):
            return "HTTP error: \(statusCode)"
        case .networkUnavailable:
            return "Network unavailable. Please check your connection."
        case .timeout:
            return "Request timed out. Please try again."
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited. Please wait \(Int(seconds)) seconds."
            }
            return "Rate limited. Please try again later."
        case .serverError(let message):
            return message ?? "Server error occurred"
        case .circuitBreakerOpen:
            return "Service temporarily unavailable. Please try again shortly."
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
    
    /// Whether this error is recoverable with a retry
    var isRetryable: Bool {
        switch self {
        case .timeout, .networkUnavailable, .serverError:
            return true
        case .httpError(let statusCode, _):
            return statusCode >= 500 || statusCode == 429
        case .rateLimited:
            return true
        default:
            return false
        }
    }
}

/// Response wrapper for gateway API responses
struct GatewayResponse<T: Decodable>: Decodable {
    let data: T
    let lastUpdated: Date?
    let meta: ResponseMeta?
    
    enum CodingKeys: String, CodingKey {
        case data
        case lastUpdated
        case meta
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decode(T.self, forKey: .data)
        
        // Handle ISO8601 date string
        if let dateString = try container.decodeIfPresent(String.self, forKey: .lastUpdated) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            lastUpdated = formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
        } else {
            lastUpdated = nil
        }
        
        meta = try container.decodeIfPresent(ResponseMeta.self, forKey: .meta)
    }
}

/// Metadata included in gateway responses
struct ResponseMeta: Decodable {
    let requestId: String?
    let provider: String?
    let cacheHit: Bool?
    
    enum CodingKeys: String, CodingKey {
        case requestId
        case provider
        case cacheHit
    }
}

/// Error response from gateway
struct GatewayErrorResponse: Decodable {
    let error: String
    let message: String?
    let code: String?
}
