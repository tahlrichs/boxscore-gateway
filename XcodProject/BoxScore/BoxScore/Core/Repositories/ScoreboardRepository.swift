//
//  ScoreboardRepository.swift
//  BoxScore
//
//  Repository for scoreboard data - orchestrates cache and network
//

import Foundation

/// Protocol for scoreboard data access
protocol ScoreboardRepositoryProtocol {
    func getScoreboard(sport: Sport, date: Date) async throws -> [Game]
    func getScoreboard(sport: Sport, date: Date, forceRefresh: Bool) async throws -> [Game]
    func refreshScoreboard(sport: Sport, date: Date) async throws -> [Game]
    func getAvailableDates(sport: Sport) async throws -> [String]
}

/// Result containing data and metadata about freshness
struct ScoreboardResult {
    let games: [Game]
    let lastUpdated: Date?
    let isStale: Bool
    let source: DataSource
    
    enum DataSource {
        case cache
        case network
    }
}

/// Repository for scoreboard data with cache-first strategy
actor ScoreboardRepository: ScoreboardRepositoryProtocol {
    
    // MARK: - Dependencies
    
    private let gatewayClient: GatewayClientProtocol
    private let cacheManager: CacheManager
    private let config: AppConfig
    
    // MARK: - State
    
    /// Track in-flight requests to avoid duplicate fetches
    private var inFlightRequests: [String: Task<[Game], Error>] = [:]
    
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
    
    /// Get scoreboard with cache-first strategy
    func getScoreboard(sport: Sport, date: Date) async throws -> [Game] {
        try await getScoreboard(sport: sport, date: date, forceRefresh: false)
    }
    
    /// Get scoreboard with option to force refresh
    func getScoreboard(sport: Sport, date: Date, forceRefresh: Bool) async throws -> [Game] {
        // Check if we should use mock data
        if config.useMockData {
            return getMockData(sport: sport, date: date)
        }
        
        let cacheKey = CacheKey.scoreboard(sport: sport, date: date)
        
        // Check cache first (unless forcing refresh)
        if !forceRefresh {
            let cacheResult: CacheResult<[Game]> = await cacheManager.get(
                key: cacheKey,
                policy: .scoreboard
            )
            
            switch cacheResult {
            case .fresh(let games, _):
                // Fresh cache hit - return immediately
                return games
                
            case .stale(let games, _):
                // Stale data - return immediately but trigger background refresh
                Task {
                    _ = try? await fetchFromNetwork(sport: sport, date: date)
                }
                return games
                
            case .expired, .miss:
                // Need fresh data
                break
            }
        }
        
        // Fetch from network
        return try await fetchFromNetwork(sport: sport, date: date)
    }
    
    /// Force refresh from network
    func refreshScoreboard(sport: Sport, date: Date) async throws -> [Game] {
        try await getScoreboard(sport: sport, date: date, forceRefresh: true)
    }
    
    /// Get extended result with metadata
    func getScoreboardWithMetadata(sport: Sport, date: Date) async throws -> ScoreboardResult {
        if config.useMockData {
            let games = getMockData(sport: sport, date: date)
            return ScoreboardResult(games: games, lastUpdated: Date(), isStale: false, source: .cache)
        }

        let cacheKey = CacheKey.scoreboard(sport: sport, date: date)
        let cacheResult: CacheResult<[Game]> = await cacheManager.get(
            key: cacheKey,
            policy: .scoreboard
        )

        switch cacheResult {
        case .fresh(let games, let cachedAt):
            return ScoreboardResult(games: games, lastUpdated: cachedAt, isStale: false, source: .cache)

        case .stale(let games, let cachedAt):
            // Trigger background refresh
            Task {
                _ = try? await fetchFromNetwork(sport: sport, date: date)
            }
            return ScoreboardResult(games: games, lastUpdated: cachedAt, isStale: true, source: .cache)

        case .expired(let games, let cachedAt):
            // Return expired data but fetch new
            Task {
                _ = try? await fetchFromNetwork(sport: sport, date: date)
            }
            return ScoreboardResult(games: games, lastUpdated: cachedAt, isStale: true, source: .cache)

        case .miss:
            let games = try await fetchFromNetwork(sport: sport, date: date)
            return ScoreboardResult(games: games, lastUpdated: Date(), isStale: false, source: .network)
        }
    }

    /// Get available dates for a sport (dates that have games)
    func getAvailableDates(sport: Sport) async throws -> [String] {
        let endpoint = GatewayEndpoint.availableDates(league: sport.leagueId)
        let response: AvailableDatesResponse = try await gatewayClient.fetch(endpoint)
        return response.data
    }

    // MARK: - Golf Methods

    /// Get golf scoreboard for a specific week and tour
    func getGolfScoreboard(tour: String, weekStart: Date) async throws -> GolfScoreboardResponse {
        let endpoint = GatewayEndpoint.golfScoreboard(tour: tour, weekStart: weekStart)
        // GatewayClient already unwraps the "data" field, so we decode directly to GolfScoreboardResponse
        let response: GolfScoreboardResponse = try await gatewayClient.fetch(endpoint)
        return response
    }

    /// Get full tournament leaderboard
    func getGolfLeaderboard(tournamentId: String) async throws -> GolfTournament {
        let endpoint = GatewayEndpoint.golfLeaderboard(tournamentId: tournamentId)
        // GatewayClient already unwraps the "data" field, so we decode directly to GolfTournament
        let response: GolfTournament = try await gatewayClient.fetch(endpoint)
        return response
    }

    // MARK: - Private Methods
    
    private func fetchFromNetwork(sport: Sport, date: Date) async throws -> [Game] {
        let requestKey = "\(sport.leagueId)_\(date.timeIntervalSince1970)"
        
        // Check for in-flight request to avoid duplicate fetches
        if let existingTask = inFlightRequests[requestKey] {
            return try await existingTask.value
        }
        
        // Create new fetch task
        let task = Task<[Game], Error> {
            let endpoint = GatewayEndpoint.scoreboard(league: sport.leagueId, date: date)
            let response: ScoreboardResponse = try await gatewayClient.fetch(endpoint)
            
            // Parse the scoreboard date from the response
            // Use the user's calendar to ensure the date is interpreted correctly
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.calendar = Calendar.current
            dateFormatter.timeZone = Calendar.current.timeZone
            let scoreboardDate = dateFormatter.date(from: response.date) ?? date

            // Transform to domain models, passing the scoreboard date
            let games = response.games.map { $0.toDomain(sport: sport, scoreboardDate: scoreboardDate) }
            
            // Cache the result
            await cacheManager.setScoreboard(games, sport: sport, date: date)
            
            return games
        }
        
        inFlightRequests[requestKey] = task
        
        defer {
            inFlightRequests.removeValue(forKey: requestKey)
        }
        
        return try await task.value
    }
    
    private func getMockData(sport: Sport, date: Date) -> [Game] {
        switch sport {
        case .nba:
            return NBAMockData.allGames.filter { game in
                Calendar.current.isDate(game.gameDate, inSameDayAs: date)
            }
        case .nfl:
            return NFLMockData.allGames.filter { game in
                Calendar.current.isDate(game.gameDate, inSameDayAs: date)
            }
        case .nhl:
            return NHLMockData.allGames.filter { game in
                Calendar.current.isDate(game.gameDate, inSameDayAs: date)
            }
        default:
            return []
        }
    }
}

// MARK: - API Response Models

/// Response model for scoreboard endpoint
struct ScoreboardResponse: Decodable {
    let league: String
    let date: String
    let lastUpdated: String?
    let games: [GameDTO]
}

/// Helper to parse ISO8601 dates with or without seconds
private func parseISO8601Date(_ string: String) -> Date? {
    // Try with full format first (with seconds)
    let formatterWithSeconds = ISO8601DateFormatter()
    formatterWithSeconds.formatOptions = [.withInternetDateTime]
    if let date = formatterWithSeconds.date(from: string) {
        return date
    }
    
    // Try without seconds (e.g., "2026-01-15T19:00Z")
    let formatterWithoutSeconds = ISO8601DateFormatter()
    formatterWithoutSeconds.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withTimeZone]
    if let date = formatterWithoutSeconds.date(from: string) {
        return date
    }
    
    // Fallback: Try DateFormatter with explicit format
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.timeZone = TimeZone(identifier: "UTC")
    
    // Try format without seconds
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mmX"
    if let date = dateFormatter.date(from: string) {
        return date
    }
    
    // Try format with seconds
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssX"
    return dateFormatter.date(from: string)
}

/// Data transfer object for game
struct GameDTO: Decodable {
    let id: String
    let startTime: String
    let status: String
    let period: String?
    let clock: String?
    let overtimePeriods: Int?
    let venue: VenueDTO?
    let homeTeam: TeamDTO
    let awayTeam: TeamDTO
    let externalIds: [String: String]?
    
    func toDomain(sport: Sport, scoreboardDate: Date? = nil) -> Game {
        let gameStatus = parseStatus()

        // Use the scoreboard date if provided (from scoreboard endpoint)
        // Otherwise fall back to parsing startTime (for individual game endpoints)
        let gameDate: Date
        if let scoreboardDate = scoreboardDate {
            gameDate = scoreboardDate
        } else {
            gameDate = parseISO8601Date(startTime) ?? Date()
        }

        return Game(
            id: id,
            sport: sport,
            gameDate: gameDate,
            status: gameStatus,
            awayTeam: awayTeam.toDomain(),
            homeTeam: homeTeam.toDomain(),
            awayScore: awayTeam.score,
            homeScore: homeTeam.score,
            awayBoxScore: createEmptyBoxScore(sport: sport, teamId: awayTeam.id, teamName: awayTeam.name),
            homeBoxScore: createEmptyBoxScore(sport: sport, teamId: homeTeam.id, teamName: homeTeam.name),
            venue: venue?.toDomain(),
            lastUpdated: Date(),
            externalIds: externalIds
        )
    }
    
    private func parseStatus() -> GameStatus {
        switch status.lowercased() {
        case "scheduled", "pre":
            let date = parseISO8601Date(startTime) ?? Date()
            return .scheduled(date: date)
        case "live", "in_progress", "inprogress":
            return .live(period: period ?? "", clock: clock ?? "")
        case "final", "finished", "complete":
            if let ot = overtimePeriods, ot > 0 {
                return .finalOvertime(periods: ot)
            }
            return .final
        default:
            return .final
        }
    }
    
    private func createEmptyBoxScore(sport: Sport, teamId: String, teamName: String) -> BoxScorePayload {
        switch sport {
        case .nba, .ncaam:
            return .nba(NBATeamBoxScore(
                teamId: teamId,
                teamName: teamName,
                starters: [],
                bench: [],
                dnp: [],
                teamTotals: NBATeamTotals(
                    minutes: 0, points: 0, fgMade: 0, fgAttempted: 0, fgPercentage: 0,
                    threeMade: 0, threeAttempted: 0, threePercentage: 0,
                    ftMade: 0, ftAttempted: 0, ftPercentage: 0,
                    offRebounds: 0, defRebounds: 0, totalRebounds: 0,
                    assists: 0, steals: 0, blocks: 0, turnovers: 0, fouls: 0
                )
            ))
        case .nfl, .ncaaf:
            return .nfl(NFLTeamBoxScore(
                teamId: teamId,
                teamName: teamName,
                groups: []
            ))
        case .nhl:
            return .nhl(NHLTeamBoxScore(
                teamId: teamId,
                teamName: teamName,
                skaters: [],
                goalies: [],
                teamTotals: NHLTeamTotals(
                    goals: 0, assists: 0, shots: 0, hits: 0, blockedShots: 0,
                    penaltyMinutes: 0, faceoffWins: 0, faceoffLosses: 0,
                    powerPlayGoals: 0, powerPlayOpportunities: 0, shortHandedGoals: 0,
                    takeaways: 0, giveaways: 0
                ),
                scratches: []
            ))
        default:
            // Default to NBA-style empty box score for now
            return .nba(NBATeamBoxScore(
                teamId: teamId,
                teamName: teamName,
                starters: [],
                bench: [],
                dnp: [],
                teamTotals: NBATeamTotals(
                    minutes: 0, points: 0, fgMade: 0, fgAttempted: 0, fgPercentage: 0,
                    threeMade: 0, threeAttempted: 0, threePercentage: 0,
                    ftMade: 0, ftAttempted: 0, ftPercentage: 0,
                    offRebounds: 0, defRebounds: 0, totalRebounds: 0,
                    assists: 0, steals: 0, blocks: 0, turnovers: 0, fouls: 0
                )
            ))
        }
    }
}

/// Data transfer object for team in scoreboard
struct TeamDTO: Decodable {
    let id: String
    let abbrev: String
    let name: String
    let city: String
    let score: Int?
    let logoURL: String?
    let primaryColor: String?
    let conference: String?
    let division: String?
    
    func toDomain() -> TeamInfo {
        TeamInfo(
            id: id,
            abbreviation: abbrev,
            name: name,
            city: city,
            primaryColor: primaryColor ?? "#000000",
            logoURL: logoURL.flatMap { URL(string: $0) },
            conference: conference,
            division: division
        )
    }
}

/// Data transfer object for venue
struct VenueDTO: Decodable {
    let id: String
    let name: String
    let city: String
    let state: String?
    
    func toDomain() -> Venue {
        Venue(id: id, name: name, city: city, state: state)
    }
}

/// Response model for available dates endpoint
struct AvailableDatesResponse: Decodable {
    let data: [String]
}

// MARK: - Shared Instance

extension ScoreboardRepository {
    static let shared = ScoreboardRepository()
}
