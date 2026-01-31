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
