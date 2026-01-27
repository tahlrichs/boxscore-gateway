//
//  LeaguesSubTab.swift
//  BoxScore
//
//  Sub-tabs for the Leagues section
//

import Foundation

enum LeaguesSubTab: String, CaseIterable, Identifiable {
    case standings
    case teams
    case stats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standings: return "Standings"
        case .teams: return "Teams"
        case .stats: return "Stats"
        }
    }
}
