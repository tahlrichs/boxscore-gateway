//
//  GolfTour.swift
//  BoxScore
//
//  Golf tour definitions for tour filtering (PGA Tour, LPGA Tour)
//

import Foundation

// MARK: - Golf Tour

struct GolfTour: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let shortName: String

    static func == (lhs: GolfTour, rhs: GolfTour) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Tour Definitions

extension GolfTour {
    /// All Tours filter (shows both PGA and LPGA)
    static let all = GolfTour(id: "all", name: "All Tours", shortName: "All")

    /// PGA Tour
    static let pga = GolfTour(id: "pga", name: "PGA Tour", shortName: "PGA")

    /// LPGA Tour
    static let lpga = GolfTour(id: "lpga", name: "LPGA Tour", shortName: "LPGA")

    /// All available tours (including "All" filter)
    static let allTours: [GolfTour] = [all, pga, lpga]

    /// Individual tours only (for API calls)
    static let individualTours: [GolfTour] = [pga, lpga]

    /// Default tour (All)
    static var defaultTour: GolfTour { all }

    /// Get tour by ID
    static func tour(forId id: String) -> GolfTour? {
        allTours.first { $0.id == id.lowercased() }
    }

    /// Whether this is the "All Tours" filter
    var isAll: Bool {
        id == "all"
    }
}
