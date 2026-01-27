//
//  StandingsRepository.swift
//  BoxScore
//
//  Repository for standings data
//

import Foundation

/// Protocol for standings data access
protocol StandingsRepositoryProtocol {
    func getStandings(sport: Sport, season: String?) async throws -> [Standing]
    func refreshStandings(sport: Sport, season: String?) async throws -> [Standing]
}

/// Result containing standings data and metadata
struct StandingsResult {
    let standings: [Standing]
    let lastUpdated: Date?
    let isStale: Bool
}

/// Repository for standings data with cache-first strategy
actor StandingsRepository: StandingsRepositoryProtocol {
    
    // MARK: - Dependencies
    
    private let gatewayClient: GatewayClientProtocol
    private let cacheManager: CacheManager
    private let config: AppConfig
    
    // MARK: - State
    
    private var inFlightRequests: [String: Task<[Standing], Error>] = [:]
    
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
    
    /// Get standings with cache-first strategy
    func getStandings(sport: Sport, season: String? = nil) async throws -> [Standing] {
        let cacheKey = CacheKey.standings(sport: sport, season: season)
        
        // Check cache first
        let cacheResult: CacheResult<[Standing]> = await cacheManager.get(
            key: cacheKey,
            policy: .standings
        )
        
        switch cacheResult {
        case .fresh(let standings, _):
            return standings
            
        case .stale(let standings, _):
            // Trigger background refresh
            Task {
                _ = try? await fetchFromNetwork(sport: sport, season: season)
            }
            return standings
            
        case .expired, .miss:
            return try await fetchFromNetwork(sport: sport, season: season)
        }
    }
    
    /// Force refresh from network
    func refreshStandings(sport: Sport, season: String? = nil) async throws -> [Standing] {
        return try await fetchFromNetwork(sport: sport, season: season)
    }
    
    /// Get standings with metadata
    func getStandingsWithMetadata(sport: Sport, season: String? = nil) async throws -> StandingsResult {
        let cacheKey = CacheKey.standings(sport: sport, season: season)
        let cacheResult: CacheResult<[Standing]> = await cacheManager.get(
            key: cacheKey,
            policy: .standings
        )
        
        switch cacheResult {
        case .fresh(let standings, let cachedAt):
            return StandingsResult(standings: standings, lastUpdated: cachedAt, isStale: false)
            
        case .stale(let standings, let cachedAt):
            Task {
                _ = try? await fetchFromNetwork(sport: sport, season: season)
            }
            return StandingsResult(standings: standings, lastUpdated: cachedAt, isStale: true)
            
        case .expired(let standings, let cachedAt):
            Task {
                _ = try? await fetchFromNetwork(sport: sport, season: season)
            }
            return StandingsResult(standings: standings, lastUpdated: cachedAt, isStale: true)
            
        case .miss:
            let standings = try await fetchFromNetwork(sport: sport, season: season)
            return StandingsResult(standings: standings, lastUpdated: Date(), isStale: false)
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchFromNetwork(sport: Sport, season: String?) async throws -> [Standing] {
        let requestKey = "\(sport.leagueId)_\(season ?? "current")"
        
        // Check for in-flight request
        if let existingTask = inFlightRequests[requestKey] {
            return try await existingTask.value
        }
        
        let task = Task<[Standing], Error> {
            let endpoint = GatewayEndpoint.standings(league: sport.leagueId, season: season)
            let response: StandingsAPIResponse = try await gatewayClient.fetch(endpoint)
            
            // Flatten conferences into standings array
            var standings: [Standing] = []
            for conference in response.conferences {
                for team in conference.teams {
                    // Use team.conference if available (for division groupings), otherwise use conference.name
                    let confName = team.conference ?? conference.name
                    standings.append(Standing(
                        teamId: team.teamId,
                        leagueId: sport.leagueId,
                        season: response.season,
                        wins: team.wins,
                        losses: team.losses,
                        ties: team.ties,
                        winPct: team.winPct,
                        rank: team.rank,
                        conference: confName,
                        division: team.division,
                        gamesBack: team.gamesBack,
                        streak: team.streak,
                        lastTen: team.lastTen,
                        teamAbbrev: team.abbrev,
                        teamName: team.name
                    ))
                }
            }
            
            // Cache the result
            let cacheKey = CacheKey.standings(sport: sport, season: season)
            await cacheManager.set(key: cacheKey, value: standings, policy: .standings)
            
            return standings
        }
        
        inFlightRequests[requestKey] = task
        defer { inFlightRequests.removeValue(forKey: requestKey) }
        
        return try await task.value
    }
    
    private func getMockStandings(sport: Sport) -> [Standing] {
        // Generate mock standings
        switch sport {
        case .nba:
            return generateNBAMockStandings()
        case .nfl:
            return generateNFLMockStandings()
        default:
            return []
        }
    }
    
    private func generateNBAMockStandings() -> [Standing] {
        let eastTeams = [
            ("BOS", "Celtics", 32, 12),
            ("MIL", "Bucks", 30, 14),
            ("CLE", "Cavaliers", 29, 14),
            ("MIA", "Heat", 27, 17),
            ("NYK", "Knicks", 26, 18),
            ("PHI", "76ers", 25, 19),
            ("IND", "Pacers", 24, 20),
            ("BKN", "Nets", 22, 22),
        ]
        
        let westTeams = [
            ("DEN", "Nuggets", 33, 11),
            ("OKC", "Thunder", 32, 12),
            ("MIN", "Timberwolves", 30, 14),
            ("LAL", "Lakers", 28, 16),
            ("LAC", "Clippers", 27, 17),
            ("PHX", "Suns", 26, 18),
            ("SAC", "Kings", 25, 19),
            ("GSW", "Warriors", 24, 20),
        ]
        
        var standings: [Standing] = []
        
        for (index, team) in eastTeams.enumerated() {
            standings.append(Standing(
                teamId: "nba_\(team.0.lowercased())",
                leagueId: "nba",
                season: "2025-26",
                wins: team.2,
                losses: team.3,
                ties: nil,
                winPct: Double(team.2) / Double(team.2 + team.3),
                rank: index + 1,
                conference: "Eastern",
                division: nil,
                gamesBack: index == 0 ? 0 : Double(index) * 2,
                streak: index % 2 == 0 ? "W3" : "L1",
                lastTen: "7-3",
                teamAbbrev: team.0,
                teamName: team.1
            ))
        }
        
        for (index, team) in westTeams.enumerated() {
            standings.append(Standing(
                teamId: "nba_\(team.0.lowercased())",
                leagueId: "nba",
                season: "2025-26",
                wins: team.2,
                losses: team.3,
                ties: nil,
                winPct: Double(team.2) / Double(team.2 + team.3),
                rank: index + 1,
                conference: "Western",
                division: nil,
                gamesBack: index == 0 ? 0 : Double(index) * 2,
                streak: index % 2 == 0 ? "W2" : "L2",
                lastTen: "6-4",
                teamAbbrev: team.0,
                teamName: team.1
            ))
        }
        
        return standings
    }
    
    private func generateNFLMockStandings() -> [Standing] {
        let afcTeams = [
            ("KC", "Chiefs", 12, 4),
            ("BUF", "Bills", 11, 5),
            ("BAL", "Ravens", 10, 6),
            ("MIA", "Dolphins", 9, 7),
        ]
        
        let nfcTeams = [
            ("SF", "49ers", 12, 4),
            ("DAL", "Cowboys", 11, 5),
            ("PHI", "Eagles", 10, 6),
            ("DET", "Lions", 9, 7),
        ]
        
        var standings: [Standing] = []
        
        for (index, team) in afcTeams.enumerated() {
            standings.append(Standing(
                teamId: "nfl_\(team.0.lowercased())",
                leagueId: "nfl",
                season: "2025",
                wins: team.2,
                losses: team.3,
                ties: 0,
                winPct: Double(team.2) / Double(team.2 + team.3),
                rank: index + 1,
                conference: "AFC",
                division: nil,
                gamesBack: nil,
                streak: "W2",
                lastTen: nil,
                teamAbbrev: team.0,
                teamName: team.1
            ))
        }
        
        for (index, team) in nfcTeams.enumerated() {
            standings.append(Standing(
                teamId: "nfl_\(team.0.lowercased())",
                leagueId: "nfl",
                season: "2025",
                wins: team.2,
                losses: team.3,
                ties: 0,
                winPct: Double(team.2) / Double(team.2 + team.3),
                rank: index + 1,
                conference: "NFC",
                division: nil,
                gamesBack: nil,
                streak: "W1",
                lastTen: nil,
                teamAbbrev: team.0,
                teamName: team.1
            ))
        }
        
        return standings
    }

    // MARK: - Rankings (College Sports)

    /// Get AP Top 25 or Coaches Poll rankings for college sports
    func getRankings(sport: Sport, poll: String? = nil) async throws -> [RankedTeam] {
        // Only college sports have rankings
        guard sport.isCollegeSport else {
            throw RepositoryError.invalidSport("Rankings are only available for college sports")
        }

        let endpoint = GatewayEndpoint.rankings(league: sport.leagueId, poll: poll)
        let response: RankingsAPIResponse = try await gatewayClient.fetch(endpoint)

        return response.teams.map { dto in
            RankedTeam(
                teamId: dto.teamId,
                abbrev: dto.abbrev,
                name: dto.name,
                location: dto.location,
                rank: dto.rank,
                previousRank: dto.previousRank,
                record: dto.record,
                trend: dto.trend,
                points: dto.points,
                firstPlaceVotes: dto.firstPlaceVotes,
                logoUrl: dto.logoUrl
            )
        }
    }
}

// MARK: - Repository Errors

enum RepositoryError: LocalizedError {
    case invalidSport(String)

    var errorDescription: String? {
        switch self {
        case .invalidSport(let message):
            return message
        }
    }
}

// MARK: - API Response Models

struct StandingsAPIResponse: Decodable {
    let league: String
    let season: String
    let lastUpdated: String?
    let conferences: [ConferenceStandingsDTO]
}

struct ConferenceStandingsDTO: Decodable {
    let name: String
    let teams: [StandingDTO]
}

struct StandingDTO: Decodable {
    let teamId: String
    let abbrev: String
    let name: String
    let wins: Int
    let losses: Int
    let ties: Int?
    let winPct: Double
    let rank: Int
    let gamesBack: Double?
    let streak: String?
    let lastTen: String?
    let conference: String?
    let division: String?
    let divisionRank: Int?
    let playoffSeed: Int?
    let homeRecord: String?
    let awayRecord: String?
    let conferenceRecord: String?
    let pointsFor: Int?
    let pointsAgainst: Int?
}

// MARK: - Rankings API Response

struct RankingsAPIResponse: Decodable {
    let league: String
    let pollName: String
    let season: String
    let week: Int
    let lastUpdated: String?
    let teams: [RankedTeamDTO]
}

struct RankedTeamDTO: Decodable {
    let teamId: String
    let abbrev: String
    let name: String
    let location: String
    let rank: Int
    let previousRank: Int?
    let record: String
    let trend: String?
    let points: Double?
    let firstPlaceVotes: Int?
    let logoUrl: String?
}

// MARK: - Shared Instance

extension StandingsRepository {
    static let shared = StandingsRepository()
}
