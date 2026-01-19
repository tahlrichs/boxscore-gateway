//
//  CollegeConference.swift
//  BoxScore
//
//  Conference definitions for college sports filtering
//

import Foundation

// MARK: - College Conference

struct CollegeConference: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let shortName: String
    let sport: Sport  // ncaaf or ncaam
    
    static func == (lhs: CollegeConference, rhs: CollegeConference) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Conference Lists

extension CollegeConference {
    
    /// Top 25 filter (special - not a real conference)
    static let top25NCAAF = CollegeConference(id: "top25", name: "Top 25", shortName: "Top 25", sport: .ncaaf)
    static let top25NCAAM = CollegeConference(id: "top25", name: "Top 25", shortName: "Top 25", sport: .ncaam)
    
    /// All conferences filter
    static let allNCAAF = CollegeConference(id: "all", name: "All Conferences", shortName: "All", sport: .ncaaf)
    static let allNCAAM = CollegeConference(id: "all", name: "All Conferences", shortName: "All", sport: .ncaam)
    
    // MARK: - NCAAF Conferences (FBS)
    
    static let ncaafConferences: [CollegeConference] = [
        top25NCAAF,
        allNCAAF,
        // Power 4
        CollegeConference(id: "acc", name: "ACC", shortName: "ACC", sport: .ncaaf),
        CollegeConference(id: "big12", name: "Big 12", shortName: "Big 12", sport: .ncaaf),
        CollegeConference(id: "bigten", name: "Big Ten", shortName: "Big Ten", sport: .ncaaf),
        CollegeConference(id: "sec", name: "SEC", shortName: "SEC", sport: .ncaaf),
        // Group of 5
        CollegeConference(id: "aac", name: "American Athletic", shortName: "AAC", sport: .ncaaf),
        CollegeConference(id: "cusa", name: "Conference USA", shortName: "C-USA", sport: .ncaaf),
        CollegeConference(id: "mac", name: "Mid-American", shortName: "MAC", sport: .ncaaf),
        CollegeConference(id: "mwc", name: "Mountain West", shortName: "MWC", sport: .ncaaf),
        CollegeConference(id: "sunbelt", name: "Sun Belt", shortName: "Sun Belt", sport: .ncaaf),
        // Independents
        CollegeConference(id: "ind", name: "FBS Independents", shortName: "Ind", sport: .ncaaf),
    ]
    
    // MARK: - NCAAM Conferences
    
    static let ncaamConferences: [CollegeConference] = [
        top25NCAAM,
        allNCAAM,
        // Power Conferences
        CollegeConference(id: "acc", name: "ACC", shortName: "ACC", sport: .ncaam),
        CollegeConference(id: "big12", name: "Big 12", shortName: "Big 12", sport: .ncaam),
        CollegeConference(id: "bigten", name: "Big Ten", shortName: "Big Ten", sport: .ncaam),
        CollegeConference(id: "bigeast", name: "Big East", shortName: "Big East", sport: .ncaam),
        CollegeConference(id: "sec", name: "SEC", shortName: "SEC", sport: .ncaam),
        // Mid-Major Conferences
        CollegeConference(id: "aac", name: "American Athletic", shortName: "AAC", sport: .ncaam),
        CollegeConference(id: "a10", name: "Atlantic 10", shortName: "A-10", sport: .ncaam),
        CollegeConference(id: "cusa", name: "Conference USA", shortName: "C-USA", sport: .ncaam),
        CollegeConference(id: "mac", name: "Mid-American", shortName: "MAC", sport: .ncaam),
        CollegeConference(id: "mwc", name: "Mountain West", shortName: "MWC", sport: .ncaam),
        CollegeConference(id: "mvc", name: "Missouri Valley", shortName: "MVC", sport: .ncaam),
        CollegeConference(id: "pac12", name: "Pac-12", shortName: "Pac-12", sport: .ncaam),
        CollegeConference(id: "sunbelt", name: "Sun Belt", shortName: "Sun Belt", sport: .ncaam),
        CollegeConference(id: "wcc", name: "West Coast", shortName: "WCC", sport: .ncaam),
        // Other conferences
        CollegeConference(id: "ivy", name: "Ivy League", shortName: "Ivy", sport: .ncaam),
        CollegeConference(id: "horizon", name: "Horizon League", shortName: "Horizon", sport: .ncaam),
        CollegeConference(id: "colonial", name: "Colonial Athletic", shortName: "CAA", sport: .ncaam),
        CollegeConference(id: "southland", name: "Southland", shortName: "Southland", sport: .ncaam),
        CollegeConference(id: "ovc", name: "Ohio Valley", shortName: "OVC", sport: .ncaam),
        CollegeConference(id: "big_sky", name: "Big Sky", shortName: "Big Sky", sport: .ncaam),
        CollegeConference(id: "summit", name: "Summit League", shortName: "Summit", sport: .ncaam),
        CollegeConference(id: "wac", name: "WAC", shortName: "WAC", sport: .ncaam),
        CollegeConference(id: "asun", name: "ASUN", shortName: "ASUN", sport: .ncaam),
        CollegeConference(id: "big_south", name: "Big South", shortName: "Big South", sport: .ncaam),
        CollegeConference(id: "patriot", name: "Patriot League", shortName: "Patriot", sport: .ncaam),
        CollegeConference(id: "socon", name: "Southern", shortName: "SoCon", sport: .ncaam),
        CollegeConference(id: "meac", name: "MEAC", shortName: "MEAC", sport: .ncaam),
        CollegeConference(id: "swac", name: "SWAC", shortName: "SWAC", sport: .ncaam),
        CollegeConference(id: "nec", name: "Northeast", shortName: "NEC", sport: .ncaam),
        CollegeConference(id: "american_east", name: "America East", shortName: "AE", sport: .ncaam),
        CollegeConference(id: "atlantic_sun", name: "Atlantic Sun", shortName: "A-Sun", sport: .ncaam),
        CollegeConference(id: "big_west", name: "Big West", shortName: "Big West", sport: .ncaam),
    ]
    
    /// Get conferences for a sport
    static func conferences(for sport: Sport) -> [CollegeConference] {
        switch sport {
        case .ncaaf:
            return ncaafConferences
        case .ncaam:
            return ncaamConferences
        default:
            return []
        }
    }
    
    /// Get default conference for a sport
    static func defaultConference(for sport: Sport) -> CollegeConference? {
        switch sport {
        case .ncaaf:
            return top25NCAAF
        case .ncaam:
            return top25NCAAM
        default:
            return nil
        }
    }
}

// MARK: - Sport Extension

extension Sport {
    /// Whether this is a college sport that supports conference filtering
    var isCollegeSport: Bool {
        return self == .ncaaf || self == .ncaam
    }
}
