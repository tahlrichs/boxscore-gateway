//
//  TeamsRepository.swift
//  BoxScore
//
//  Repository for teams data
//

import Foundation

/// Protocol for teams data access
protocol TeamsRepositoryProtocol {
    func getTeams(sport: Sport) async throws -> [TeamItem]
}

/// Result containing teams data and metadata
struct TeamsResult {
    let teams: [TeamItem]
    let lastUpdated: Date?
    let isStale: Bool
}

/// Team item for display in lists
struct TeamItem: Identifiable, Codable, Equatable, Sendable, Hashable {
    let id: String
    let abbrev: String
    let name: String
    let city: String
    let logoURL: String?
    let primaryColor: String?
    let conference: String?
    let division: String?

    var fullName: String {
        "\(city) \(name)"
    }
}

/// Repository for teams data with cache-first strategy
actor TeamsRepository: TeamsRepositoryProtocol {

    // MARK: - Dependencies

    private let gatewayClient: GatewayClientProtocol
    private let cacheManager: CacheManager

    // MARK: - State

    private var inFlightRequests: [String: Task<[TeamItem], Error>] = [:]

    // MARK: - Initialization

    init(
        gatewayClient: GatewayClientProtocol = GatewayClient.shared,
        cacheManager: CacheManager = .shared
    ) {
        self.gatewayClient = gatewayClient
        self.cacheManager = cacheManager
    }

    // MARK: - Public Methods

    /// Get teams for a sport with cache-first strategy
    func getTeams(sport: Sport) async throws -> [TeamItem] {
        let cacheKey = CacheKey.teams(sport: sport)

        // Check cache first (teams are cached for 7 days)
        let cacheResult: CacheResult<[TeamItem]> = await cacheManager.get(
            key: cacheKey,
            policy: .teams
        )

        switch cacheResult {
        case .fresh(let teams, _):
            return teams

        case .stale(let teams, _):
            // Trigger background refresh
            Task {
                _ = try? await fetchFromNetwork(sport: sport)
            }
            return teams

        case .expired, .miss:
            return try await fetchFromNetwork(sport: sport)
        }
    }

    /// Get teams with metadata
    func getTeamsWithMetadata(sport: Sport) async throws -> TeamsResult {
        let cacheKey = CacheKey.teams(sport: sport)
        let cacheResult: CacheResult<[TeamItem]> = await cacheManager.get(
            key: cacheKey,
            policy: .teams
        )

        switch cacheResult {
        case .fresh(let teams, let cachedAt):
            return TeamsResult(teams: teams, lastUpdated: cachedAt, isStale: false)

        case .stale(let teams, let cachedAt):
            Task {
                _ = try? await fetchFromNetwork(sport: sport)
            }
            return TeamsResult(teams: teams, lastUpdated: cachedAt, isStale: true)

        case .expired(let teams, let cachedAt):
            Task {
                _ = try? await fetchFromNetwork(sport: sport)
            }
            return TeamsResult(teams: teams, lastUpdated: cachedAt, isStale: true)

        case .miss:
            let teams = try await fetchFromNetwork(sport: sport)
            return TeamsResult(teams: teams, lastUpdated: Date(), isStale: false)
        }
    }

    // MARK: - Private Methods

    private func fetchFromNetwork(sport: Sport) async throws -> [TeamItem] {
        let requestKey = sport.leagueId

        // Check for in-flight request
        if let existingTask = inFlightRequests[requestKey] {
            return try await existingTask.value
        }

        let task = Task<[TeamItem], Error> {
            let endpoint = GatewayEndpoint.teams(league: sport.leagueId)
            let response: TeamsAPIResponse = try await gatewayClient.fetch(endpoint)

            let teams = response.teams.map { (dto: TeamsListTeamDTO) in
                TeamItem(
                    id: dto.id,
                    abbrev: dto.abbrev,
                    name: dto.name,
                    city: dto.city,
                    logoURL: dto.logoURL,
                    primaryColor: dto.primaryColor,
                    conference: dto.conference,
                    division: dto.division
                )
            }

            // Cache the result
            let cacheKey = CacheKey.teams(sport: sport)
            await cacheManager.set(key: cacheKey, value: teams, policy: .teams)

            return teams
        }

        inFlightRequests[requestKey] = task
        defer { inFlightRequests.removeValue(forKey: requestKey) }

        return try await task.value
    }
}

// MARK: - API Response Models

struct TeamsAPIResponse: Decodable {
    let league: String
    let teams: [TeamsListTeamDTO]
    let lastUpdated: String
}

struct TeamsListTeamDTO: Decodable {
    let id: String
    let abbrev: String
    let name: String
    let city: String
    let logoURL: String?
    let primaryColor: String?
    let conference: String?
    let division: String?
}

// MARK: - Shared Instance

extension TeamsRepository {
    static let shared = TeamsRepository()
}
