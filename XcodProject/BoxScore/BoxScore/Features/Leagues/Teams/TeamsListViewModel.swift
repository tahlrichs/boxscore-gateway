//
//  TeamsListViewModel.swift
//  BoxScore
//
//  View model for teams list
//

import Foundation
import SwiftUI

/// College teams filter options
enum CollegeTeamsFilter: Hashable, Identifiable {
    case all               // Show all teams
    case top25             // Show Top 25 ranked teams
    case conference(String) // Show specific conference

    var id: String {
        switch self {
        case .all: return "all"
        case .top25: return "top25"
        case .conference(let name): return name
        }
    }

    var title: String {
        switch self {
        case .all: return "All Teams"
        case .top25: return "Top 25"
        case .conference(let name): return name
        }
    }
}

@Observable
class TeamsListViewModel {

    // MARK: - Dependencies

    private let teamsRepository: TeamsRepository
    private let standingsRepository: StandingsRepository

    // MARK: - State

    var teams: [TeamItem] = []
    var rankedTeams: [RankedTeam] = []  // For Top 25 filtering
    var loadingState: LoadingState = .idle
    var lastUpdated: Date?
    var errorMessage: String?

    /// Currently selected sport (observed from AppState)
    private var currentSport: Sport = .nba

    /// Current filter selection for college sports
    var selectedCollegeFilter: CollegeTeamsFilter = .all

    /// All available conferences in the current data
    var availableConferences: [String] = []

    /// Check if current sport is college
    var isCollegeSport: Bool {
        currentSport.isCollegeSport
    }

    /// Filtered teams based on current filter
    var filteredTeams: [TeamItem] {
        guard currentSport.isCollegeSport else {
            return teams
        }

        switch selectedCollegeFilter {
        case .all:
            return teams
        case .top25:
            // Filter to only teams that are in the Top 25
            let rankedIds = Set(rankedTeams.map { $0.teamId })
            let rankedAbbrevs = Set(rankedTeams.map { $0.abbrev.lowercased() })
            return teams.filter { team in
                rankedIds.contains(team.id) || rankedAbbrevs.contains(team.abbrev.lowercased())
            }.sorted { team1, team2 in
                // Sort by rank
                let rank1 = rankedTeams.first { $0.abbrev.lowercased() == team1.abbrev.lowercased() }?.rank ?? 999
                let rank2 = rankedTeams.first { $0.abbrev.lowercased() == team2.abbrev.lowercased() }?.rank ?? 999
                return rank1 < rank2
            }
        case .conference(let confName):
            return teams.filter { $0.conference == confName }
        }
    }

    // MARK: - Initialization

    init(
        teamsRepository: TeamsRepository = .shared,
        standingsRepository: StandingsRepository = .shared
    ) {
        self.teamsRepository = teamsRepository
        self.standingsRepository = standingsRepository
    }

    // MARK: - Public Methods

    @MainActor
    func loadTeams(for sport: Sport) async {
        // Always reload if sport changed
        let sportChanged = sport != currentSport

        // Skip only if same sport, already have data, and already loaded
        if !sportChanged && !teams.isEmpty && loadingState == .loaded {
            return
        }

        // Clear teams and reset filter if sport changed
        if sportChanged {
            teams = []
            rankedTeams = []
            selectedCollegeFilter = .all
            availableConferences = []
        }

        currentSport = sport
        loadingState = .loading
        errorMessage = nil

        do {
            // For college sports, load teams, rankings, and standings (for conference data)
            if sport.isCollegeSport {
                async let teamsTask = teamsRepository.getTeamsWithMetadata(sport: sport)
                async let rankingsTask = standingsRepository.getRankings(sport: sport)
                async let standingsTask = standingsRepository.getStandings(sport: sport, season: nil)

                let (result, rankings, standings) = try await (teamsTask, rankingsTask, standingsTask)

                // Build conference mapping from standings
                var conferenceMap: [String: String] = [:]
                for standing in standings {
                    if let abbrev = standing.teamAbbrev?.lowercased(), let conf = standing.conference {
                        conferenceMap[abbrev] = conf
                    }
                }

                // Apply conference data to teams
                teams = result.teams.map { team in
                    let conf = conferenceMap[team.abbrev.lowercased()] ?? team.conference
                    return TeamItem(
                        id: team.id,
                        abbrev: team.abbrev,
                        name: team.name,
                        city: team.city,
                        logoURL: team.logoURL,
                        primaryColor: team.primaryColor,
                        conference: conf,
                        division: team.division
                    )
                }
                rankedTeams = rankings
                lastUpdated = result.lastUpdated
                updateAvailableConferences()
            } else {
                let result = try await teamsRepository.getTeamsWithMetadata(sport: sport)
                teams = result.teams
                rankedTeams = []
                lastUpdated = result.lastUpdated
            }
            loadingState = .loaded
        } catch {
            loadingState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    private func updateAvailableConferences() {
        let uniqueConfs = Set(teams.compactMap { $0.conference })
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

    @MainActor
    func refreshTeams(for sport: Sport) async {
        currentSport = sport

        do {
            let fetchedTeams = try await teamsRepository.getTeams(sport: sport)
            teams = fetchedTeams
            lastUpdated = Date()
            loadingState = .loaded
        } catch {
            // Keep existing data on refresh error
            errorMessage = "Failed to refresh: \(error.localizedDescription)"
        }
    }

    /// Format last updated for display
    var lastUpdatedText: String? {
        guard let lastUpdated = lastUpdated else { return nil }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: lastUpdated, relativeTo: Date()))"
    }
}
