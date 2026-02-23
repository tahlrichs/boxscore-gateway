//
//  StandingsViewModel.swift
//  BoxScore
//
//  View model for standings screen
//

import Foundation
import SwiftUI

enum StandingsGrouping: String, CaseIterable {
    case league = "League"
    case conference = "Conference"
    case division = "Division"
}

@Observable
class StandingsViewModel {

    // MARK: - Dependencies

    private let standingsRepository: StandingsRepository

    // MARK: - State

    var selectedSport: Sport = .nba {
        didSet {
            if oldValue != selectedSport {
                Task { await loadStandings() }
            }
        }
    }

    var selectedGrouping: StandingsGrouping = .conference {
        didSet {
            if oldValue != selectedGrouping {
                groupStandings()
            }
        }
    }

    var standings: [Standing] = []
    var groupedStandings: [String: [Standing]] = [:]
    var conferences: [String] = []

    // Division mode: conference → division → teams
    var divisionStandings: [String: [(division: String, teams: [Standing])]] = [:]
    var divisionConferences: [String] = []

    // League mode: flat ranked list
    var leagueRankedStandings: [Standing] = []

    var loadingState: LoadingState = .idle
    var lastUpdated: Date?
    var isStale: Bool = false
    var errorMessage: String?

    // MARK: - Division Lookup

    private static let divisionsByTeam: [String: [String: String]] = [
        "nba": [
            "BOS": "Atlantic", "BKN": "Atlantic", "NYK": "Atlantic", "PHI": "Atlantic", "TOR": "Atlantic",
            "CHI": "Central", "CLE": "Central", "DET": "Central", "IND": "Central", "MIL": "Central",
            "ATL": "Southeast", "CHA": "Southeast", "MIA": "Southeast", "ORL": "Southeast", "WAS": "Southeast",
            "DEN": "Northwest", "MIN": "Northwest", "OKC": "Northwest", "POR": "Northwest", "UTA": "Northwest",
            "GSW": "Pacific", "LAC": "Pacific", "LAL": "Pacific", "PHX": "Pacific", "SAC": "Pacific",
            "DAL": "Southwest", "HOU": "Southwest", "MEM": "Southwest", "NOP": "Southwest", "SAS": "Southwest",
        ],
        "nfl": [
            "BUF": "AFC East", "MIA": "AFC East", "NE": "AFC East", "NYJ": "AFC East",
            "BAL": "AFC North", "CIN": "AFC North", "CLE": "AFC North", "PIT": "AFC North",
            "HOU": "AFC South", "IND": "AFC South", "JAX": "AFC South", "TEN": "AFC South",
            "DEN": "AFC West", "KC": "AFC West", "LV": "AFC West", "LAC": "AFC West",
            "DAL": "NFC East", "NYG": "NFC East", "PHI": "NFC East", "WSH": "NFC East",
            "CHI": "NFC North", "DET": "NFC North", "GB": "NFC North", "MIN": "NFC North",
            "ATL": "NFC South", "CAR": "NFC South", "NO": "NFC South", "TB": "NFC South",
            "ARI": "NFC West", "LAR": "NFC West", "SF": "NFC West", "SEA": "NFC West",
        ],
        "nhl": [
            "BOS": "Atlantic", "BUF": "Atlantic", "DET": "Atlantic", "FLA": "Atlantic",
            "MTL": "Atlantic", "OTT": "Atlantic", "TB": "Atlantic", "TOR": "Atlantic",
            "CAR": "Metropolitan", "CBJ": "Metropolitan", "NJ": "Metropolitan", "NYI": "Metropolitan",
            "NYR": "Metropolitan", "PHI": "Metropolitan", "PIT": "Metropolitan", "WSH": "Metropolitan",
            "ARI": "Central", "CHI": "Central", "COL": "Central", "DAL": "Central",
            "MIN": "Central", "NSH": "Central", "STL": "Central", "WPG": "Central",
            "ANA": "Pacific", "CGY": "Pacific", "EDM": "Pacific", "LA": "Pacific",
            "SEA": "Pacific", "SJ": "Pacific", "VAN": "Pacific", "VGK": "Pacific",
        ],
        "mlb": [
            "BAL": "AL East", "BOS": "AL East", "NYY": "AL East", "TB": "AL East", "TOR": "AL East",
            "CLE": "AL Central", "CWS": "AL Central", "DET": "AL Central", "KC": "AL Central", "MIN": "AL Central",
            "HOU": "AL West", "LAA": "AL West", "OAK": "AL West", "SEA": "AL West", "TEX": "AL West",
            "ATL": "NL East", "MIA": "NL East", "NYM": "NL East", "PHI": "NL East", "WSH": "NL East",
            "CHC": "NL Central", "CIN": "NL Central", "MIL": "NL Central", "PIT": "NL Central", "STL": "NL Central",
            "ARI": "NL West", "COL": "NL West", "LAD": "NL West", "SD": "NL West", "SF": "NL West",
        ],
    ]

    // MARK: - Computed

    var availableGroupings: [StandingsGrouping] {
        let sportKey = selectedSport.rawValue
        guard let lookup = Self.divisionsByTeam[sportKey] else {
            return [.league, .conference]
        }
        // Check if any current standings match a team in the lookup
        let hasDivisionData = standings.contains { standing in
            guard let abbrev = standing.teamAbbrev else { return false }
            return lookup[abbrev] != nil
        }
        return hasDivisionData ? StandingsGrouping.allCases : [.league, .conference]
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
            let result = try await standingsRepository.getStandingsWithMetadata(
                sport: selectedSport,
                season: nil
            )

            standings = result.standings

            // Reset grouping if division not available for this sport
            if selectedGrouping == .division && !availableGroupings.contains(.division) {
                selectedGrouping = .conference
            }

            groupStandings()

            lastUpdated = result.lastUpdated
            isStale = result.isStale
            loadingState = .loaded

        } catch {
            loadingState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func refreshStandings() async {
        do {
            let freshStandings = try await standingsRepository.refreshStandings(
                sport: selectedSport,
                season: nil
            )

            standings = freshStandings
            groupStandings()

            lastUpdated = Date()
            isStale = false
            loadingState = .loaded

        } catch {
            // Keep existing data on refresh error
            isStale = true
        }
    }

    // MARK: - Private Methods

    private func groupStandings() {
        switch selectedGrouping {
        case .league:
            groupByLeague()
        case .conference:
            groupByConference()
        case .division:
            groupByDivision()
        }
    }

    private func groupByLeague() {
        leagueRankedStandings = standings.sorted { $0.winPct > $1.winPct }
        // Clear conference/division data
        groupedStandings = [:]
        conferences = []
        divisionStandings = [:]
        divisionConferences = []
    }

    private func groupByConference() {
        var grouped: [String: [Standing]] = [:]

        for standing in standings {
            let conference = standing.conference ?? "League"
            grouped[conference, default: []].append(standing)
        }

        // Sort each conference by win percentage (best first)
        for (conference, teams) in grouped {
            grouped[conference] = teams.sorted { $0.winPct > $1.winPct }
        }

        groupedStandings = grouped
        conferences = grouped.keys.sorted()

        // Clear other mode data
        leagueRankedStandings = []
        divisionStandings = [:]
        divisionConferences = []
    }

    private func groupByDivision() {
        let sportKey = selectedSport.rawValue
        let lookup = Self.divisionsByTeam[sportKey] ?? [:]

        // First group by conference
        var byConference: [String: [String: [Standing]]] = [:]

        for standing in standings {
            let conference = standing.conference ?? "League"
            let division = lookup[standing.teamAbbrev ?? ""] ?? "Other"
            byConference[conference, default: [:]][division, default: []].append(standing)
        }

        // Sort and structure for the view
        var result: [String: [(division: String, teams: [Standing])]] = [:]

        for (conference, divisions) in byConference {
            let sortedDivisions = divisions.keys.sorted().map { divName in
                (division: divName, teams: divisions[divName]!.sorted { $0.winPct > $1.winPct })
            }
            result[conference] = sortedDivisions
        }

        divisionStandings = result
        divisionConferences = result.keys.sorted()

        // Clear other mode data
        leagueRankedStandings = []
        groupedStandings = [:]
        conferences = []
    }

    /// Format last updated for display
    var lastUpdatedText: String? {
        guard let lastUpdated = lastUpdated else { return nil }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: lastUpdated, relativeTo: Date()))"
    }
}
