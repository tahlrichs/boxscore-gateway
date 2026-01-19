//
//  NFLModels.swift
//  BoxScore
//
//  NFL-specific box score models
//

import Foundation

// MARK: - NFL Team Box Score

struct NFLTeamBoxScore: Codable, Sendable {
    let teamId: String
    let teamName: String
    let groups: [NFLGroup]
}

// MARK: - NFL Group (Offense / Defense / Special Teams)

enum NFLGroupType: String, CaseIterable, Identifiable, Codable, Sendable {
    case offense
    case defense
    case specialTeams
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .offense: return "Offense"
        case .defense: return "Defense"
        case .specialTeams: return "Special Teams"
        }
    }
}

struct NFLGroup: Identifiable, Codable, Sendable {
    let id: String
    let type: NFLGroupType
    let sections: [NFLSection]
    
    var displayName: String { type.displayName }
}

// MARK: - NFL Section (Passing / Rushing / Receiving / etc.)

enum NFLSectionType: String, Identifiable, Codable, Sendable {
    // Offense
    case passing
    case rushing
    case receiving
    
    // Defense
    case tackles
    case interceptions
    case fumbles
    case sacks
    
    // Special Teams
    case kicking
    case punting
    case kickReturns
    case puntReturns
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .passing: return "Passing"
        case .rushing: return "Rushing"
        case .receiving: return "Receiving"
        case .tackles: return "Tackles"
        case .interceptions: return "Interceptions"
        case .fumbles: return "Fumbles"
        case .sacks: return "Sacks"
        case .kicking: return "Kicking"
        case .punting: return "Punting"
        case .kickReturns: return "Kick Returns"
        case .puntReturns: return "Punt Returns"
        }
    }
}

struct NFLSection: Identifiable, Codable, Sendable {
    let id: String
    let type: NFLSectionType
    let columns: [TableColumn]
    let rows: [TableRow]
    let teamTotalsRow: TableRow?
    let isEmpty: Bool
    
    var displayName: String { type.displayName }
    
    init(
        id: String,
        type: NFLSectionType,
        columns: [TableColumn],
        rows: [TableRow],
        teamTotalsRow: TableRow? = nil
    ) {
        self.id = id
        self.type = type
        self.columns = columns
        self.rows = rows
        self.teamTotalsRow = teamTotalsRow
        self.isEmpty = rows.isEmpty
    }
    
    /// Create an empty section
    static func empty(type: NFLSectionType, teamId: String) -> NFLSection {
        NFLSection(
            id: "\(teamId)_\(type.rawValue)",
            type: type,
            columns: [],
            rows: []
        )
    }
}

// MARK: - NFL Column Definitions

enum NFLColumns {
    static let passing: [TableColumn] = [
        TableColumn(id: "cmp", title: "CMP", width: 44),
        TableColumn(id: "att", title: "ATT", width: 44),
        TableColumn(id: "yds", title: "YDS", width: 50),
        TableColumn(id: "td", title: "TD", width: 40),
        TableColumn(id: "int", title: "INT", width: 40),
        TableColumn(id: "sack", title: "SCK", width: 44),
        TableColumn(id: "rtg", title: "RTG", width: 50),
    ]
    
    static let rushing: [TableColumn] = [
        TableColumn(id: "car", title: "CAR", width: 44),
        TableColumn(id: "yds", title: "YDS", width: 50),
        TableColumn(id: "avg", title: "AVG", width: 50),
        TableColumn(id: "td", title: "TD", width: 40),
        TableColumn(id: "lng", title: "LNG", width: 44),
    ]
    
    static let receiving: [TableColumn] = [
        TableColumn(id: "rec", title: "REC", width: 44),
        TableColumn(id: "tgt", title: "TGT", width: 44),
        TableColumn(id: "yds", title: "YDS", width: 50),
        TableColumn(id: "avg", title: "AVG", width: 50),
        TableColumn(id: "td", title: "TD", width: 40),
        TableColumn(id: "lng", title: "LNG", width: 44),
    ]
    
    static let tackles: [TableColumn] = [
        TableColumn(id: "tot", title: "TOT", width: 44),
        TableColumn(id: "solo", title: "SOLO", width: 50),
        TableColumn(id: "ast", title: "AST", width: 44),
        TableColumn(id: "tfl", title: "TFL", width: 44),
        TableColumn(id: "qbh", title: "QBH", width: 44),
    ]
    
    static let interceptions: [TableColumn] = [
        TableColumn(id: "int", title: "INT", width: 40),
        TableColumn(id: "yds", title: "YDS", width: 50),
        TableColumn(id: "td", title: "TD", width: 40),
    ]
    
    static let fumbles: [TableColumn] = [
        TableColumn(id: "fum", title: "FUM", width: 44),
        TableColumn(id: "lost", title: "LOST", width: 50),
        TableColumn(id: "rec", title: "REC", width: 44),
    ]
    
    static let sacks: [TableColumn] = [
        TableColumn(id: "sacks", title: "SACKS", width: 60),
        TableColumn(id: "yds", title: "YDS", width: 50),
    ]
    
    static let kicking: [TableColumn] = [
        TableColumn(id: "fgm", title: "FGM", width: 50),
        TableColumn(id: "fga", title: "FGA", width: 50),
        TableColumn(id: "lng", title: "LNG", width: 44),
        TableColumn(id: "xpm", title: "XPM", width: 50),
        TableColumn(id: "xpa", title: "XPA", width: 50),
        TableColumn(id: "pts", title: "PTS", width: 44),
    ]
    
    static let punting: [TableColumn] = [
        TableColumn(id: "punts", title: "PUNTS", width: 60),
        TableColumn(id: "yds", title: "YDS", width: 50),
        TableColumn(id: "avg", title: "AVG", width: 50),
        TableColumn(id: "tb", title: "TB", width: 40),
        TableColumn(id: "in20", title: "IN20", width: 50),
        TableColumn(id: "lng", title: "LNG", width: 44),
    ]
    
    static let kickReturns: [TableColumn] = [
        TableColumn(id: "ret", title: "RET", width: 44),
        TableColumn(id: "yds", title: "YDS", width: 50),
        TableColumn(id: "avg", title: "AVG", width: 50),
        TableColumn(id: "td", title: "TD", width: 40),
        TableColumn(id: "lng", title: "LNG", width: 44),
    ]
    
    static let puntReturns: [TableColumn] = [
        TableColumn(id: "ret", title: "RET", width: 44),
        TableColumn(id: "yds", title: "YDS", width: 50),
        TableColumn(id: "avg", title: "AVG", width: 50),
        TableColumn(id: "td", title: "TD", width: 40),
        TableColumn(id: "lng", title: "LNG", width: 44),
    ]
    
    static let playerColumnWidth: CGFloat = 140
    
    static func columns(for type: NFLSectionType) -> [TableColumn] {
        switch type {
        case .passing: return passing
        case .rushing: return rushing
        case .receiving: return receiving
        case .tackles: return tackles
        case .interceptions: return interceptions
        case .fumbles: return fumbles
        case .sacks: return sacks
        case .kicking: return kicking
        case .punting: return punting
        case .kickReturns: return kickReturns
        case .puntReturns: return puntReturns
        }
    }
}

