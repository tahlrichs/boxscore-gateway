//
//  StandingsViewModel.swift
//  BoxScore
//
//  View model for standings screen
//

import Foundation
import SwiftUI

/// Standings filter options for pro sports
enum StandingsFilter: Hashable, Identifiable, CaseIterable {
    case league          // Show all teams by league/conference
    case conference      // Show teams grouped by conference
    case division        // Show teams grouped by division (NFL, NHL, MLB)

    var id: Self { self }

    var title: String {
        switch self {
        case .league: return "League"
        case .conference: return "Conference"
        case .division: return "Division"
        }
    }

    /// Which sports support this filter
    func isAvailable(for sport: Sport) -> Bool {
        switch self {
        case .league:
            return true
        case .conference:
            // All major sports have conferences
            return !sport.isCollegeSport && !sport.isGolf
        case .division:
            // NBA, NFL, NHL, MLB have divisions
            return sport == .nba || sport == .nfl || sport == .nhl || sport == .mlb
        }
    }

    static func availableFilters(for sport: Sport) -> [StandingsFilter] {
        StandingsFilter.allCases.filter { $0.isAvailable(for: sport) }
    }
}

/// College standings filter options
enum CollegeStandingsFilter: Hashable, Identifiable {
    case top25            // Show Top 25 ranked teams
    case conference(String) // Show specific conference

    var id: String {
        switch self {
        case .top25: return "top25"
        case .conference(let name): return name
        }
    }

    var title: String {
        switch self {
        case .top25: return "Top 25"
        case .conference(let name): return name
        }
    }
}

@Observable
class StandingsViewModel {

    // MARK: - Dependencies

    private let standingsRepository: StandingsRepository

    // MARK: - State

    var selectedSport: Sport = .nba {
        didSet {
            if oldValue != selectedSport {
                // Reset filters when sport changes
                selectedFilter = .league
                selectedCollegeFilter = .top25
                Task { await loadStandings() }
            }
        }
    }

    /// Current filter selection for pro sports
    var selectedFilter: StandingsFilter = .league {
        didSet {
            if oldValue != selectedFilter {
                groupStandings()
            }
        }
    }

    /// Current filter selection for college sports
    var selectedCollegeFilter: CollegeStandingsFilter = .top25 {
        didSet {
            // Avoid infinite loop with id comparison
            if oldValue.id != selectedCollegeFilter.id {
                groupStandings()
            }
        }
    }

    var standings: [Standing] = []
    var rankedTeams: [RankedTeam] = []    // AP Top 25 rankings for college
    var groupedStandings: [String: [Standing]] = [:]
    var groupedRankings: [RankedTeam] = []  // Top 25 display for college
    var conferences: [String] = []

    /// All available conferences in the current data (for college filter)
    var availableConferences: [String] = []

    var loadingState: LoadingState = .idle
    var errorMessage: String?

    /// Available filters for the current sport
    var availableFilters: [StandingsFilter] {
        StandingsFilter.availableFilters(for: selectedSport)
    }

    /// Check if current sport is college
    var isCollegeSport: Bool {
        selectedSport.isCollegeSport
    }
    
    // MARK: - Initialization
    
    init(standingsRepository: StandingsRepository = .shared) {
        self.standingsRepository = standingsRepository
        Task { await loadStandings() }
    }
    
    // MARK: - Public Methods
    
    @MainActor
    func loadStandings() async {
        loadingState = .loading
        errorMessage = nil

        do {
            // For college sports, load both standings and rankings
            if selectedSport.isCollegeSport {
                async let standingsTask = standingsRepository.getStandingsWithMetadata(
                    sport: selectedSport,
                    season: nil
                )
                async let rankingsTask = standingsRepository.getRankings(sport: selectedSport)

                let (result, rankings) = try await (standingsTask, rankingsTask)
                standings = result.standings
                rankedTeams = rankings
            } else {
                let result = try await standingsRepository.getStandingsWithMetadata(
                    sport: selectedSport,
                    season: nil
                )
                standings = result.standings
                rankedTeams = []
            }

            groupStandings()
            loadingState = .loaded

        } catch {
            loadingState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func refreshStandings() async {
        do {
            if selectedSport.isCollegeSport {
                async let standingsTask = standingsRepository.refreshStandings(
                    sport: selectedSport,
                    season: nil
                )
                async let rankingsTask = standingsRepository.getRankings(sport: selectedSport)

                let (freshStandings, rankings) = try await (standingsTask, rankingsTask)
                standings = freshStandings
                rankedTeams = rankings
            } else {
                let freshStandings = try await standingsRepository.refreshStandings(
                    sport: selectedSport,
                    season: nil
                )
                standings = freshStandings
                rankedTeams = []
            }

            groupStandings()
            loadingState = .loaded

        } catch {
            // Keep existing data on refresh error
        }
    }
    
    // MARK: - Private Methods

    private func groupStandings() {
        // First, extract all unique conferences for the filter dropdown
        updateAvailableConferences()

        // Group based on sport type
        if selectedSport.isCollegeSport {
            groupCollegeStandings()
        } else {
            groupProStandings()
        }
    }

    private func updateAvailableConferences() {
        let uniqueConfs = Set(standings.compactMap { $0.conference })
        // Sort conferences, putting major ones first
        let majorConfs = ["ACC", "Big Ten", "Big 12", "SEC", "Pac-12", "Big East", "American", "Mountain West"]
        availableConferences = uniqueConfs.sorted { conf1, conf2 in
            let idx1 = majorConfs.firstIndex(where: { conf1.contains($0) }) ?? Int.max
            let idx2 = majorConfs.firstIndex(where: { conf2.contains($0) }) ?? Int.max
            if idx1 != idx2 {
                return idx1 < idx2
            }
            return conf1 < conf2
        }
    }

    private func groupCollegeStandings() {
        var grouped: [String: [Standing]] = [:]

        switch selectedCollegeFilter {
        case .top25:
            // Use AP Top 25 rankings data (not standings)
            groupedRankings = rankedTeams
            groupedStandings = [:]
            conferences = rankedTeams.isEmpty ? [] : ["AP Top 25"]
            return

        case .conference(let confName):
            // Show only teams from the selected conference
            let confTeams = standings.filter { $0.conference == confName }
            if !confTeams.isEmpty {
                grouped[confName] = confTeams
            }
        }

        // Sort each group by win percentage (best first)
        for (group, teams) in grouped {
            grouped[group] = teams.sorted { $0.winPct > $1.winPct }
        }

        groupedRankings = []
        groupedStandings = grouped
        conferences = grouped.keys.sorted()
    }

    private func groupProStandings() {
        var grouped: [String: [Standing]] = [:]

        switch selectedFilter {
        case .league:
            // Show all teams in one flat list, sorted by win percentage
            let allTeams = standings.sorted { $0.winPct > $1.winPct }
            grouped["League Standings"] = allTeams

        case .conference:
            // Group by conference (Eastern/Western for NBA, AFC/NFC for NFL, etc.)
            for standing in standings {
                let conf = standing.conference ?? "League"
                let confOnly = extractConferenceName(from: conf)
                if grouped[confOnly] == nil {
                    grouped[confOnly] = []
                }
                grouped[confOnly]?.append(standing)
            }

        case .division:
            // Group by full conference/division name (e.g., "AFC East", "NFC West")
            for standing in standings {
                let group = standing.conference ?? "League"
                if grouped[group] == nil {
                    grouped[group] = []
                }
                grouped[group]?.append(standing)
            }
        }

        // Sort each group by win percentage (best first)
        for (group, teams) in grouped {
            grouped[group] = teams.sorted { $0.winPct > $1.winPct }
        }

        groupedStandings = grouped
        // Sort conferences with a specific order for common cases
        conferences = sortConferences(Array(grouped.keys))
    }

    /// Sort conferences in a logical order (East before West, etc.)
    private func sortConferences(_ names: [String]) -> [String] {
        let order = ["League Standings", "Eastern Conference", "Western Conference", "AFC", "NFC", "American League", "National League"]
        return names.sorted { name1, name2 in
            let idx1 = order.firstIndex(where: { name1.contains($0) }) ?? Int.max
            let idx2 = order.firstIndex(where: { name2.contains($0) }) ?? Int.max
            if idx1 != idx2 {
                return idx1 < idx2
            }
            return name1 < name2
        }
    }

    /// Extract conference name from a combined conference-division string
    private func extractConferenceName(from fullName: String) -> String {
        // Handle formats like "American Football Conference - AFC East" or "AFC - East"
        if fullName.contains(" - ") {
            let parts = fullName.components(separatedBy: " - ")
            return parts[0].trimmingCharacters(in: .whitespaces)
        }
        // Handle formats like "AFC East" -> "AFC"
        let knownConferences = ["AFC", "NFC", "American", "National", "Eastern", "Western", "AL", "NL"]
        for conf in knownConferences {
            if fullName.hasPrefix(conf) {
                return conf == "American" ? "American League" :
                       conf == "National" ? "National League" :
                       conf == "Eastern" ? "Eastern Conference" :
                       conf == "Western" ? "Western Conference" : conf
            }
        }
        return fullName
    }
    
    /// Check if there's any data to display
    var hasData: Bool {
        !standings.isEmpty || !rankedTeams.isEmpty
    }
}
