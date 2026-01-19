//
//  CacheManager.swift
//  BoxScore
//
//  Two-layer cache: in-memory (fast) + persistent (CoreData/file)
//

import Foundation

/// Protocol for cache operations
protocol CacheManagerProtocol: Sendable {
    func get<T: Codable & Sendable>(key: String, policy: CachePolicy) async -> CacheResult<T>
    func set<T: Codable & Sendable>(key: String, value: T, policy: CachePolicy) async
    func remove(key: String) async
    func clear() async
    func clearExpired() async
}

/// Two-layer cache manager with memory and persistent storage
actor CacheManager: CacheManagerProtocol {
    
    // MARK: - Shared Instance
    
    static let shared = CacheManager()
    
    // MARK: - Properties
    
    /// In-memory cache for fast access
    private var memoryCache: [String: Any] = [:]
    
    /// Timestamps for memory cache entries
    private var memoryCacheTimestamps: [String: Date] = [:]
    
    /// File manager for persistent cache
    private let fileManager = FileManager.default
    
    /// Cache directory URL
    private lazy var cacheDirectory: URL = {
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let cacheDir = paths[0].appendingPathComponent("BoxScoreCache", isDirectory: true)
        
        if !fileManager.fileExists(atPath: cacheDir.path) {
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        
        return cacheDir
    }()
    
    /// JSON encoder for serialization
    private let encoder = JSONEncoder()
    
    /// JSON decoder for deserialization
    private let decoder = JSONDecoder()
    
    /// Maximum memory cache entries
    private let maxMemoryCacheEntries = 100
    
    // MARK: - Initialization
    
    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - Public Methods
    
    /// Get cached data for a key
    func get<T: Codable & Sendable>(key: String, policy: CachePolicy) async -> CacheResult<T> {
        // Check memory cache first (fastest)
        if let entry = memoryCache[key] as? CacheEntry<T> {
            let result = entry.checkFreshness(for: policy)
            if result.isUsable {
                return result
            }
        }
        
        // Check persistent cache if policy allows
        guard policy.shouldPersist else {
            return .miss
        }
        
        if let entry: CacheEntry<T> = loadFromDisk(key: key) {
            let result = entry.checkFreshness(for: policy)
            
            // Populate memory cache if usable
            if result.isUsable {
                memoryCache[key] = entry
                memoryCacheTimestamps[key] = Date()
            }
            
            return result
        }
        
        return .miss
    }
    
    /// Set cached data for a key
    func set<T: Codable & Sendable>(key: String, value: T, policy: CachePolicy) async {
        let entry = CacheEntry(data: value, policy: policy)
        
        // Always update memory cache
        memoryCache[key] = entry
        memoryCacheTimestamps[key] = Date()
        
        // Evict old entries if needed
        await evictMemoryCacheIfNeeded()
        
        // Persist to disk if policy allows
        if policy.shouldPersist {
            saveToDisk(key: key, entry: entry)
        }
    }
    
    /// Remove cached data for a key
    func remove(key: String) async {
        memoryCache.removeValue(forKey: key)
        memoryCacheTimestamps.removeValue(forKey: key)
        removeFromDisk(key: key)
    }
    
    /// Clear all cached data
    func clear() async {
        memoryCache.removeAll()
        memoryCacheTimestamps.removeAll()
        clearDiskCache()
    }
    
    /// Clear only expired entries
    func clearExpired() async {
        // Clear expired memory cache entries
        let now = Date()
        var keysToRemove: [String] = []
        
        for (key, timestamp) in memoryCacheTimestamps {
            // Remove entries older than 1 hour from memory (regardless of policy)
            if now.timeIntervalSince(timestamp) > 3600 {
                keysToRemove.append(key)
            }
        }
        
        for key in keysToRemove {
            memoryCache.removeValue(forKey: key)
            memoryCacheTimestamps.removeValue(forKey: key)
        }
        
        // Clear old disk cache files
        clearOldDiskCacheFiles()
    }
    
    // MARK: - Memory Cache Management
    
    private func evictMemoryCacheIfNeeded() {
        guard memoryCache.count > maxMemoryCacheEntries else { return }
        
        // Remove oldest entries
        let sortedKeys = memoryCacheTimestamps
            .sorted { $0.value < $1.value }
            .prefix(memoryCache.count - maxMemoryCacheEntries)
            .map { $0.key }
        
        for key in sortedKeys {
            memoryCache.removeValue(forKey: key)
            memoryCacheTimestamps.removeValue(forKey: key)
        }
    }
    
    // MARK: - Disk Cache Operations
    
    private func fileURL(for key: String) -> URL {
        let sanitizedKey = key
            .replacingOccurrences(of: ":", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        return cacheDirectory.appendingPathComponent("\(sanitizedKey).cache")
    }
    
    private func loadFromDisk<T: Codable & Sendable>(key: String) -> CacheEntry<T>? {
        let url = fileURL(for: key)
        
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        return try? decoder.decode(CacheEntry<T>.self, from: data)
    }
    
    private func saveToDisk<T: Codable & Sendable>(key: String, entry: CacheEntry<T>) {
        let url = fileURL(for: key)
        
        guard let data = try? encoder.encode(entry) else {
            return
        }
        
        try? data.write(to: url, options: .atomic)
    }
    
    private func removeFromDisk(key: String) {
        let url = fileURL(for: key)
        try? fileManager.removeItem(at: url)
    }
    
    private func clearDiskCache() {
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    private func clearOldDiskCacheFiles() {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) else { return }
        
        let oldDate = Date().addingTimeInterval(-7 * 24 * 60 * 60) // 7 days ago
        
        for fileURL in files {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let modDate = attributes[.modificationDate] as? Date,
                  modDate < oldDate else {
                continue
            }
            
            try? fileManager.removeItem(at: fileURL)
        }
    }
}

// MARK: - Convenience Extensions

extension CacheManager {
    
    /// Get scoreboard from cache
    func getScoreboard(sport: Sport, date: Date) async -> CacheResult<[Game]> {
        let key = CacheKey.scoreboard(sport: sport, date: date)
        return await get(key: key, policy: .scoreboard)
    }
    
    /// Cache scoreboard
    func setScoreboard(_ games: [Game], sport: Sport, date: Date) async {
        let key = CacheKey.scoreboard(sport: sport, date: date)
        await set(key: key, value: games, policy: .scoreboard)
    }
    
    /// Get game from cache
    func getGame(id: String) async -> CacheResult<Game> {
        let key = CacheKey.game(id: id)
        return await get(key: key, policy: .liveGame)
    }
    
    /// Cache game
    func setGame(_ game: Game) async {
        let key = CacheKey.game(id: game.id)
        let policy: CachePolicy = game.status.isLive ? .liveGame : .finalBoxScore
        await set(key: key, value: game, policy: policy)
    }
    
    /// Get standings from cache
    func getStandings(sport: Sport, season: String?) async -> CacheResult<[Standing]> {
        let key = CacheKey.standings(sport: sport, season: season)
        return await get(key: key, policy: .standings)
    }
    
    /// Cache standings
    func setStandings(_ standings: [Standing], sport: Sport, season: String?) async {
        let key = CacheKey.standings(sport: sport, season: season)
        await set(key: key, value: standings, policy: .standings)
    }
}
