//
//  RosterRepository.swift
//  BoxScore
//
//  Repository for team roster data
//

import Foundation

/// Protocol for roster data access
protocol RosterRepositoryProtocol {
    func getRoster(teamId: String) async throws -> Roster
    func refreshRoster(teamId: String) async throws -> Roster
}

/// Result containing roster data and metadata
struct RosterResult {
    let roster: Roster
    let lastUpdated: Date?
    let isStale: Bool
}

/// Repository for roster data with cache-first strategy
actor RosterRepository: RosterRepositoryProtocol {
    
    // MARK: - Dependencies
    
    private let gatewayClient: GatewayClientProtocol
    private let cacheManager: CacheManager
    private let config: AppConfig
    
    // MARK: - State
    
    private var inFlightRequests: [String: Task<Roster, Error>] = [:]
    
    // MARK: - Initialization
    
    init(
        gatewayClient: GatewayClientProtocol = GatewayClient.shared,
        cacheManager: CacheManager = .shared,
        config: AppConfig = .shared
    ) {
        self.gatewayClient = gatewayClient
        self.cacheManager = cacheManager
        self.config = config
    }
    
    // MARK: - Public Methods
    
    /// Get roster with cache-first strategy
    func getRoster(teamId: String) async throws -> Roster {
        let cacheKey = CacheKey.roster(teamId: teamId)
        
        // Check cache first
        let cacheResult: CacheResult<Roster> = await cacheManager.get(
            key: cacheKey,
            policy: .roster
        )
        
        switch cacheResult {
        case .fresh(let roster, _):
            return roster
            
        case .stale(let roster, _):
            // Trigger background refresh
            Task {
                _ = try? await fetchFromNetwork(teamId: teamId)
            }
            return roster
            
        case .expired, .miss:
            return try await fetchFromNetwork(teamId: teamId)
        }
    }
    
    /// Force refresh from network
    func refreshRoster(teamId: String) async throws -> Roster {
        return try await fetchFromNetwork(teamId: teamId)
    }
    
    /// Get roster with metadata
    func getRosterWithMetadata(teamId: String) async throws -> RosterResult {
        let cacheKey = CacheKey.roster(teamId: teamId)
        let cacheResult: CacheResult<Roster> = await cacheManager.get(
            key: cacheKey,
            policy: .roster
        )
        
        switch cacheResult {
        case .fresh(let roster, let cachedAt):
            return RosterResult(roster: roster, lastUpdated: cachedAt, isStale: false)
            
        case .stale(let roster, let cachedAt):
            Task {
                _ = try? await fetchFromNetwork(teamId: teamId)
            }
            return RosterResult(roster: roster, lastUpdated: cachedAt, isStale: true)
            
        case .expired(let roster, let cachedAt):
            Task {
                _ = try? await fetchFromNetwork(teamId: teamId)
            }
            return RosterResult(roster: roster, lastUpdated: cachedAt, isStale: true)
            
        case .miss:
            let roster = try await fetchFromNetwork(teamId: teamId)
            return RosterResult(roster: roster, lastUpdated: Date(), isStale: false)
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchFromNetwork(teamId: String) async throws -> Roster {
        // Check for in-flight request
        if let existingTask = inFlightRequests[teamId] {
            return try await existingTask.value
        }
        
        let task = Task<Roster, Error> {
            let endpoint = GatewayEndpoint.roster(teamId: teamId)
            let response: RosterAPIResponse = try await gatewayClient.fetch(endpoint)
            
            let roster = Roster(
                teamId: response.teamId,
                players: response.players.map { player in
                    PlayerInfo(
                        id: player.id,
                        name: player.name,
                        jersey: player.jersey,
                        position: player.position,
                        height: player.height,
                        weight: player.weight,
                        birthdate: player.birthdate.flatMap { ISO8601DateFormatter().date(from: $0) },
                        college: player.college
                    )
                },
                lastUpdated: Date()
            )
            
            // Cache the result
            let cacheKey = CacheKey.roster(teamId: teamId)
            await cacheManager.set(key: cacheKey, value: roster, policy: .roster)
            
            return roster
        }
        
        inFlightRequests[teamId] = task
        defer { inFlightRequests.removeValue(forKey: teamId) }
        
        return try await task.value
    }
    
    private func getMockRoster(teamId: String) -> Roster {
        // Generate mock roster based on team
        if teamId.contains("lal") {
            return Roster(
                teamId: teamId,
                players: [
                    PlayerInfo(id: "p1", name: "LeBron James", jersey: "23", position: "SF", height: "6-9", weight: "250", birthdate: nil, college: nil),
                    PlayerInfo(id: "p2", name: "Anthony Davis", jersey: "3", position: "PF", height: "6-10", weight: "253", birthdate: nil, college: "Kentucky"),
                    PlayerInfo(id: "p3", name: "Austin Reaves", jersey: "15", position: "SG", height: "6-5", weight: "197", birthdate: nil, college: "Oklahoma"),
                    PlayerInfo(id: "p4", name: "D'Angelo Russell", jersey: "1", position: "PG", height: "6-4", weight: "193", birthdate: nil, college: "Ohio State"),
                    PlayerInfo(id: "p5", name: "Rui Hachimura", jersey: "28", position: "PF", height: "6-8", weight: "230", birthdate: nil, college: "Gonzaga"),
                ],
                lastUpdated: Date()
            )
        } else if teamId.contains("bos") {
            return Roster(
                teamId: teamId,
                players: [
                    PlayerInfo(id: "p6", name: "Jayson Tatum", jersey: "0", position: "SF", height: "6-8", weight: "210", birthdate: nil, college: "Duke"),
                    PlayerInfo(id: "p7", name: "Jaylen Brown", jersey: "7", position: "SG", height: "6-6", weight: "223", birthdate: nil, college: "California"),
                    PlayerInfo(id: "p8", name: "Derrick White", jersey: "9", position: "PG", height: "6-4", weight: "190", birthdate: nil, college: "Colorado"),
                    PlayerInfo(id: "p9", name: "Jrue Holiday", jersey: "4", position: "PG", height: "6-3", weight: "205", birthdate: nil, college: "UCLA"),
                    PlayerInfo(id: "p10", name: "Kristaps Porzingis", jersey: "8", position: "C", height: "7-2", weight: "240", birthdate: nil, college: nil),
                ],
                lastUpdated: Date()
            )
        } else {
            return Roster(
                teamId: teamId,
                players: [
                    PlayerInfo(id: "p11", name: "Player One", jersey: "1", position: "PG", height: "6-2", weight: "185", birthdate: nil, college: nil),
                    PlayerInfo(id: "p12", name: "Player Two", jersey: "2", position: "SG", height: "6-5", weight: "200", birthdate: nil, college: nil),
                    PlayerInfo(id: "p13", name: "Player Three", jersey: "3", position: "SF", height: "6-7", weight: "215", birthdate: nil, college: nil),
                ],
                lastUpdated: Date()
            )
        }
    }
}

// MARK: - API Response Models

struct RosterAPIResponse: Decodable {
    let teamId: String
    let season: String?
    let lastUpdated: String?
    let players: [PlayerDTO]
}

struct PlayerDTO: Decodable {
    let id: String
    let name: String
    let jersey: String?
    let position: String?
    let height: String?
    let weight: String?
    let birthdate: String?
    let college: String?
}

// MARK: - Shared Instance

extension RosterRepository {
    static let shared = RosterRepository()
}
