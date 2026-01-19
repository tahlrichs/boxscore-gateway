//
//  StandingsView.swift
//  BoxScore
//
//  Standings view with conference grouping
//

import SwiftUI

struct StandingsView: View {
    @State private var viewModel = StandingsViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Sport selector
            sportPicker
            
            // Content
            if viewModel.loadingState.isLoading && viewModel.standings.isEmpty {
                loadingView
            } else if viewModel.standings.isEmpty {
                emptyStateView
            } else {
                standingsList
            }
        }
        .refreshable {
            await viewModel.refreshStandings()
        }
    }
    
    // MARK: - Sport Picker
    
    private var sportPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Sport.allCases) { sport in
                    sportButton(sport)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
    
    private func sportButton(_ sport: Sport) -> some View {
        Button {
            viewModel.selectedSport = sport
        } label: {
            Text(sport.displayName)
                .font(.subheadline)
                .fontWeight(viewModel.selectedSport == sport ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    viewModel.selectedSport == sport
                        ? Color.black
                        : Color(.systemGray6)
                )
                .foregroundStyle(
                    viewModel.selectedSport == sport
                        ? .white
                        : .primary
                )
                .cornerRadius(8)
        }
    }
    
    // MARK: - Standings List
    
    private var standingsList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Last updated indicator
                if let lastUpdatedText = viewModel.lastUpdatedText {
                    HStack {
                        Text(lastUpdatedText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                
                // Conference sections
                ForEach(viewModel.conferences, id: \.self) { conference in
                    Section {
                        // Column headers
                        standingsHeader
                        
                        // Team rows
                        if let teams = viewModel.groupedStandings[conference] {
                            ForEach(teams) { standing in
                                standingRow(standing)
                            }
                        }
                    } header: {
                        conferenceSectionHeader(conference)
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Conference Header
    
    private func conferenceSectionHeader(_ conference: String) -> some View {
        HStack {
            Text(conference)
                .font(.headline)
                .fontWeight(.bold)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Standings Header
    
    private var standingsHeader: some View {
        HStack(spacing: 0) {
            Text("TEAM")
                .frame(width: 140, alignment: .leading)
            
            Text("W")
                .frame(width: 36, alignment: .center)
            
            Text("L")
                .frame(width: 36, alignment: .center)
            
            Text("PCT")
                .frame(width: 50, alignment: .center)
            
            Text("GB")
                .frame(width: 40, alignment: .center)
            
            Text("STRK")
                .frame(width: 44, alignment: .center)
            
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
    
    // MARK: - Standing Row
    
    private func standingRow(_ standing: Standing) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Rank and Team
                HStack(spacing: 8) {
                    Text("\(standing.rank)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .center)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(standing.teamAbbrev ?? "???")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(standing.teamName ?? "Unknown")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 140, alignment: .leading)
                
                // Wins
                Text("\(standing.wins)")
                    .font(.subheadline)
                    .frame(width: 36, alignment: .center)
                
                // Losses
                Text("\(standing.losses)")
                    .font(.subheadline)
                    .frame(width: 36, alignment: .center)
                
                // Win Percentage
                Text(String(format: "%.3f", standing.winPct))
                    .font(.subheadline)
                    .frame(width: 50, alignment: .center)
                
                // Games Back
                Text(formatGamesBack(standing.gamesBack))
                    .font(.subheadline)
                    .frame(width: 40, alignment: .center)
                
                // Streak
                Text(standing.streak ?? "-")
                    .font(.subheadline)
                    .foregroundStyle(streakColor(standing.streak))
                    .frame(width: 44, alignment: .center)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            Divider()
                .padding(.leading, 16)
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading standings...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.number")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("No Standings Available")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("Standings for \(viewModel.selectedSport.displayName) are not available")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Helpers
    
    private func formatGamesBack(_ gb: Double?) -> String {
        guard let gb = gb else { return "-" }
        if gb == 0 { return "-" }
        if gb.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", gb)
        }
        return String(format: "%.1f", gb)
    }
    
    private func streakColor(_ streak: String?) -> Color {
        guard let streak = streak else { return .primary }
        if streak.starts(with: "W") { return .green }
        if streak.starts(with: "L") { return .red }
        return .primary
    }
}

#Preview {
    StandingsView()
}
