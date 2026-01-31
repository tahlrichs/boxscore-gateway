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
    let ppg: Double
    let rpg: Double
    let apg: Double
    let spg: Double
    let fgPct: Double  // 0-100 scale
    let ftPct: Double  // 0-100 scale

    var id: String { "\(seasonLabel)-\(teamAbbreviation ?? "total")" }
}
