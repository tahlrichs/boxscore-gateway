//
//  NHLModels.swift
//  BoxScore
//
//  NHL-specific box score models
//

import Foundation

// MARK: - NHL Team Box Score

struct NHLTeamBoxScore: Codable, Equatable {
    let teamId: String
    let teamName: String
    let skaters: [NHLSkaterLine]
    let goalies: [NHLGoalieLine]
    let teamTotals: NHLTeamTotals
    let scratches: [NHLScratchPlayer]
}

// MARK: - NHL Skater Line (Forwards & Defensemen)

struct NHLSkaterLine: Identifiable, Codable, Equatable {
    let id: String               // playerId
    let name: String
    let jersey: String
    let position: String         // C, LW, RW, D
    let stats: NHLSkaterStats?
    
    /// Display name as "F. LastName" format
    var displayName: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            let firstInitial = parts[0].prefix(1)
            let lastName = parts.dropFirst().joined(separator: " ")
            return "\(firstInitial). \(lastName)"
        }
        return name
    }
    
    var jerseyDisplay: String {
        "#\(jersey)"
    }
    
    var positionShort: String {
        switch position.uppercased() {
        case "CENTER": return "C"
        case "LEFT WING", "LEFTWING": return "LW"
        case "RIGHT WING", "RIGHTWING": return "RW"
        case "DEFENSEMAN", "DEFENSE": return "D"
        default: return position.prefix(2).uppercased()
        }
    }
}

// MARK: - NHL Skater Stats

struct NHLSkaterStats: Codable, Equatable {
    let goals: Int
    let assists: Int
    let plusMinus: Int
    let penaltyMinutes: Int
    let shots: Int
    let hits: Int
    let blockedShots: Int
    let faceoffWins: Int
    let faceoffLosses: Int
    let timeOnIceSeconds: Int
    let powerPlayGoals: Int
    let shortHandedGoals: Int
    let powerPlayAssists: Int
    let shortHandedAssists: Int
    let shifts: Int
    
    var points: Int { goals + assists }
    
    var faceoffPercentage: Double {
        let total = faceoffWins + faceoffLosses
        return total > 0 ? Double(faceoffWins) / Double(total) * 100 : 0
    }
    
    // MARK: - Formatted Display Strings
    
    var goalsDisplay: String { "\(goals)" }
    var assistsDisplay: String { "\(assists)" }
    var pointsDisplay: String { "\(points)" }
    var plusMinusDisplay: String { plusMinus >= 0 ? "+\(plusMinus)" : "\(plusMinus)" }
    var penaltyMinutesDisplay: String { "\(penaltyMinutes)" }
    var shotsDisplay: String { "\(shots)" }
    var hitsDisplay: String { "\(hits)" }
    var blockedShotsDisplay: String { "\(blockedShots)" }
    var faceoffDisplay: String { "\(faceoffWins)/\(faceoffWins + faceoffLosses)" }
    var shiftsDisplay: String { "\(shifts)" }
    
    var timeOnIceDisplay: String {
        let minutes = timeOnIceSeconds / 60
        let seconds = timeOnIceSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var powerPlayPointsDisplay: String { "\(powerPlayGoals + powerPlayAssists)" }
    var shortHandedPointsDisplay: String { "\(shortHandedGoals + shortHandedAssists)" }
}

// MARK: - NHL Goalie Line

struct NHLGoalieLine: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let jersey: String
    let stats: NHLGoalieStats?
    let decision: String?        // W, L, OTL, or nil
    
    var displayName: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            let firstInitial = parts[0].prefix(1)
            let lastName = parts.dropFirst().joined(separator: " ")
            return "\(firstInitial). \(lastName)"
        }
        return name
    }
    
    var jerseyDisplay: String {
        "#\(jersey)"
    }
    
    var decisionDisplay: String {
        guard let decision = decision else { return "" }
        switch decision.uppercased() {
        case "W": return "(W)"
        case "L": return "(L)"
        case "OTL": return "(OTL)"
        default: return "(\(decision))"
        }
    }
}

// MARK: - NHL Goalie Stats

struct NHLGoalieStats: Codable, Equatable {
    let saves: Int
    let shotsAgainst: Int
    let goalsAgainst: Int
    let timeOnIceSeconds: Int
    let evenStrengthSaves: Int
    let powerPlaySaves: Int
    let shortHandedSaves: Int
    let evenStrengthShotsAgainst: Int
    let powerPlayShotsAgainst: Int
    let shortHandedShotsAgainst: Int
    
    var savePercentage: Double {
        shotsAgainst > 0 ? Double(saves) / Double(shotsAgainst) * 100 : 0
    }
    
    // MARK: - Formatted Display Strings
    
    var savesDisplay: String { "\(saves)" }
    var shotsAgainstDisplay: String { "\(shotsAgainst)" }
    var goalsAgainstDisplay: String { "\(goalsAgainst)" }
    var savePercentageDisplay: String { String(format: "%.1f%%", savePercentage) }
    
    var timeOnIceDisplay: String {
        let minutes = timeOnIceSeconds / 60
        let seconds = timeOnIceSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var evenStrengthDisplay: String { "\(evenStrengthSaves)/\(evenStrengthShotsAgainst)" }
    var powerPlayDisplay: String { "\(powerPlaySaves)/\(powerPlayShotsAgainst)" }
    var shortHandedDisplay: String { "\(shortHandedSaves)/\(shortHandedShotsAgainst)" }
}

// MARK: - NHL Scratch Player

struct NHLScratchPlayer: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let jersey: String
    let position: String
    let reason: String?          // "Healthy Scratch", "Injury - Upper Body", etc.
    
    var displayName: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            let firstInitial = parts[0].prefix(1)
            let lastName = parts.dropFirst().joined(separator: " ")
            return "\(firstInitial). \(lastName)"
        }
        return name
    }
}

// MARK: - NHL Team Totals

struct NHLTeamTotals: Codable, Equatable {
    let goals: Int
    let assists: Int
    let shots: Int
    let hits: Int
    let blockedShots: Int
    let penaltyMinutes: Int
    let faceoffWins: Int
    let faceoffLosses: Int
    let powerPlayGoals: Int
    let powerPlayOpportunities: Int
    let shortHandedGoals: Int
    let takeaways: Int
    let giveaways: Int
    
    var points: Int { goals + assists }
    
    var faceoffPercentage: Double {
        let total = faceoffWins + faceoffLosses
        return total > 0 ? Double(faceoffWins) / Double(total) * 100 : 0
    }
    
    var powerPlayPercentage: Double {
        powerPlayOpportunities > 0 ? Double(powerPlayGoals) / Double(powerPlayOpportunities) * 100 : 0
    }
    
    // MARK: - Formatted Display Strings
    
    var goalsDisplay: String { "\(goals)" }
    var assistsDisplay: String { "\(assists)" }
    var pointsDisplay: String { "\(points)" }
    var shotsDisplay: String { "\(shots)" }
    var hitsDisplay: String { "\(hits)" }
    var blockedShotsDisplay: String { "\(blockedShots)" }
    var penaltyMinutesDisplay: String { "\(penaltyMinutes)" }
    var faceoffDisplay: String { "\(faceoffWins)/\(faceoffWins + faceoffLosses)" }
    var faceoffPctDisplay: String { String(format: "%.1f%%", faceoffPercentage) }
    var powerPlayDisplay: String { "\(powerPlayGoals)/\(powerPlayOpportunities)" }
    var powerPlayPctDisplay: String { String(format: "%.1f%%", powerPlayPercentage) }
}

// MARK: - NHL Column Definitions

enum NHLColumns {
    /// Skater stat columns: TOI, G, A, PTS, +/-, PIM, SOG, HIT, BLK, FO
    static let skaters: [TableColumn] = [
        TableColumn(id: "toi", title: "TOI", width: 44),
        TableColumn(id: "g", title: "G", width: 28),
        TableColumn(id: "a", title: "A", width: 28),
        TableColumn(id: "pts", title: "PTS", width: 32),
        TableColumn(id: "pm", title: "+/-", width: 34),
        TableColumn(id: "pim", title: "PIM", width: 32),
        TableColumn(id: "sog", title: "SOG", width: 36),
        TableColumn(id: "hit", title: "HIT", width: 32),
        TableColumn(id: "blk", title: "BLK", width: 32),
        TableColumn(id: "fo", title: "FO", width: 50),
    ]
    
    /// Goalie stat columns: TOI, SV, SA, GA, SV%
    static let goalies: [TableColumn] = [
        TableColumn(id: "toi", title: "TOI", width: 44),
        TableColumn(id: "sv", title: "SV", width: 32),
        TableColumn(id: "sa", title: "SA", width: 32),
        TableColumn(id: "ga", title: "GA", width: 32),
        TableColumn(id: "svpct", title: "SV%", width: 52),
    ]
    
    static let playerColumnWidth: CGFloat = 110
}

// MARK: - Convert to TableRow

extension NHLSkaterLine {
    func toTableRow() -> TableRow {
        guard let stats = stats else {
            return TableRow(
                id: id,
                leadingText: displayName,
                subtitle: "\(jerseyDisplay) \(positionShort)",
                cells: Array(repeating: "-", count: NHLColumns.skaters.count)
            )
        }
        
        // Order: TOI, G, A, PTS, +/-, PIM, SOG, HIT, BLK, FO
        return TableRow(
            id: id,
            leadingText: displayName,
            subtitle: "\(jerseyDisplay) \(positionShort)",
            cells: [
                stats.timeOnIceDisplay,
                stats.goalsDisplay,
                stats.assistsDisplay,
                stats.pointsDisplay,
                stats.plusMinusDisplay,
                stats.penaltyMinutesDisplay,
                stats.shotsDisplay,
                stats.hitsDisplay,
                stats.blockedShotsDisplay,
                stats.faceoffDisplay
            ]
        )
    }
}

extension NHLGoalieLine {
    func toTableRow() -> TableRow {
        guard let stats = stats else {
            return TableRow(
                id: id,
                leadingText: "\(displayName) \(decisionDisplay)",
                subtitle: jerseyDisplay,
                cells: Array(repeating: "-", count: NHLColumns.goalies.count)
            )
        }
        
        // Order: TOI, SV, SA, GA, SV%
        return TableRow(
            id: id,
            leadingText: "\(displayName) \(decisionDisplay)".trimmingCharacters(in: .whitespaces),
            subtitle: jerseyDisplay,
            cells: [
                stats.timeOnIceDisplay,
                stats.savesDisplay,
                stats.shotsAgainstDisplay,
                stats.goalsAgainstDisplay,
                stats.savePercentageDisplay
            ]
        )
    }
}

extension NHLTeamTotals {
    func toTableRow(teamId: String) -> TableRow {
        // Order: TOI, G, A, PTS, -, PIM, SOG, HIT, BLK, FO
        TableRow(
            id: "\(teamId)_totals",
            isTeamTotals: true,
            leadingText: "TEAM",
            cells: [
                "-",  // No TOI for team totals
                goalsDisplay,
                assistsDisplay,
                pointsDisplay,
                "-",  // No +/- for team totals
                penaltyMinutesDisplay,
                shotsDisplay,
                hitsDisplay,
                blockedShotsDisplay,
                faceoffDisplay
            ]
        )
    }
}
