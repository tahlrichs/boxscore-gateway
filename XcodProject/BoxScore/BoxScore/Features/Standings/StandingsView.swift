//
//  StandingsView.swift
//  BoxScore
//
//  Standings view with league/conference/division grouping
//

import SwiftUI

struct StandingsView: View {
    @Binding var selectedSport: Sport
    @State private var viewModel = StandingsViewModel()

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            // Grouping picker
            groupingPicker
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.cardBackground(for: appState.effectiveColorScheme))

            // Content
            if viewModel.loadingState.isLoading && viewModel.standings.isEmpty {
                loadingView
            } else if viewModel.standings.isEmpty {
                emptyStateView
            } else {
                standingsList
            }
        }
        .onChange(of: selectedSport) { _, newSport in
            viewModel.selectedSport = newSport
        }
        .refreshable {
            await viewModel.refreshStandings()
        }
        .onAppear {
            if viewModel.selectedSport != selectedSport {
                viewModel.selectedSport = selectedSport
            }
        }
    }

    // MARK: - Grouping Picker

    private var groupingPicker: some View {
        SegmentedPicker(
            selection: $viewModel.selectedGrouping,
            options: viewModel.availableGroupings,
            colorScheme: appState.effectiveColorScheme
        )
    }

    // MARK: - Standings List

    private var standingsList: some View {
        ScrollView {
            switch viewModel.selectedGrouping {
            case .league:
                leagueList
            case .conference:
                conferenceList
            case .division:
                divisionList
            }
        }
        .background(Theme.secondaryBackground(for: appState.effectiveColorScheme))
    }

    // MARK: - League List (flat ranked)

    private var leagueList: some View {
        LazyVStack(spacing: 0) {
            standingsHeader
            ForEach(Array(viewModel.leagueRankedStandings.enumerated()), id: \.element.id) { index, standing in
                standingRow(standing, overrideRank: index + 1)
            }
        }
    }

    // MARK: - Conference List (grouped by conference)

    private var conferenceList: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(viewModel.conferences, id: \.self) { conference in
                Section {
                    standingsHeader
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

    // MARK: - Division List (conference → division)

    private var divisionList: some View {
        LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
            ForEach(viewModel.divisionConferences, id: \.self) { conference in
                Section {
                    if let divisions = viewModel.divisionStandings[conference] {
                        ForEach(divisions, id: \.division) { divisionGroup in
                            divisionSubHeader(divisionGroup.division)
                            standingsHeader
                            ForEach(divisionGroup.teams) { standing in
                                standingRow(standing)
                            }
                        }
                    }
                } header: {
                    conferenceSectionHeader(conference)
                }
            }
        }
    }

    // MARK: - Conference Header

    private func conferenceSectionHeader(_ conference: String) -> some View {
        HStack {
            Text(conference)
                .font(Theme.displayFont(size: 17))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.cardBackground(for: appState.effectiveColorScheme))
    }

    // MARK: - Division Sub-Header

    private func divisionSubHeader(_ division: String) -> some View {
        HStack {
            Text(division)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.cardBackground(for: appState.effectiveColorScheme))
    }

    // MARK: - Standings Header

    private var standingsHeader: some View {
        HStack(spacing: 0) {
            Text("TEAM")
                .frame(width: 168, alignment: .leading)

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
        .background(Theme.separator(for: appState.effectiveColorScheme))
    }

    // MARK: - Standing Row

    private func standingRow(_ standing: Standing, overrideRank: Int? = nil) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Rank, Logo, and Team
                HStack(spacing: 6) {
                    Text("\(overrideRank ?? standing.rank)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .center)

                    teamLogo(for: standing)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(standing.teamAbbrev ?? "???")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(standing.teamName ?? "Unknown")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 168, alignment: .leading)

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
        .background(Theme.cardBackground(for: appState.effectiveColorScheme))
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
        .background(Theme.secondaryBackground(for: appState.effectiveColorScheme))
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
        .background(Theme.secondaryBackground(for: appState.effectiveColorScheme))
    }

    // MARK: - Team Logo

    @ViewBuilder
    private func teamLogo(for standing: Standing, size: CGFloat = 24) -> some View {
        let league = viewModel.selectedSport.rawValue.lowercased()
        let abbr = (standing.teamAbbrev ?? "").lowercased()
        let imageName = "team-\(league)-\(abbr)"
        if let _ = UIImage(named: imageName) {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Color.clear
                .frame(width: size, height: size)
        }
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
    StandingsView(selectedSport: .constant(.nba))
        .environment(AppState.shared)
}
