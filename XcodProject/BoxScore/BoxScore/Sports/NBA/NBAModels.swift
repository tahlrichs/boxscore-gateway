//
//  NBAModels.swift
//  BoxScore
//
//  NBA-specific box score models
//

import Foundation

// MARK: - NBA Team Box Score

struct NBATeamBoxScore: Codable, Equatable {
    let teamId: String
    let teamName: String
    let starters: [NBAPlayerLine]
    let bench: [NBAPlayerLine]
    let dnp: [NBAPlayerLine]      // Did Not Play
    let teamTotals: NBATeamTotals
}

// MARK: - NBA Player Line

struct NBAPlayerLine: Identifiable, Codable, Equatable {
    let id: String               // playerId
    let name: String
    let jersey: String
    let position: String
    let isStarter: Bool
    let hasEnteredGame: Bool
    let stats: NBAStatLine?      // nil if hasn't entered game
    let dnpReason: String?       // e.g., "Coach's Decision", "Injury"
    
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
}

// MARK: - NBA Stat Line

struct NBAStatLine: Codable, Equatable {
    let minutes: Int
    let points: Int
    let fgMade: Int
    let fgAttempted: Int
    let threeMade: Int
    let threeAttempted: Int
    let ftMade: Int
    let ftAttempted: Int
    let offRebounds: Int
    let defRebounds: Int
    let assists: Int
    let steals: Int
    let blocks: Int
    let turnovers: Int
    let fouls: Int
    let plusMinus: Int
    
    var totalRebounds: Int { offRebounds + defRebounds }
    
    var fgPercentage: Double {
        fgAttempted > 0 ? Double(fgMade) / Double(fgAttempted) * 100 : 0
    }
    
    var threePercentage: Double {
        threeAttempted > 0 ? Double(threeMade) / Double(threeAttempted) * 100 : 0
    }
    
    var ftPercentage: Double {
        ftAttempted > 0 ? Double(ftMade) / Double(ftAttempted) * 100 : 0
    }
    
    // MARK: - Formatted Display Strings (pre-computed for performance)
    
    var minutesDisplay: String { "\(minutes)" }
    var pointsDisplay: String { "\(points)" }
    var fgDisplay: String { "\(fgMade)-\(fgAttempted)" }
    var threeDisplay: String { "\(threeMade)-\(threeAttempted)" }
    var ftDisplay: String { "\(ftMade)-\(ftAttempted)" }
    var reboundsDisplay: String { "\(totalRebounds)" }
    var assistsDisplay: String { "\(assists)" }
    var stealsDisplay: String { "\(steals)" }
    var blocksDisplay: String { "\(blocks)" }
    var turnoversDisplay: String { "\(turnovers)" }
    var foulsDisplay: String { "\(fouls)" }
    var plusMinusDisplay: String { plusMinus >= 0 ? "+\(plusMinus)" : "\(plusMinus)" }
    var offRebDisplay: String { "\(offRebounds)" }
    var defRebDisplay: String { "\(defRebounds)" }
}

// MARK: - NBA Team Totals

struct NBATeamTotals: Codable, Equatable {
    let minutes: Int
    let points: Int
    let fgMade: Int
    let fgAttempted: Int
    let fgPercentage: Double
    let threeMade: Int
    let threeAttempted: Int
    let threePercentage: Double
    let ftMade: Int
    let ftAttempted: Int
    let ftPercentage: Double
    let offRebounds: Int
    let defRebounds: Int
    let totalRebounds: Int
    let assists: Int
    let steals: Int
    let blocks: Int
    let turnovers: Int
    let fouls: Int
    
    // MARK: - Formatted Display Strings
    
    var minutesDisplay: String { "\(minutes)" }
    var pointsDisplay: String { "\(points)" }
    var fgDisplay: String { "\(fgMade)-\(fgAttempted)" }
    var fgPctDisplay: String { String(format: "%.1f%%", fgPercentage) }
    var threeDisplay: String { "\(threeMade)-\(threeAttempted)" }
    var threePctDisplay: String { String(format: "%.1f%%", threePercentage) }
    var ftDisplay: String { "\(ftMade)-\(ftAttempted)" }
    var ftPctDisplay: String { String(format: "%.1f%%", ftPercentage) }
    var reboundsDisplay: String { "\(totalRebounds)" }
    var assistsDisplay: String { "\(assists)" }
    var stealsDisplay: String { "\(steals)" }
    var blocksDisplay: String { "\(blocks)" }
    var turnoversDisplay: String { "\(turnovers)" }
    var foulsDisplay: String { "\(fouls)" }
    var offRebDisplay: String { "\(offRebounds)" }
    var defRebDisplay: String { "\(defRebounds)" }
}

// MARK: - NBA Column Definitions

enum NBAColumns {
    /// Full stat columns: MIN, PTS, FG, 3PT, FT, OREB, DREB, REB, AST, STL, BLK, TO, PF, +/-
    static let standard: [TableColumn] = [
        TableColumn(id: "min", title: "MIN", width: 32),
        TableColumn(id: "pts", title: "PTS", width: 32),
        TableColumn(id: "fg", title: "FG", width: 42),
        TableColumn(id: "3pt", title: "3PT", width: 42),
        TableColumn(id: "ft", title: "FT", width: 42),
        TableColumn(id: "oreb", title: "OREB", width: 36),
        TableColumn(id: "dreb", title: "DREB", width: 36),
        TableColumn(id: "reb", title: "REB", width: 32),
        TableColumn(id: "ast", title: "AST", width: 32),
        TableColumn(id: "stl", title: "STL", width: 32),
        TableColumn(id: "blk", title: "BLK", width: 32),
        TableColumn(id: "to", title: "TO", width: 28),
        TableColumn(id: "pf", title: "PF", width: 28),
        TableColumn(id: "+/-", title: "+/-", width: 34),
    ]
    
    static let playerColumnWidth: CGFloat = 90
}

// MARK: - Convert to TableRow

extension NBAPlayerLine {
    func toTableRow() -> TableRow {
        guard let stats = stats else {
            return TableRow(
                id: id,
                leadingText: displayName,
                subtitle: jerseyDisplay,
                cells: Array(repeating: "-", count: NBAColumns.standard.count)
            )
        }
        
        // Order: MIN, PTS, FG, 3PT, FT, OREB, DREB, REB, AST, STL, BLK, TO, PF, +/-
        return TableRow(
            id: id,
            leadingText: displayName,
            subtitle: jerseyDisplay,
            cells: [
                stats.minutesDisplay,
                stats.pointsDisplay,
                stats.fgDisplay,
                stats.threeDisplay,
                stats.ftDisplay,
                stats.offRebDisplay,
                stats.defRebDisplay,
                stats.reboundsDisplay,
                stats.assistsDisplay,
                stats.stealsDisplay,
                stats.blocksDisplay,
                stats.turnoversDisplay,
                stats.foulsDisplay,
                stats.plusMinusDisplay
            ]
        )
    }
}

extension NBATeamTotals {
    func toTableRow(teamId: String) -> TableRow {
        // Order: MIN, PTS, FG, 3PT, FT, OREB, DREB, REB, AST, STL, BLK, TO, PF, +/-
        TableRow(
            id: "\(teamId)_totals",
            isTeamTotals: true,
            leadingText: "TEAM",
            cells: [
                minutesDisplay,
                pointsDisplay,
                fgDisplay,
                threeDisplay,
                ftDisplay,
                offRebDisplay,
                defRebDisplay,
                reboundsDisplay,
                assistsDisplay,
                stealsDisplay,
                blocksDisplay,
                turnoversDisplay,
                foulsDisplay,
                "-"  // No +/- for team totals
            ]
        )
    }
}
