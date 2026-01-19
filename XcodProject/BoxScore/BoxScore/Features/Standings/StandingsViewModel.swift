//
//  StandingsViewModel.swift
//  BoxScore
//
//  View model for standings screen
//

import Foundation
import SwiftUI

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
    
    var standings: [Standing] = []
    var groupedStandings: [String: [Standing]] = [:]
    var conferences: [String] = []
    
    var loadingState: LoadingState = .idle
    var lastUpdated: Date?
    var isStale: Bool = false
    var errorMessage: String?
    
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
        // Group by conference
        var grouped: [String: [Standing]] = [:]
        
        for standing in standings {
            let conference = standing.conference ?? "League"
            if grouped[conference] == nil {
                grouped[conference] = []
            }
            grouped[conference]?.append(standing)
        }
        
        // Sort each conference by rank
        for (conference, teams) in grouped {
            grouped[conference] = teams.sorted { $0.rank < $1.rank }
        }
        
        groupedStandings = grouped
        conferences = grouped.keys.sorted()
    }
    
    /// Format last updated for display
    var lastUpdatedText: String? {
        guard let lastUpdated = lastUpdated else { return nil }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: lastUpdated, relativeTo: Date()))"
    }
}
