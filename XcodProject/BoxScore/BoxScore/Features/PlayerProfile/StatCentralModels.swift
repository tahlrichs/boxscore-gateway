//
//  StatCentralModels.swift
//  BoxScore
//
//  Response models for the /stat-central endpoint
//

import Foundation

struct StatCentralData: Codable, Sendable {
    let player: StatCentralPlayer
    let seasons: [SeasonRow]
    let career: SeasonRow
}

struct StatCentralPlayer: Codable, Sendable {
    let id: String
    let displayName: String
    let jersey: String
    let position: String
    let teamName: String
    let teamAbbreviation: String
    let headshot: String?
    let college: String?
    let hometown: String?
    let draftSummary: String?
}

struct SeasonRow: Identifiable, Codable, Sendable {
    let seasonLabel: String
    let teamAbbreviation: String?
    let gamesPlayed: Int
    let gamesStarted: Double?
    let minutes: Double?
    let points: Double?
    let rebounds: Double?
    let assists: Double?
    let steals: Double?
    let blocks: Double?
    let turnovers: Double?
    let personalFouls: Double?
    let fgMade: Double?
    let fgAttempted: Double?
    let fgPct: Double?           // 0-100 scale
    let fg3Made: Double?
    let fg3Attempted: Double?
    let fg3Pct: Double?          // 0-100 scale
    let ftMade: Double?
    let ftAttempted: Double?
    let ftPct: Double?           // 0-100 scale
    let offRebounds: Double?
    let defRebounds: Double?

    var id: String { "\(seasonLabel)-\(teamAbbreviation ?? "total")" }
}

// MARK: - Game Log Models

struct GameLogData: Codable, Sendable {
    let games: [GameLogEntry]
}

struct GameLogEntry: Identifiable, Codable, Sendable {
    let gameId: String
    let gameDate: String        // "2026-01-28" — formatted to "Sat 1/28" in the view
    let opponent: String        // 3-letter abbreviation (e.g., "SAS")
    let isHome: Bool
    let dnpReason: String?
    let minutes: Double
    let points: Int
    let fgm: Int
    let fga: Int
    let fg3m: Int
    let fg3a: Int
    let ftm: Int
    let fta: Int
    let oreb: Int
    let dreb: Int
    let reb: Int
    let ast: Int
    let stl: Int
    let blk: Int
    let tov: Int
    let pf: Int
    let plusMinus: Int

    var id: String { gameId }

    /// Format "2026-01-28" → "Sat 1/28"
    var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        guard let date = fmt.date(from: gameDate) else { return gameDate }
        let display = DateFormatter()
        display.dateFormat = "EEE M/d"
        display.locale = Locale(identifier: "en_US_POSIX")
        return display.string(from: date)
    }

    /// "vs SAS" or "@ SAS"
    var opponentDisplay: String {
        isHome ? "vs \(opponent)" : "@ \(opponent)"
    }
}
