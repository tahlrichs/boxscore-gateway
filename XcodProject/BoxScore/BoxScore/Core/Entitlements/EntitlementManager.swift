//
//  EntitlementManager.swift
//  BoxScore
//
//  Manages user entitlements and subscription status using StoreKit 2
//

import Foundation
import StoreKit

/// User subscription tier
enum SubscriptionTier: String, Codable {
    case free
    case pro
    case premium
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .premium: return "Premium"
        }
    }
}

/// User entitlements based on subscription
struct UserEntitlements: Codable {
    let tier: SubscriptionTier
    let isActive: Bool
    let expirationDate: Date?
    
    /// Refresh interval multiplier (lower = faster for paid tiers)
    var refreshMultiplier: Double {
        switch tier {
        case .free: return 1.0
        case .pro: return 0.5
        case .premium: return 0.33
        }
    }
    
    /// Whether fast refresh is available
    var hasFastRefresh: Bool {
        tier != .free && isActive
    }
    
    /// Whether push notifications are enabled
    var hasPushNotifications: Bool {
        tier == .premium && isActive
    }
    
    /// Whether historical data is available
    var hasHistoricalData: Bool {
        tier != .free && isActive
    }
    
    static let free = UserEntitlements(tier: .free, isActive: true, expirationDate: nil)
}

/// Manages user entitlements
@Observable
class EntitlementManager {
    
    // MARK: - Shared Instance
    
    static let shared = EntitlementManager()
    
    // MARK: - Properties
    
    /// Current user entitlements
    private(set) var entitlements: UserEntitlements = .free
    
    /// Whether entitlements are being loaded
    var isLoading: Bool = false
    
    /// Products available for purchase
    private(set) var products: [Product] = []
    
    /// Active subscriptions
    private(set) var activeSubscriptions: [Product.SubscriptionInfo.Status] = []
    
    // MARK: - Product IDs
    
    private let productIds = [
        "com.boxscore.pro.monthly",
        "com.boxscore.pro.yearly",
        "com.boxscore.premium.monthly",
        "com.boxscore.premium.yearly",
    ]
    
    // MARK: - Initialization
    
    init() {
        // Start listening for transaction updates
        Task {
            await startTransactionListener()
            await loadEntitlements()
        }
    }
    
    // MARK: - Public Methods
    
    /// Load user's current entitlements
    @MainActor
    func loadEntitlements() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load products
            products = try await Product.products(for: productIds)
            
            // Check current entitlements
            await updateEntitlements()
        } catch {
            print("Failed to load products: \(error)")
            entitlements = .free
        }
    }
    
    /// Purchase a product
    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateEntitlements()
            await transaction.finish()
            return transaction
            
        case .pending:
            return nil
            
        case .userCancelled:
            return nil
            
        @unknown default:
            return nil
        }
    }
    
    /// Restore purchases
    @MainActor
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updateEntitlements()
    }
    
    // MARK: - Private Methods
    
    private func startTransactionListener() async {
        // Listen for transaction updates
        for await result in Transaction.updates {
            do {
                let transaction = try checkVerified(result)
                await updateEntitlements()
                await transaction.finish()
            } catch {
                print("Transaction verification failed: \(error)")
            }
        }
    }
    
    @MainActor
    private func updateEntitlements() async {
        var highestTier: SubscriptionTier = .free
        var latestExpiration: Date?
        var hasActiveSubscription = false
        
        // Check all transactions
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // Determine tier from product ID
                let tier = tierFromProductId(transaction.productID)
                
                if tier.rawValue > highestTier.rawValue {
                    highestTier = tier
                }
                
                hasActiveSubscription = true
                
                if let expiration = transaction.expirationDate {
                    if latestExpiration == nil || expiration > latestExpiration! {
                        latestExpiration = expiration
                    }
                }
            } catch {
                print("Failed to verify transaction: \(error)")
            }
        }
        
        entitlements = UserEntitlements(
            tier: highestTier,
            isActive: hasActiveSubscription || highestTier == .free,
            expirationDate: latestExpiration
        )
        
        // Update AppConfig
        AppConfig.shared.isPaidUser = highestTier != .free
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }
    
    private func tierFromProductId(_ productId: String) -> SubscriptionTier {
        if productId.contains("premium") {
            return .premium
        } else if productId.contains("pro") {
            return .pro
        }
        return .free
    }
}

// MARK: - Store Errors

enum StoreError: Error, LocalizedError {
    case verificationFailed
    case purchaseFailed
    case productNotFound
    
    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Purchase verification failed"
        case .purchaseFailed:
            return "Purchase could not be completed"
        case .productNotFound:
            return "Product not found"
        }
    }
}

// MARK: - Product Extensions

extension Product {
    var tierName: String {
        if id.contains("premium") {
            return "Premium"
        } else if id.contains("pro") {
            return "Pro"
        }
        return "Free"
    }
    
    var periodName: String {
        if id.contains("monthly") {
            return "Monthly"
        } else if id.contains("yearly") {
            return "Yearly"
        }
        return ""
    }
}
