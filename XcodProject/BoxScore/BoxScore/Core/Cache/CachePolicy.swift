//
//  CachePolicy.swift
//  BoxScore
//
//  Cache policy definitions with TTL and staleness rules
//

import Foundation

/// Defines caching behavior for different data types
enum CachePolicy: Sendable {
    /// Live game state - very short TTL
    case liveGame
    
    /// Scoreboard list of games
    case scoreboard
    
    /// Box score for live games
    case liveBoxScore
    
    /// Box score for final games
    case finalBoxScore
    
    /// League standings
    case standings
    
    /// Team rosters
    case roster
    
    /// Game schedule
    case schedule
    
    /// Team metadata
    case teamMetadata
    
    /// Never cache
    case none
    
    /// Time-to-live in seconds
    var ttl: TimeInterval {
        let config = AppConfig.shared
        switch self {
        case .liveGame:
            return config.liveGameTTL
        case .scoreboard:
            return config.scoreboardTTL
        case .liveBoxScore:
            return config.liveBoxScoreTTL
        case .finalBoxScore:
            return config.finalBoxScoreTTL
        case .standings:
            return config.standingsTTL
        case .roster:
            return config.rosterTTL
        case .schedule:
            return config.scheduleTTL
        case .teamMetadata:
            return 30 * 24 * 60 * 60 // 30 days
        case .none:
            return 0
        }
    }
    
    /// Whether to persist to disk
    var shouldPersist: Bool {
        switch self {
        case .liveGame:
            return false // Memory only for fastest updates
        case .scoreboard, .liveBoxScore:
            return true // Persist for offline access
        case .finalBoxScore, .standings, .roster, .schedule, .teamMetadata:
            return true
        case .none:
            return false
        }
    }
    
    /// Maximum age before data is considered "stale" but still usable
    var staleThreshold: TimeInterval {
        switch self {
        case .liveGame, .liveBoxScore:
            return ttl * 2
        case .scoreboard:
            return ttl * 3
        case .finalBoxScore, .standings, .roster, .schedule, .teamMetadata:
            return ttl * 2
        case .none:
            return 0
        }
    }
}

/// Result of cache lookup
enum CacheResult<T: Sendable>: Sendable {
    /// Fresh data within TTL
    case fresh(T, cachedAt: Date)
    
    /// Stale data beyond TTL but within stale threshold
    case stale(T, cachedAt: Date)
    
    /// Expired data beyond stale threshold
    case expired(T, cachedAt: Date)
    
    /// No cached data found
    case miss
    
    /// The cached data, if any
    var data: T? {
        switch self {
        case .fresh(let data, _), .stale(let data, _), .expired(let data, _):
            return data
        case .miss:
            return nil
        }
    }
    
    /// Whether the cached data is usable (fresh or stale)
    var isUsable: Bool {
        switch self {
        case .fresh, .stale:
            return true
        case .expired, .miss:
            return false
        }
    }
    
    /// Whether a refresh is needed
    var needsRefresh: Bool {
        switch self {
        case .fresh:
            return false
        case .stale, .expired, .miss:
            return true
        }
    }
}

/// Cache entry wrapper
struct CacheEntry<T: Codable & Sendable>: Codable, Sendable {
    let data: T
    let cachedAt: Date
    let policy: String // CachePolicy raw value for serialization
    
    init(data: T, cachedAt: Date = Date(), policy: CachePolicy) {
        self.data = data
        self.cachedAt = cachedAt
        self.policy = String(describing: policy)
    }
    
    /// Check the freshness of this cache entry
    func checkFreshness(for policy: CachePolicy) -> CacheResult<T> {
        let age = Date().timeIntervalSince(cachedAt)
        
        if age <= policy.ttl {
            return .fresh(data, cachedAt: cachedAt)
        } else if age <= policy.staleThreshold {
            return .stale(data, cachedAt: cachedAt)
        } else {
            return .expired(data, cachedAt: cachedAt)
        }
    }
}

/// Cache key generator
enum CacheKey {
    static func scoreboard(sport: Sport, date: Date) -> String {
        let dateString = dateFormatter.string(from: date)
        return "scoreboard:\(sport.leagueId):\(dateString)"
    }
    
    static func game(id: String) -> String {
        return "game:\(id)"
    }
    
    static func boxScore(gameId: String) -> String {
        return "boxscore:\(gameId)"
    }
    
    static func standings(sport: Sport, season: String?) -> String {
        return "standings:\(sport.leagueId):\(season ?? "current")"
    }
    
    static func roster(teamId: String) -> String {
        return "roster:\(teamId)"
    }
    
    static func schedule(sport: Sport, startDate: Date, endDate: Date) -> String {
        let start = dateFormatter.string(from: startDate)
        let end = dateFormatter.string(from: endDate)
        return "schedule:\(sport.leagueId):\(start):\(end)"
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()
}
