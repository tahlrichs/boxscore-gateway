//
//  GameRepository.swift
//  BoxScore
//
//  Repository for individual game and box score data
//

import Foundation

/// Protocol for game data access
protocol GameRepositoryProtocol {
    func getGame(id: String) async throws -> Game
    func getBoxScore(gameId: String, sport: Sport) async throws -> Game
    func refreshGame(id: String) async throws -> Game
}

/// Result containing game data and metadata
struct GameResult {
    let game: Game
    let lastUpdated: Date?
    let isStale: Bool
    let hasBoxScore: Bool
}

/// Repository for game and box score data
actor GameRepository: GameRepositoryProtocol {
    
    // MARK: - Dependencies
    
    private let gatewayClient: GatewayClientProtocol
    private let cacheManager: CacheManager
    private let config: AppConfig
    
    // MARK: - State
    
    private var inFlightGameRequests: [String: Task<Game, Error>] = [:]
    private var inFlightBoxScoreRequests: [String: Task<Game, Error>] = [:]
    
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
    
    /// Get game by ID
    func getGame(id: String) async throws -> Game {
        // Check cache first
        let cacheResult: CacheResult<Game> = await cacheManager.getGame(id: id)
        
        if case .fresh(let game, _) = cacheResult {
            return game
        }
        
        // For stale data, return cached and refresh in background
        if case .stale(let game, _) = cacheResult {
            Task {
                _ = try? await fetchGameFromNetwork(id: id)
            }
            return game
        }
        
        return try await fetchGameFromNetwork(id: id)
    }
    
    /// Get game with full box score data
    func getBoxScore(gameId: String, sport: Sport) async throws -> Game {
        // Check if using mock data
        if config.useMockData {
            return try getMockGame(id: gameId, sport: sport)
        }
        
        let cacheKey = CacheKey.boxScore(gameId: gameId)
        let cacheResult: CacheResult<Game> = await cacheManager.get(
            key: cacheKey,
            policy: .liveBoxScore
        )
        
        switch cacheResult {
        case .fresh(let game, _):
            return game
            
        case .stale(let game, _):
            // Trigger background refresh for live games
            if game.status.isLive {
                Task {
                    _ = try? await fetchBoxScoreFromNetwork(gameId: gameId, sport: sport)
                }
            }
            return game
            
        case .expired, .miss:
            return try await fetchBoxScoreFromNetwork(gameId: gameId, sport: sport)
        }
    }
    
    /// Force refresh game from network
    func refreshGame(id: String) async throws -> Game {
        return try await fetchGameFromNetwork(id: id)
    }
    
    /// Get game with metadata about freshness
    func getGameWithMetadata(id: String, sport: Sport) async throws -> GameResult {
        if config.useMockData {
            let game = try getMockGame(id: id, sport: sport)
            let hasBoxScore = checkHasBoxScore(game)
            return GameResult(game: game, lastUpdated: Date(), isStale: false, hasBoxScore: hasBoxScore)
        }
        
        let cacheKey = CacheKey.boxScore(gameId: id)
        let cacheResult: CacheResult<Game> = await cacheManager.get(key: cacheKey, policy: .liveBoxScore)
        
        switch cacheResult {
        case .fresh(let game, let cachedAt):
            return GameResult(game: game, lastUpdated: cachedAt, isStale: false, hasBoxScore: checkHasBoxScore(game))
            
        case .stale(let game, let cachedAt):
            if game.status.isLive {
                Task {
                    _ = try? await fetchBoxScoreFromNetwork(gameId: id, sport: sport)
                }
            }
            return GameResult(game: game, lastUpdated: cachedAt, isStale: true, hasBoxScore: checkHasBoxScore(game))
            
        case .expired(let game, let cachedAt):
            Task {
                _ = try? await fetchBoxScoreFromNetwork(gameId: id, sport: sport)
            }
            return GameResult(game: game, lastUpdated: cachedAt, isStale: true, hasBoxScore: checkHasBoxScore(game))
            
        case .miss:
            let game = try await fetchBoxScoreFromNetwork(gameId: id, sport: sport)
            return GameResult(game: game, lastUpdated: Date(), isStale: false, hasBoxScore: checkHasBoxScore(game))
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchGameFromNetwork(id: String) async throws -> Game {
        // Check for in-flight request
        if let existingTask = inFlightGameRequests[id] {
            return try await existingTask.value
        }
        
        let task = Task<Game, Error> {
            let endpoint = GatewayEndpoint.game(id: id)
            let response: GameDetailResponse = try await gatewayClient.fetch(endpoint)
            let game = response.toDomain()
            
            await cacheManager.setGame(game)
            return game
        }
        
        inFlightGameRequests[id] = task
        defer { inFlightGameRequests.removeValue(forKey: id) }
        
        return try await task.value
    }
    
    private func fetchBoxScoreFromNetwork(gameId: String, sport: Sport) async throws -> Game {
        // Check for in-flight request
        if let existingTask = inFlightBoxScoreRequests[gameId] {
            return try await existingTask.value
        }
        
        let task = Task<Game, Error> {
            let endpoint = GatewayEndpoint.boxScore(gameId: gameId)
            let response: BoxScoreResponse = try await gatewayClient.fetch(endpoint)
            let game = response.toDomain(sport: sport)
            
            // Cache with appropriate policy based on game status
            let cacheKey = CacheKey.boxScore(gameId: gameId)
            let policy: CachePolicy = game.status.isFinal ? .finalBoxScore : .liveBoxScore
            await cacheManager.set(key: cacheKey, value: game, policy: policy)
            
            return game
        }
        
        inFlightBoxScoreRequests[gameId] = task
        defer { inFlightBoxScoreRequests.removeValue(forKey: gameId) }
        
        return try await task.value
    }
    
    private func getMockGame(id: String, sport: Sport) throws -> Game {
        let allGames: [Game]
        switch sport {
        case .nba:
            allGames = NBAMockData.allGames
        case .nfl:
            allGames = NFLMockData.allGames
        case .nhl:
            allGames = NHLMockData.allGames
        default:
            allGames = []
        }
        
        guard let game = allGames.first(where: { $0.id == id }) else {
            throw NetworkError.noData
        }
        
        return game
    }
    
    private func checkHasBoxScore(_ game: Game) -> Bool {
        switch game.homeBoxScore {
        case .nba(let boxScore):
            return !boxScore.starters.isEmpty
        case .nfl(let boxScore):
            return !boxScore.groups.isEmpty
        case .nhl(let boxScore):
            return !boxScore.skaters.isEmpty
        }
    }
}

// MARK: - API Response Models

/// Response for game detail endpoint
struct GameDetailResponse: Decodable {
    let game: GameDTO
    let lastUpdated: String?
    
    func toDomain() -> Game {
        // Infer sport from response or default
        let sport = Sport.from(leagueId: game.id.components(separatedBy: "_").first ?? "") ?? .nba
        return game.toDomain(sport: sport)
    }
}

/// Response for box score endpoint
struct BoxScoreResponse: Decodable {
    let game: GameDTO
    let boxScore: BoxScoreDTO
    let lastUpdated: String?
    
    func toDomain(sport: Sport) -> Game {
        var domainGame = game.toDomain(sport: sport)
        
        // Override box scores with actual data
        let homeBoxScore = boxScore.homeTeam.toDomain(sport: sport)
        let awayBoxScore = boxScore.awayTeam.toDomain(sport: sport)
        
        return Game(
            id: domainGame.id,
            sport: domainGame.sport,
            gameDate: domainGame.gameDate,
            status: domainGame.status,
            awayTeam: domainGame.awayTeam,
            homeTeam: domainGame.homeTeam,
            awayScore: domainGame.awayScore,
            homeScore: domainGame.homeScore,
            awayBoxScore: awayBoxScore,
            homeBoxScore: homeBoxScore,
            venue: domainGame.venue,
            lastUpdated: Date(),
            externalIds: domainGame.externalIds
        )
    }
}

/// Box score DTO container
struct BoxScoreDTO: Decodable {
    let homeTeam: TeamBoxScoreDTO
    let awayTeam: TeamBoxScoreDTO
}

/// Team box score DTO (handles multiple sports)
struct TeamBoxScoreDTO: Decodable {
    let teamId: String
    let teamName: String
    
    // NBA fields
    let starters: [PlayerLineDTO]?
    let bench: [PlayerLineDTO]?
    let dnp: [PlayerLineDTO]?
    let teamTotals: TeamTotalsDTO?
    
    // NFL fields
    let groups: [NFLGroupDTO]?
    
    // NHL fields
    let skaters: [NHLSkaterDTO]?
    let goalies: [NHLGoalieDTO]?
    let scratches: [NHLScratchDTO]?
    
    func toDomain(sport: Sport) -> BoxScorePayload {
        switch sport {
        case .nba, .ncaam:
            return .nba(toNBABoxScore())
        case .nfl, .ncaaf:
            return .nfl(toNFLBoxScore())
        case .nhl:
            return .nhl(toNHLBoxScore())
        default:
            return .nba(toNBABoxScore())
        }
    }
    
    private func toNBABoxScore() -> NBATeamBoxScore {
        NBATeamBoxScore(
            teamId: teamId,
            teamName: teamName,
            starters: starters?.map { $0.toNBAPlayerLine() } ?? [],
            bench: bench?.map { $0.toNBAPlayerLine() } ?? [],
            dnp: dnp?.map { $0.toNBAPlayerLine() } ?? [],
            teamTotals: teamTotals?.toNBATeamTotals() ?? emptyNBATeamTotals()
        )
    }
    
    private func toNFLBoxScore() -> NFLTeamBoxScore {
        // Convert flat groups from API to organized NFL structure
        // Group sections by offense/defense/specialTeams
        let sections = groups?.map { $0.toDomain(teamId: teamId) } ?? []
        
        // Categorize sections into groups
        let offenseSections = sections.filter { section in
            [.passing, .rushing, .receiving].contains(section.type)
        }
        let defenseSections = sections.filter { section in
            [.tackles, .interceptions, .fumbles, .sacks].contains(section.type)
        }
        let specialTeamsSections = sections.filter { section in
            [.kicking, .punting, .kickReturns, .puntReturns].contains(section.type)
        }
        
        var nflGroups: [NFLGroup] = []
        
        if !offenseSections.isEmpty {
            nflGroups.append(NFLGroup(
                id: "\(teamId)_offense",
                type: .offense,
                sections: offenseSections
            ))
        }
        
        if !defenseSections.isEmpty {
            nflGroups.append(NFLGroup(
                id: "\(teamId)_defense",
                type: .defense,
                sections: defenseSections
            ))
        }
        
        if !specialTeamsSections.isEmpty {
            nflGroups.append(NFLGroup(
                id: "\(teamId)_specialTeams",
                type: .specialTeams,
                sections: specialTeamsSections
            ))
        }
        
        return NFLTeamBoxScore(
            teamId: teamId,
            teamName: teamName,
            groups: nflGroups
        )
    }
    
    private func toNHLBoxScore() -> NHLTeamBoxScore {
        let skaterLines = skaters?.map { $0.toDomain() } ?? []
        
        // Calculate team totals from skaters
        let teamTotals = calculateNHLTeamTotals(from: skaterLines)
        
        return NHLTeamBoxScore(
            teamId: teamId,
            teamName: teamName,
            skaters: skaterLines,
            goalies: goalies?.map { $0.toDomain() } ?? [],
            teamTotals: teamTotals,
            scratches: scratches?.map { $0.toDomain() } ?? []
        )
    }
    
    private func calculateNHLTeamTotals(from skaters: [NHLSkaterLine]) -> NHLTeamTotals {
        var goals = 0, assists = 0, shots = 0, hits = 0, blockedShots = 0
        var penaltyMinutes = 0, faceoffWins = 0, faceoffLosses = 0
        var powerPlayGoals = 0, shortHandedGoals = 0
        
        for skater in skaters {
            if let stats = skater.stats {
                goals += stats.goals
                assists += stats.assists
                shots += stats.shots
                hits += stats.hits
                blockedShots += stats.blockedShots
                penaltyMinutes += stats.penaltyMinutes
                faceoffWins += stats.faceoffWins
                faceoffLosses += stats.faceoffLosses
                powerPlayGoals += stats.powerPlayGoals
                shortHandedGoals += stats.shortHandedGoals
            }
        }
        
        return NHLTeamTotals(
            goals: goals, assists: assists, shots: shots, hits: hits, blockedShots: blockedShots,
            penaltyMinutes: penaltyMinutes, faceoffWins: faceoffWins, faceoffLosses: faceoffLosses,
            powerPlayGoals: powerPlayGoals, powerPlayOpportunities: 0, shortHandedGoals: shortHandedGoals,
            takeaways: 0, giveaways: 0
        )
    }
    
    private func emptyNBATeamTotals() -> NBATeamTotals {
        NBATeamTotals(
            minutes: 0, points: 0, fgMade: 0, fgAttempted: 0, fgPercentage: 0,
            threeMade: 0, threeAttempted: 0, threePercentage: 0,
            ftMade: 0, ftAttempted: 0, ftPercentage: 0,
            offRebounds: 0, defRebounds: 0, totalRebounds: 0,
            assists: 0, steals: 0, blocks: 0, turnovers: 0, fouls: 0
        )
    }
}

/// Player line DTO
struct PlayerLineDTO: Decodable {
    let id: String
    let name: String
    let jersey: String?
    let position: String?
    let isStarter: Bool?
    let hasEnteredGame: Bool?
    let stats: PlayerStatsDTO?
    let dnpReason: String?
    
    func toNBAPlayerLine() -> NBAPlayerLine {
        NBAPlayerLine(
            id: id,
            name: name,
            jersey: jersey ?? "",
            position: position ?? "",
            isStarter: isStarter ?? false,
            hasEnteredGame: hasEnteredGame ?? (stats != nil),
            stats: stats?.toNBAStatLine(),
            dnpReason: dnpReason
        )
    }
}

/// Player stats DTO
struct PlayerStatsDTO: Decodable {
    let minutes: Int?
    let points: Int?
    let fgMade: Int?
    let fgAttempted: Int?
    let threeMade: Int?
    let threeAttempted: Int?
    let ftMade: Int?
    let ftAttempted: Int?
    let offRebounds: Int?
    let defRebounds: Int?
    let assists: Int?
    let steals: Int?
    let blocks: Int?
    let turnovers: Int?
    let fouls: Int?
    let plusMinus: Int?
    
    func toNBAStatLine() -> NBAStatLine {
        NBAStatLine(
            minutes: minutes ?? 0,
            points: points ?? 0,
            fgMade: fgMade ?? 0,
            fgAttempted: fgAttempted ?? 0,
            threeMade: threeMade ?? 0,
            threeAttempted: threeAttempted ?? 0,
            ftMade: ftMade ?? 0,
            ftAttempted: ftAttempted ?? 0,
            offRebounds: offRebounds ?? 0,
            defRebounds: defRebounds ?? 0,
            assists: assists ?? 0,
            steals: steals ?? 0,
            blocks: blocks ?? 0,
            turnovers: turnovers ?? 0,
            fouls: fouls ?? 0,
            plusMinus: plusMinus ?? 0
        )
    }
}

/// Team totals DTO
struct TeamTotalsDTO: Decodable {
    let minutes: Int?
    let points: Int?
    let fgMade: Int?
    let fgAttempted: Int?
    let fgPercentage: Double?
    let threeMade: Int?
    let threeAttempted: Int?
    let threePercentage: Double?
    let ftMade: Int?
    let ftAttempted: Int?
    let ftPercentage: Double?
    let offRebounds: Int?
    let defRebounds: Int?
    let totalRebounds: Int?
    let assists: Int?
    let steals: Int?
    let blocks: Int?
    let turnovers: Int?
    let fouls: Int?
    
    func toNBATeamTotals() -> NBATeamTotals {
        NBATeamTotals(
            minutes: minutes ?? 0,
            points: points ?? 0,
            fgMade: fgMade ?? 0,
            fgAttempted: fgAttempted ?? 0,
            fgPercentage: fgPercentage ?? 0,
            threeMade: threeMade ?? 0,
            threeAttempted: threeAttempted ?? 0,
            threePercentage: threePercentage ?? 0,
            ftMade: ftMade ?? 0,
            ftAttempted: ftAttempted ?? 0,
            ftPercentage: ftPercentage ?? 0,
            offRebounds: offRebounds ?? 0,
            defRebounds: defRebounds ?? 0,
            totalRebounds: totalRebounds ?? (offRebounds ?? 0) + (defRebounds ?? 0),
            assists: assists ?? 0,
            steals: steals ?? 0,
            blocks: blocks ?? 0,
            turnovers: turnovers ?? 0,
            fouls: fouls ?? 0
        )
    }
}

/// NFL Group DTO - matches API response: { name, headers, rows }
struct NFLGroupDTO: Decodable {
    let name: String
    let headers: [String]
    let rows: [NFLRowDTO]
    
    func toDomain(teamId: String) -> NFLSection {
        let sectionType = NFLSectionType(rawValue: name) ?? mapNameToSectionType(name)
        let columns = headers.enumerated().map { index, header in
            TableColumn(id: "col_\(index)", title: header, width: 50)
        }
        
        return NFLSection(
            id: "\(teamId)_\(name)",
            type: sectionType,
            columns: columns,
            rows: rows.map { $0.toDomain(headers: headers) },
            teamTotalsRow: nil
        )
    }
    
    private func mapNameToSectionType(_ name: String) -> NFLSectionType {
        // Map API names to section types
        switch name.lowercased() {
        case "passing": return .passing
        case "rushing": return .rushing
        case "receiving": return .receiving
        case "defensive", "tackles": return .tackles
        case "interceptions": return .interceptions
        case "fumbles": return .fumbles
        case "sacks": return .sacks
        case "kicking": return .kicking
        case "punting": return .punting
        case "kickreturns": return .kickReturns
        case "puntreturns": return .puntReturns
        default: return .passing
        }
    }
}

/// NFL Row DTO - matches API response: { id, name, position, stats }
struct NFLRowDTO: Decodable {
    let id: String
    let name: String
    let position: String
    let stats: [String: String]
    
    func toDomain(headers: [String]) -> TableRow {
        // Convert stats dict to ordered cells based on headers
        let cells = headers.map { header in
            stats[header] ?? "-"
        }
        
        return TableRow(
            id: id,
            isTeamTotals: false,
            leadingText: name,
            subtitle: position.isEmpty ? nil : position,
            cells: cells
        )
    }
}

// MARK: - NHL DTOs

/// NHL Skater DTO
struct NHLSkaterDTO: Decodable {
    let id: String
    let name: String
    let jersey: String
    let position: String
    let stats: NHLSkaterStatsDTO?
    
    func toDomain() -> NHLSkaterLine {
        NHLSkaterLine(
            id: id,
            name: name,
            jersey: jersey,
            position: position,
            stats: stats?.toDomain()
        )
    }
}

/// NHL Skater Stats DTO
struct NHLSkaterStatsDTO: Decodable {
    let goals: Int?
    let assists: Int?
    let plusMinus: Int?
    let penaltyMinutes: Int?
    let shots: Int?
    let hits: Int?
    let blockedShots: Int?
    let faceoffWins: Int?
    let faceoffLosses: Int?
    let timeOnIceSeconds: Int?
    let powerPlayGoals: Int?
    let shortHandedGoals: Int?
    let powerPlayAssists: Int?
    let shortHandedAssists: Int?
    let shifts: Int?
    
    func toDomain() -> NHLSkaterStats {
        NHLSkaterStats(
            goals: goals ?? 0,
            assists: assists ?? 0,
            plusMinus: plusMinus ?? 0,
            penaltyMinutes: penaltyMinutes ?? 0,
            shots: shots ?? 0,
            hits: hits ?? 0,
            blockedShots: blockedShots ?? 0,
            faceoffWins: faceoffWins ?? 0,
            faceoffLosses: faceoffLosses ?? 0,
            timeOnIceSeconds: timeOnIceSeconds ?? 0,
            powerPlayGoals: powerPlayGoals ?? 0,
            shortHandedGoals: shortHandedGoals ?? 0,
            powerPlayAssists: powerPlayAssists ?? 0,
            shortHandedAssists: shortHandedAssists ?? 0,
            shifts: shifts ?? 0
        )
    }
}

/// NHL Goalie DTO
struct NHLGoalieDTO: Decodable {
    let id: String
    let name: String
    let jersey: String
    let stats: NHLGoalieStatsDTO?
    let decision: String?
    
    func toDomain() -> NHLGoalieLine {
        NHLGoalieLine(
            id: id,
            name: name,
            jersey: jersey,
            stats: stats?.toDomain(),
            decision: decision
        )
    }
}

/// NHL Goalie Stats DTO
struct NHLGoalieStatsDTO: Decodable {
    let saves: Int?
    let shotsAgainst: Int?
    let goalsAgainst: Int?
    let timeOnIceSeconds: Int?
    let evenStrengthSaves: Int?
    let powerPlaySaves: Int?
    let shortHandedSaves: Int?
    let evenStrengthShotsAgainst: Int?
    let powerPlayShotsAgainst: Int?
    let shortHandedShotsAgainst: Int?
    
    func toDomain() -> NHLGoalieStats {
        NHLGoalieStats(
            saves: saves ?? 0,
            shotsAgainst: shotsAgainst ?? 0,
            goalsAgainst: goalsAgainst ?? 0,
            timeOnIceSeconds: timeOnIceSeconds ?? 0,
            evenStrengthSaves: evenStrengthSaves ?? 0,
            powerPlaySaves: powerPlaySaves ?? 0,
            shortHandedSaves: shortHandedSaves ?? 0,
            evenStrengthShotsAgainst: evenStrengthShotsAgainst ?? 0,
            powerPlayShotsAgainst: powerPlayShotsAgainst ?? 0,
            shortHandedShotsAgainst: shortHandedShotsAgainst ?? 0
        )
    }
}

/// NHL Scratch Player DTO
struct NHLScratchDTO: Decodable {
    let id: String
    let name: String
    let jersey: String
    let position: String
    let reason: String?
    
    func toDomain() -> NHLScratchPlayer {
        NHLScratchPlayer(
            id: id,
            name: name,
            jersey: jersey,
            position: position,
            reason: reason
        )
    }
}


// MARK: - Shared Instance

extension GameRepository {
    static let shared = GameRepository()
}
