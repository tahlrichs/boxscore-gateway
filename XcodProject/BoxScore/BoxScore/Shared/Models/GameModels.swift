//
//  GameModels.swift
//  BoxScore
//
//  Sport-agnostic game models
//

import Foundation

// MARK: - Sport Type

enum Sport: String, CaseIterable, Identifiable, Codable, Sendable {
    case nba
    case nfl
    case ncaaf   // College Football
    case ncaam   // College Basketball
    case nhl
    case mlb
    case golf    // Golf (PGA Tour, LPGA Tour)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nba: return "NBA"
        case .nfl: return "NFL"
        case .ncaaf: return "NCCAF"
        case .ncaam: return "NCAAM"
        case .nhl: return "NHL"
        case .mlb: return "MLB"
        case .golf: return "GOLF"
        }
    }

    /// Whether this sport uses football-style box scores
    var isFootball: Bool {
        return self == .nfl || self == .ncaaf
    }

    /// Whether this sport uses basketball-style box scores
    var isBasketball: Bool {
        return self == .nba || self == .ncaam
    }

    /// Whether this sport uses hockey-style box scores
    var isHockey: Bool {
        return self == .nhl
    }

    /// Whether this sport is golf
    var isGolf: Bool {
        return self == .golf
    }

    /// Whether this is a team-based sport (not golf)
    var isTeamBased: Bool {
        return self != .golf
    }
}

// MARK: - Game Status

enum GameStatus: Equatable, Codable, Sendable {
    case scheduled(date: Date)
    case live(period: String, clock: String)
    case final
    case finalOvertime(periods: Int)
    
    var displayText: String {
        switch self {
        case .scheduled(let date):
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        case .live(let period, let clock):
            return "\(period) \(clock)"
        case .final:
            return "FINAL"
        case .finalOvertime(let periods):
            return periods == 1 ? "FINAL/OT" : "FINAL/\(periods)OT"
        }
    }
    
    var isLive: Bool {
        if case .live = self { return true }
        return false
    }
    
    var isFinal: Bool {
        switch self {
        case .final, .finalOvertime:
            return true
        default:
            return false
        }
    }

    var isScheduled: Bool {
        if case .scheduled = self { return true }
        return false
    }

    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case type, date, period, clock, periods
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "scheduled":
            let date = try container.decode(Date.self, forKey: .date)
            self = .scheduled(date: date)
        case "live":
            let period = try container.decode(String.self, forKey: .period)
            let clock = try container.decode(String.self, forKey: .clock)
            self = .live(period: period, clock: clock)
        case "final":
            self = .final
        case "finalOvertime":
            let periods = try container.decode(Int.self, forKey: .periods)
            self = .finalOvertime(periods: periods)
        default:
            self = .final
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .scheduled(let date):
            try container.encode("scheduled", forKey: .type)
            try container.encode(date, forKey: .date)
        case .live(let period, let clock):
            try container.encode("live", forKey: .type)
            try container.encode(period, forKey: .period)
            try container.encode(clock, forKey: .clock)
        case .final:
            try container.encode("final", forKey: .type)
        case .finalOvertime(let periods):
            try container.encode("finalOvertime", forKey: .type)
            try container.encode(periods, forKey: .periods)
        }
    }
}

// MARK: - Venue

struct Venue: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let city: String
    let state: String?
    
    init(id: String, name: String, city: String, state: String? = nil) {
        self.id = id
        self.name = name
        self.city = city
        self.state = state
    }
}

// MARK: - Team Info

struct TeamInfo: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let abbreviation: String
    let name: String
    let city: String
    let primaryColor: String  // Hex color for future use
    let logoURL: URL?
    let conference: String?
    let division: String?
    
    var fullName: String {
        // If name already contains city, don't duplicate
        if name.lowercased().hasPrefix(city.lowercased()) {
            return name
        }
        return "\(city) \(name)"
    }
    
    init(
        id: String,
        abbreviation: String,
        name: String,
        city: String,
        primaryColor: String,
        logoURL: URL? = nil,
        conference: String? = nil,
        division: String? = nil
    ) {
        self.id = id
        self.abbreviation = abbreviation
        self.name = name
        self.city = city
        self.primaryColor = primaryColor
        self.logoURL = logoURL
        self.conference = conference
        self.division = division
    }
}

// MARK: - Box Score Payload

/// Sport-specific box score data wrapped in an enum for type safety
enum BoxScorePayload: Codable, Sendable {
    case nba(NBATeamBoxScore)
    case nfl(NFLTeamBoxScore)
    case nhl(NHLTeamBoxScore)
    
    // MARK: - Codable
    
    private enum CodingKeys: String, CodingKey {
        case type, data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "nba":
            let data = try container.decode(NBATeamBoxScore.self, forKey: .data)
            self = .nba(data)
        case "nfl":
            let data = try container.decode(NFLTeamBoxScore.self, forKey: .data)
            self = .nfl(data)
        case "nhl":
            let data = try container.decode(NHLTeamBoxScore.self, forKey: .data)
            self = .nhl(data)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown box score type: \(type)")
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .nba(let data):
            try container.encode("nba", forKey: .type)
            try container.encode(data, forKey: .data)
        case .nfl(let data):
            try container.encode("nfl", forKey: .type)
            try container.encode(data, forKey: .data)
        case .nhl(let data):
            try container.encode("nhl", forKey: .type)
            try container.encode(data, forKey: .data)
        }
    }
}

// MARK: - Game

struct Game: Identifiable, Codable, Sendable {
    let id: String
    let sport: Sport
    let gameDate: Date  // The date of the game (ignoring time for filtering)
    let status: GameStatus
    let awayTeam: TeamInfo
    let homeTeam: TeamInfo
    let awayScore: Int?
    let homeScore: Int?
    let awayBoxScore: BoxScorePayload
    let homeBoxScore: BoxScorePayload
    let venue: Venue?
    let lastUpdated: Date
    let externalIds: [String: String]?
    
    /// Convenience to check if this is an NBA game
    var isNBA: Bool { sport == .nba }
    
    /// Convenience to check if this is an NFL game
    var isNFL: Bool { sport == .nfl }
    
    /// Convenience to check if this is an NCAAF game
    var isNCAAF: Bool { sport == .ncaaf }
    
    /// Convenience to check if this is an NCAAM game
    var isNCAAM: Bool { sport == .ncaam }
    
    /// Convenience to check if this is an NHL game
    var isNHL: Bool { sport == .nhl }
    
    /// Whether this game uses basketball-style box scores
    var usesBasketballBoxScore: Bool { sport.isBasketball }
    
    /// Whether this game uses football-style box scores
    var usesFootballBoxScore: Bool { sport.isFootball }
    
    /// Whether this game uses hockey-style box scores
    var usesHockeyBoxScore: Bool { sport.isHockey }
    
    init(
        id: String,
        sport: Sport,
        gameDate: Date,
        status: GameStatus,
        awayTeam: TeamInfo,
        homeTeam: TeamInfo,
        awayScore: Int?,
        homeScore: Int?,
        awayBoxScore: BoxScorePayload,
        homeBoxScore: BoxScorePayload,
        venue: Venue? = nil,
        lastUpdated: Date = Date(),
        externalIds: [String: String]? = nil
    ) {
        self.id = id
        self.sport = sport
        self.gameDate = gameDate
        self.status = status
        self.awayTeam = awayTeam
        self.homeTeam = homeTeam
        self.awayScore = awayScore
        self.homeScore = homeScore
        self.awayBoxScore = awayBoxScore
        self.homeBoxScore = homeBoxScore
        self.venue = venue
        self.lastUpdated = lastUpdated
        self.externalIds = externalIds
    }
}

// MARK: - Game Expansion State

/// Tracks which parts of a game card are expanded
struct GameExpansionState {
    var awayExpanded: Bool = false
    var homeExpanded: Bool = false
}

// MARK: - Standing

struct Standing: Identifiable, Codable, Equatable, Sendable {
    var id: String { "\(teamId)_\(season)" }
    
    let teamId: String
    let leagueId: String
    let season: String
    let wins: Int
    let losses: Int
    let ties: Int?
    let winPct: Double
    let rank: Int
    let conference: String?
    let division: String?
    let gamesBack: Double?
    let streak: String?
    let lastTen: String?
    
    // Team info for display
    let teamAbbrev: String?
    let teamName: String?
    
    init(
        teamId: String,
        leagueId: String,
        season: String,
        wins: Int,
        losses: Int,
        ties: Int? = nil,
        winPct: Double,
        rank: Int,
        conference: String? = nil,
        division: String? = nil,
        gamesBack: Double? = nil,
        streak: String? = nil,
        lastTen: String? = nil,
        teamAbbrev: String? = nil,
        teamName: String? = nil
    ) {
        self.teamId = teamId
        self.leagueId = leagueId
        self.season = season
        self.wins = wins
        self.losses = losses
        self.ties = ties
        self.winPct = winPct
        self.rank = rank
        self.conference = conference
        self.division = division
        self.gamesBack = gamesBack
        self.streak = streak
        self.lastTen = lastTen
        self.teamAbbrev = teamAbbrev
        self.teamName = teamName
    }
}

// MARK: - Ranked Team (for college polls)

struct RankedTeam: Identifiable, Codable, Equatable, Sendable {
    var id: String { teamId }

    let teamId: String
    let abbrev: String
    let name: String           // Team name like "Wildcats"
    let location: String       // School name like "Arizona"
    let rank: Int              // Current poll ranking (1-25)
    let previousRank: Int?     // Previous week's rank
    let record: String         // Overall record like "18-0"
    let trend: String?         // Movement like "+1", "-2", or "-"
    let points: Double?        // Poll points
    let firstPlaceVotes: Int?
    let logoUrl: String?
}

// MARK: - Player Info (for rosters)

struct PlayerInfo: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let name: String
    let jersey: String?
    let position: String?
    let height: String?
    let weight: String?
    let birthdate: Date?
    let college: String?
    
    init(
        id: String,
        name: String,
        jersey: String? = nil,
        position: String? = nil,
        height: String? = nil,
        weight: String? = nil,
        birthdate: Date? = nil,
        college: String? = nil
    ) {
        self.id = id
        self.name = name
        self.jersey = jersey
        self.position = position
        self.height = height
        self.weight = weight
        self.birthdate = birthdate
        self.college = college
    }
}

// MARK: - Roster

struct Roster: Identifiable, Codable, Equatable, Sendable {
    var id: String { teamId }
    
    let teamId: String
    let players: [PlayerInfo]
    let lastUpdated: Date
    
    init(teamId: String, players: [PlayerInfo], lastUpdated: Date = Date()) {
        self.teamId = teamId
        self.players = players
        self.lastUpdated = lastUpdated
    }
}

