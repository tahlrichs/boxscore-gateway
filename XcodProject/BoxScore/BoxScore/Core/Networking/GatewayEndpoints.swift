//
//  GatewayEndpoints.swift
//  BoxScore
//
//  Gateway API endpoint definitions
//

import Foundation

/// All available gateway endpoints
enum GatewayEndpoint {
    // Scoreboard
    case scoreboard(league: String, date: Date)
    case availableDates(league: String)

    // Games
    case game(id: String)
    case boxScore(gameId: String)

    // Standings
    case standings(league: String, season: String?)

    // Teams & Rosters
    case roster(teamId: String)
    case team(id: String)

    // Schedule
    case schedule(league: String, startDate: Date, endDate: Date)

    // Leagues
    case leagues

    // Health
    case health

    // Players
    case playerSearch(query: String, sport: String?, limit: Int?)
    case player(id: String)
    case playerSeasonSummary(playerId: String, season: Int)
    case playerGameLog(playerId: String, season: Int, limit: Int?)
    case playerSplits(playerId: String, season: Int)
    case playerCareer(playerId: String)

    // Golf
    case golfScoreboard(tour: String, weekStart: Date)
    case golfLeaderboard(tournamentId: String)
    case golfAvailableWeeks(tour: String)
    
    /// HTTP method for this endpoint
    var method: String {
        switch self {
        case .scoreboard, .availableDates, .game, .boxScore, .standings, .roster, .team, .schedule, .leagues, .health,
             .playerSearch, .player, .playerSeasonSummary, .playerGameLog, .playerSplits, .playerCareer,
             .golfScoreboard, .golfLeaderboard, .golfAvailableWeeks:
            return "GET"
        }
    }
    
    /// Path component of the URL
    var path: String {
        switch self {
        case .scoreboard:
            return "/v1/scoreboard"
        case .availableDates:
            return "/v1/scoreboard/dates"
        case .game(let id):
            return "/v1/games/\(id)"
        case .boxScore(let gameId):
            return "/v1/games/\(gameId)/boxscore"
        case .standings:
            return "/v1/standings"
        case .roster(let teamId):
            return "/v1/teams/\(teamId)/roster"
        case .team(let id):
            return "/v1/teams/\(id)"
        case .schedule:
            return "/v1/schedule"
        case .leagues:
            return "/v1/leagues"
        case .health:
            return "/v1/health"
        case .playerSearch:
            return "/v1/players/search"
        case .player(let id):
            return "/v1/players/\(id)"
        case .playerSeasonSummary(let playerId, let season):
            return "/v1/players/\(playerId)/season/\(season)/summary"
        case .playerGameLog(let playerId, let season, _):
            return "/v1/players/\(playerId)/season/\(season)/gamelog"
        case .playerSplits(let playerId, let season):
            return "/v1/players/\(playerId)/season/\(season)/splits"
        case .playerCareer(let playerId):
            return "/v1/players/\(playerId)/career/summary"
        case .golfScoreboard:
            return "/v1/golf/scoreboard"
        case .golfLeaderboard(let tournamentId):
            return "/v1/golf/tournaments/\(tournamentId)/leaderboard"
        case .golfAvailableWeeks:
            return "/v1/golf/available-weeks"
        }
    }
    
    /// Query parameters for this endpoint
    var queryItems: [URLQueryItem]? {
        switch self {
        case .scoreboard(let league, let date):
            return [
                URLQueryItem(name: "league", value: league),
                URLQueryItem(name: "date", value: Self.dateFormatter.string(from: date))
            ]

        case .availableDates(let league):
            return [
                URLQueryItem(name: "league", value: league)
            ]

        case .standings(let league, let season):
            var items = [URLQueryItem(name: "league", value: league)]
            if let season = season {
                items.append(URLQueryItem(name: "season", value: season))
            }
            return items

        case .schedule(let league, let startDate, let endDate):
            return [
                URLQueryItem(name: "league", value: league),
                URLQueryItem(name: "startDate", value: Self.dateFormatter.string(from: startDate)),
                URLQueryItem(name: "endDate", value: Self.dateFormatter.string(from: endDate))
            ]

        case .game, .boxScore, .roster, .team, .leagues, .health,
             .player, .playerSeasonSummary, .playerSplits, .playerCareer:
            return nil

        case .playerSearch(let query, let sport, let limit):
            var items = [URLQueryItem(name: "q", value: query)]
            if let sport = sport {
                items.append(URLQueryItem(name: "sport", value: sport))
            }
            if let limit = limit {
                items.append(URLQueryItem(name: "limit", value: String(limit)))
            }
            return items

        case .playerGameLog(_, _, let limit):
            if let limit = limit {
                return [URLQueryItem(name: "limit", value: String(limit))]
            }
            return nil

        case .golfScoreboard(let tour, let weekStart):
            return [
                URLQueryItem(name: "tour", value: tour),
                URLQueryItem(name: "week", value: Self.dateFormatter.string(from: weekStart))
            ]

        case .golfAvailableWeeks(let tour):
            return [URLQueryItem(name: "tour", value: tour)]

        case .golfLeaderboard:
            return nil
        }
    }
    
    /// Date formatter for API date parameters (YYYY-MM-DD)
    /// Uses local timezone so the date matches what the user sees
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current  // Use local timezone, not UTC
        return formatter
    }()
    
    /// Build the full URL for this endpoint
    func url(baseURL: URL) -> URL? {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        return components?.url
    }
}

// MARK: - Sport to League Mapping

extension Sport {
    /// The league identifier used in API calls
    var leagueId: String {
        switch self {
        case .nba:
            return "nba"
        case .nfl:
            return "nfl"
        case .nhl:
            return "nhl"
        case .mlb:
            return "mlb"
        case .ncaam:
            return "ncaam"
        case .ncaaf:
            return "ncaaf"
        case .golf:
            return "pga" // Default to PGA for golf
        }
    }

    /// Create Sport from league ID string
    static func from(leagueId: String) -> Sport? {
        switch leagueId.lowercased() {
        case "nba": return .nba
        case "nfl": return .nfl
        case "nhl": return .nhl
        case "mlb": return .mlb
        case "ncaam": return .ncaam
        case "ncaaf": return .ncaaf
        case "pga", "lpga", "golf": return .golf
        default: return nil
        }
    }
}
