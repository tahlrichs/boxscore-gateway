//
//  HomeViewModel.swift
//  BoxScore
//
//  View model for the home screen with @Observable (iOS 17+)
//

import Foundation
import SwiftUI

/// Loading state for async operations
enum LoadingState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}

@Observable
class HomeViewModel {
    
    // MARK: - Dependencies
    
    private let scoreboardRepository: ScoreboardRepository
    private let gameRepository: GameRepository
    
    // MARK: - Published State
    
    /// All games (unfiltered)
    private var allGames: [Game] = []
    
    /// Currently selected sport filter
    var selectedSport: Sport = .nba {
        didSet {
            if oldValue != selectedSport {
                // Reset conference when switching sports
                if selectedSport.isCollegeSport {
                    selectedConference = CollegeConference.defaultConference(for: selectedSport)
                } else {
                    selectedConference = nil
                }

                // Handle golf-specific loading
                if selectedSport.isGolf {
                    selectedTour = .all
                    selectedWeek = WeekSelector.mondayOfWeek(containing: Date())
                    Task { await loadTournaments() }
                } else {
                    Task {
                        await loadAvailableDates()
                        await loadGames()
                    }
                }
            }
        }
    }
    
    /// Currently selected date
    var selectedDate: Date = {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        // If before 11 AM, show yesterday's games
        if hour < 11 {
            return calendar.date(byAdding: .day, value: -1, to: now) ?? now
        }
        return now
    }() {
        didSet {
            if !Calendar.current.isDate(oldValue, inSameDayAs: selectedDate) {
                Task { await loadGames() }
            }
        }
    }
    
    /// Currently selected conference (for college sports)
    var selectedConference: CollegeConference? = nil

    /// Currently selected golf tour
    var selectedTour: GolfTour = .all {
        didSet {
            if oldValue != selectedTour {
                Task { await loadTournaments() }
            }
        }
    }

    /// Currently selected week (Monday of the week) for golf
    var selectedWeek: Date = WeekSelector.mondayOfWeek(containing: Date()) {
        didSet {
            if !Calendar.current.isDate(oldValue, inSameDayAs: selectedWeek) {
                Task { await loadTournaments() }
            }
        }
    }

    /// Available weeks for golf week selector
    var availableWeeks: [Date] = WeekSelector.generateWeeks(around: Date())

    /// Golf tournaments for the selected week
    var tournaments: [GolfTournament] = []

    /// Loading state for golf tournaments
    var tournamentsLoadingState: LoadingState = .idle

    /// Available dates for the date selector
    var availableDates: [Date] = []
    
    /// Expansion state per game (keyed by game ID)
    var expansionState: [String: GameExpansionState] = [:]
    
    /// NFL group expansion state (keyed by "gameId_teamSide_groupId")
    var nflGroupExpanded: [String: Bool] = [:]
    
    /// NFL section expansion state (keyed by "gameId_teamSide_sectionId")
    var nflSectionExpanded: [String: Bool] = [:]
    
    /// Loading state
    var loadingState: LoadingState = .idle
    
    /// Last update timestamp
    var lastUpdated: Date?
    
    /// Whether data is stale and being refreshed
    var isStale: Bool = false
    
    /// Error message for display
    var errorMessage: String?
    
    /// Active sports (sports that have games)
    var activeSports: [Sport] {
        Sport.allCases.filter { sport in
            allGames.contains { $0.sport == sport }
        }
    }
    
    /// Filtered games based on selected sport, date, and conference
    var filteredGames: [Game] {
        allGames.filter { game in
            // First filter by sport and date
            guard game.sport == selectedSport && Calendar.current.isDate(game.gameDate, inSameDayAs: selectedDate) else {
                return false
            }
            
            // Then filter by conference for college sports
            if selectedSport.isCollegeSport, let conference = selectedConference {
                return gameMatchesConference(game, conference: conference)
            }
            
            return true
        }
    }
    
    /// Check if a game matches the selected conference filter
    private func gameMatchesConference(_ game: Game, conference: CollegeConference) -> Bool {
        // "All" shows all games
        if conference.id == "all" {
            return true
        }
        
        // "Top 25" - for now, show all games (would need ranking data to properly filter)
        // TODO: Implement actual Top 25 filtering when ranking data is available
        if conference.id == "top25" {
            return true
        }
        
        // Check if either team is in the selected conference
        let homeConference = game.homeTeam.conference?.lowercased() ?? ""
        let awayConference = game.awayTeam.conference?.lowercased() ?? ""
        
        // If neither team has conference data, show the game (graceful degradation)
        // This handles cached data from before conference support was added
        if homeConference.isEmpty && awayConference.isEmpty {
            return true
        }
        
        let confName = conference.name.lowercased()
        let confShort = conference.shortName.lowercased()
        
        // Match if either team's conference matches the filter
        func matchesFilter(_ teamConf: String) -> Bool {
            guard !teamConf.isEmpty else { return false }
            return teamConf == confName || 
                   teamConf == confShort ||
                   teamConf.contains(confShort) ||
                   confShort.contains(teamConf) ||
                   teamConf.contains(confName) ||
                   confName.contains(teamConf)
        }
        
        return matchesFilter(homeConference) || matchesFilter(awayConference)
    }
    
    // MARK: - Initialization
    
    init(
        scoreboardRepository: ScoreboardRepository = .shared,
        gameRepository: GameRepository = .shared
    ) {
        self.scoreboardRepository = scoreboardRepository
        self.gameRepository = gameRepository

        // Initial load
        Task {
            await loadAvailableDates()
            await loadGames()
        }
    }
    
    // MARK: - Data Loading
    
    /// Load games from repository
    @MainActor
    func loadGames() async {
        loadingState = .loading
        errorMessage = nil
        
        do {
            let result = try await scoreboardRepository.getScoreboardWithMetadata(
                sport: selectedSport,
                date: selectedDate
            )
            
            // Update games - merge with existing for other sports
            updateGames(result.games, for: selectedSport)
            
            lastUpdated = result.lastUpdated
            isStale = result.isStale
            loadingState = .loaded
            
        } catch {
            loadingState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
            
            // Keep existing data on error - no mock data fallback
        }
    }
    
    /// Refresh games (pull-to-refresh)
    @MainActor
    func refreshGames() async {
        do {
            let games = try await scoreboardRepository.refreshScoreboard(
                sport: selectedSport,
                date: selectedDate
            )
            
            updateGames(games, for: selectedSport)
            lastUpdated = Date()
            isStale = false
            loadingState = .loaded
            
        } catch {
            // Don't show error on refresh, just keep existing data
            isStale = true
        }
    }

    // MARK: - Golf Tournament Loading

    /// Load golf tournaments for the selected week and tour
    @MainActor
    func loadTournaments() async {
        tournamentsLoadingState = .loading
        errorMessage = nil

        do {
            if selectedTour.isAll {
                // Fetch from both tours and combine
                async let pgaResponse = scoreboardRepository.getGolfScoreboard(tour: "pga", weekStart: selectedWeek)
                async let lpgaResponse = scoreboardRepository.getGolfScoreboard(tour: "lpga", weekStart: selectedWeek)

                let (pga, lpga) = try await (pgaResponse, lpgaResponse)
                tournaments = pga.tournaments + lpga.tournaments
            } else {
                let response = try await scoreboardRepository.getGolfScoreboard(
                    tour: selectedTour.id,
                    weekStart: selectedWeek
                )
                tournaments = response.tournaments
            }

            lastUpdated = Date()
            tournamentsLoadingState = .loaded

        } catch {
            tournamentsLoadingState = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    /// Refresh golf tournaments (pull-to-refresh)
    @MainActor
    func refreshTournaments() async {
        do {
            if selectedTour.isAll {
                // Fetch from both tours and combine
                async let pgaResponse = scoreboardRepository.getGolfScoreboard(tour: "pga", weekStart: selectedWeek)
                async let lpgaResponse = scoreboardRepository.getGolfScoreboard(tour: "lpga", weekStart: selectedWeek)

                let (pga, lpga) = try await (pgaResponse, lpgaResponse)
                tournaments = pga.tournaments + lpga.tournaments
            } else {
                let response = try await scoreboardRepository.getGolfScoreboard(
                    tour: selectedTour.id,
                    weekStart: selectedWeek
                )
                tournaments = response.tournaments
            }

            lastUpdated = Date()
            tournamentsLoadingState = .loaded

        } catch {
            // Don't show error on refresh, just keep existing data
            isStale = true
        }
    }

    /// Update games for a specific sport
    private func updateGames(_ newGames: [Game], for sport: Sport) {
        // Remove existing games for this sport and date
        allGames.removeAll { game in
            game.sport == sport && Calendar.current.isDate(game.gameDate, inSameDayAs: selectedDate)
        }
        
        // Add new games
        allGames.append(contentsOf: newGames)
        
        // Initialize expansion state for new games
        for game in newGames {
            if expansionState[game.id] == nil {
                expansionState[game.id] = GameExpansionState()
            }
        }
    }
    
    /// Load available dates from backend API
    @MainActor
    private func loadAvailableDates() async {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        // Determine target date based on time of day
        // If before 11 AM, target yesterday, otherwise target today
        let targetDate = hour < 11
            ? calendar.date(byAdding: .day, value: -1, to: now) ?? now
            : now
        let targetDayStart = calendar.startOfDay(for: targetDate)

        do {
            // Fetch dates from backend
            let dateStrings = try await scoreboardRepository.getAvailableDates(sport: selectedSport)

            // Convert date strings to Date objects
            // Use the user's calendar to ensure dates are interpreted correctly
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.calendar = Calendar.current
            formatter.timeZone = Calendar.current.timeZone

            let dates = dateStrings.compactMap { formatter.date(from: $0) }

            availableDates = dates

            // Set selected date to target date if it's in the available dates, otherwise use closest available date
            if dates.contains(where: { calendar.isDate($0, inSameDayAs: targetDayStart) }) {
                selectedDate = targetDayStart
            } else if let firstDate = dates.first {
                // Find the closest date to target date
                let closestDate = dates.min(by: { abs($0.timeIntervalSince(targetDayStart)) < abs($1.timeIntervalSince(targetDayStart)) })
                selectedDate = closestDate ?? firstDate
            }
        } catch {
            // Fallback to generating dates locally on error
            print("Failed to fetch available dates: \(error)")
            generateAvailableDatesFallback()
        }
    }

    /// Fallback method to generate dates locally if API fails
    private func generateAvailableDatesFallback() {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)

        // Determine target date based on time of day
        let targetDate = hour < 11
            ? calendar.date(byAdding: .day, value: -1, to: now) ?? now
            : now
        let targetDayStart = calendar.startOfDay(for: targetDate)

        // Combined season coverage for all sports:
        // NCAAF 2025: Aug 23, 2025 to Jan 20, 2026 (National Championship)
        // NFL 2025: Aug 1, 2025 (preseason) to Feb 8, 2026 (Super Bowl)
        // NBA 2025-26: Oct 4, 2025 (preseason) to Jun 22, 2026 (finals end)
        // NCAAM 2025-26: Nov 4, 2025 to Apr 6, 2026 (Final Four)
        // Generate dates from Aug 1, 2025 to Jun 22, 2026 to cover all sports
        var components = DateComponents()
        components.year = 2025
        components.month = 8
        components.day = 1
        let seasonStart = calendar.date(from: components) ?? targetDayStart

        components.year = 2026
        components.month = 6
        components.day = 22
        let seasonEnd = calendar.date(from: components) ?? targetDayStart

        var dates: [Date] = []
        var currentDate = seasonStart

        while currentDate <= seasonEnd {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        availableDates = dates

        // Set selected date to target date if within season, otherwise start of season
        if targetDayStart >= seasonStart && targetDayStart <= seasonEnd {
            selectedDate = targetDayStart
        } else if targetDayStart < seasonStart {
            selectedDate = seasonStart
        } else {
            selectedDate = seasonEnd
        }
    }
    
    // MARK: - Sport Selection
    
    func selectSport(_ sport: Sport) {
        selectedSport = sport
    }
    
    // MARK: - Date Selection
    
    func selectDate(_ date: Date) {
        selectedDate = date
    }
    
    // MARK: - Game Expansion
    
    func isAwayExpanded(for gameId: String) -> Bool {
        expansionState[gameId]?.awayExpanded ?? false
    }
    
    func isHomeExpanded(for gameId: String) -> Bool {
        expansionState[gameId]?.homeExpanded ?? false
    }
    
    func toggleAwayExpanded(for gameId: String) {
        expansionState[gameId]?.awayExpanded.toggle()
    }
    
    func toggleHomeExpanded(for gameId: String) {
        expansionState[gameId]?.homeExpanded.toggle()
    }
    
    // MARK: - NFL Nested Expansion
    
    func nflGroupKey(gameId: String, teamSide: TeamSide, groupId: String) -> String {
        "\(gameId)_\(teamSide.rawValue)_\(groupId)"
    }
    
    func nflSectionKey(gameId: String, teamSide: TeamSide, sectionId: String) -> String {
        "\(gameId)_\(teamSide.rawValue)_\(sectionId)"
    }
    
    func isNFLGroupExpanded(gameId: String, teamSide: TeamSide, groupId: String) -> Bool {
        let key = nflGroupKey(gameId: gameId, teamSide: teamSide, groupId: groupId)
        return nflGroupExpanded[key] ?? false
    }
    
    func isNFLSectionExpanded(gameId: String, teamSide: TeamSide, sectionId: String) -> Bool {
        let key = nflSectionKey(gameId: gameId, teamSide: teamSide, sectionId: sectionId)
        return nflSectionExpanded[key] ?? false
    }
    
    func toggleNFLGroup(gameId: String, teamSide: TeamSide, groupId: String) {
        let key = nflGroupKey(gameId: gameId, teamSide: teamSide, groupId: groupId)
        nflGroupExpanded[key] = !(nflGroupExpanded[key] ?? false)
    }
    
    func toggleNFLSection(gameId: String, teamSide: TeamSide, sectionId: String) {
        let key = nflSectionKey(gameId: gameId, teamSide: teamSide, sectionId: sectionId)
        nflSectionExpanded[key] = !(nflSectionExpanded[key] ?? false)
    }
    
    // MARK: - Box Score Loading
    
    /// Track which games are currently loading box scores
    var boxScoreLoadingState: [String: Bool] = [:]
    
    /// Check if a box score is currently loading
    func isBoxScoreLoading(gameId: String) -> Bool {
        boxScoreLoadingState[gameId] ?? false
    }
    
    /// Fetch box score for a game
    @MainActor
    func fetchBoxScore(for gameId: String) async {
        // Don't fetch if already loading
        guard boxScoreLoadingState[gameId] != true else { return }
        
        // Find the game to get its sport
        guard let game = allGames.first(where: { $0.id == gameId }) else { return }
        
        // Check if box score already has data
        let hasData: Bool
        switch game.awayBoxScore {
        case .nba(let boxScore):
            hasData = !boxScore.starters.isEmpty
        case .nfl(let boxScore):
            hasData = !boxScore.groups.isEmpty
        case .nhl(let boxScore):
            hasData = !boxScore.skaters.isEmpty
        }
        
        // Don't fetch if we already have data
        guard !hasData else { return }
        
        boxScoreLoadingState[gameId] = true
        
        do {
            let updatedGame = try await gameRepository.getBoxScore(gameId: gameId, sport: game.sport)
            
            // Update the game in allGames with the box score data
            if let index = allGames.firstIndex(where: { $0.id == gameId }) {
                allGames[index] = updatedGame
            }
        } catch {
            // Silently fail - the UI will show empty state
            print("Failed to fetch box score for \(gameId): \(error)")
        }
        
        boxScoreLoadingState[gameId] = false
    }
    
    // MARK: - Helpers
    
    func game(for id: String) -> Game? {
        allGames.first { $0.id == id }
    }
    
    /// Format last updated for display
    var lastUpdatedText: String? {
        guard let lastUpdated = lastUpdated else { return nil }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: lastUpdated, relativeTo: Date()))"
    }
}

// MARK: - Team Side

enum TeamSide: String {
    case away
    case home
}
