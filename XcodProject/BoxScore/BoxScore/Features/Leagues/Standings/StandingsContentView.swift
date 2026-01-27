//
//  StandingsContentView.swift
//  BoxScore
//
//  Standings content view (without sport picker) - uses AppState for sport selection
//

import SwiftUI

struct StandingsContentView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = StandingsViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Filter bar (show for pro sports with multiple filters or college sports)
            if viewModel.availableFilters.count > 1 || viewModel.isCollegeSport {
                filterBar
            }

            // Content
            Group {
                if viewModel.loadingState.isLoading && !viewModel.hasData {
                    loadingView
                } else if !viewModel.hasData {
                    emptyStateView
                } else {
                    standingsList
                }
            }
        }
        .refreshable {
            await viewModel.refreshStandings()
        }
        .onAppear {
            // Initialize viewModel's sport from shared state
            if viewModel.selectedSport != appState.selectedSport {
                viewModel.selectedSport = appState.selectedSport
            }
        }
        .onChange(of: appState.selectedSport) { _, newSport in
            // Sync shared state to viewModel
            if viewModel.selectedSport != newSport {
                viewModel.selectedSport = newSport
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack {
            Spacer()

            if viewModel.isCollegeSport {
                collegeFilterMenu
            } else {
                proFilterMenu
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.background(for: appState.effectiveColorScheme))
    }

    // MARK: - Pro Sports Filter Menu

    private var proFilterMenu: some View {
        Menu {
            ForEach(viewModel.availableFilters) { filter in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedFilter = filter
                    }
                } label: {
                    HStack {
                        Text(filter.title)
                        if viewModel.selectedFilter == filter {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.selectedFilter.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.separator(for: appState.effectiveColorScheme))
            .cornerRadius(6)
        }
    }

    // MARK: - College Sports Filter Menu

    private var collegeFilterMenu: some View {
        Menu {
            // Top 25
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.selectedCollegeFilter = .top25
                }
            } label: {
                HStack {
                    Text("Top 25")
                    if case .top25 = viewModel.selectedCollegeFilter {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            // Individual conferences
            ForEach(viewModel.availableConferences, id: \.self) { conference in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedCollegeFilter = .conference(conference)
                    }
                } label: {
                    HStack {
                        Text(conference)
                        if case .conference(let selected) = viewModel.selectedCollegeFilter,
                           selected == conference {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.selectedCollegeFilter.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.separator(for: appState.effectiveColorScheme))
            .cornerRadius(6)
        }
    }

    // MARK: - Standings List

    private var standingsList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Check if showing college Top 25 rankings
                if viewModel.isCollegeSport && !viewModel.groupedRankings.isEmpty {
                    Section {
                        rankingsHeader

                        ForEach(viewModel.groupedRankings) { team in
                            rankingRow(team)
                        }
                    } header: {
                        conferenceSectionHeader("AP Top 25")
                    }
                } else {
                    // Conference sections for standings
                    ForEach(viewModel.conferences, id: \.self) { conference in
                        Section {
                            // Column headers
                            standingsHeader

                            // Team rows
                            if let teams = viewModel.groupedStandings[conference] {
                                ForEach(Array(teams.enumerated()), id: \.element.id) { index, standing in
                                    standingRow(standing, position: index + 1)
                                }
                            }
                        } header: {
                            conferenceSectionHeader(conference)
                        }
                    }
                }
            }
        }
        .background(Theme.secondaryBackground(for: appState.effectiveColorScheme))
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
        .background(Theme.background(for: appState.effectiveColorScheme))
    }

    // MARK: - Standings Header

    private var standingsHeader: some View {
        HStack(spacing: 0) {
            Text("TEAM")
                .frame(width: 160, alignment: .leading)

            Text("W")
                .frame(width: 32, alignment: .center)

            Text("L")
                .frame(width: 32, alignment: .center)

            Text("PCT")
                .frame(width: 50, alignment: .center)

            Text("GB")
                .frame(width: 36, alignment: .center)

            Text("STRK")
                .frame(width: 40, alignment: .center)

            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - Standing Row

    private func standingRow(_ standing: Standing, position: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Position, Logo, and Team
                HStack(spacing: 8) {
                    Text("\(position)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .center)

                    // Team logo
                    teamLogo(for: standing)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(standing.teamAbbrev ?? "???")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(standing.teamName ?? "Unknown")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(width: 160, alignment: .leading)

                // Wins
                Text("\(standing.wins)")
                    .font(.subheadline)
                    .frame(width: 32, alignment: .center)

                // Losses
                Text("\(standing.losses)")
                    .font(.subheadline)
                    .frame(width: 32, alignment: .center)

                // Win Percentage
                Text(String(format: "%.3f", standing.winPct))
                    .font(.subheadline)
                    .frame(width: 50, alignment: .center)

                // Games Back
                Text(formatGamesBack(standing.gamesBack))
                    .font(.subheadline)
                    .frame(width: 36, alignment: .center)

                // Streak
                Text(standing.streak ?? "-")
                    .font(.subheadline)
                    .foregroundStyle(streakColor(standing.streak))
                    .frame(width: 40, alignment: .center)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
                .padding(.leading, 16)
        }
        .background(Theme.background(for: appState.effectiveColorScheme))
    }

    // MARK: - Rankings Header (College)

    private var rankingsHeader: some View {
        HStack(spacing: 0) {
            Text("TEAM")
                .frame(width: 180, alignment: .leading)

            Text("RECORD")
                .frame(width: 70, alignment: .center)

            Text("TREND")
                .frame(width: 50, alignment: .center)

            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - Ranking Row (College)

    private func rankingRow(_ team: RankedTeam) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Rank, Logo, and Team
                HStack(spacing: 8) {
                    Text("\(team.rank)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, alignment: .center)

                    // Team logo from URL
                    rankingLogo(for: team)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(team.location)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(team.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(width: 180, alignment: .leading)

                // Record
                Text(team.record)
                    .font(.subheadline)
                    .frame(width: 70, alignment: .center)

                // Trend
                Text(formatTrend(team.trend))
                    .font(.subheadline)
                    .foregroundStyle(trendColor(team.trend))
                    .frame(width: 50, alignment: .center)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
                .padding(.leading, 16)
        }
        .background(Theme.background(for: appState.effectiveColorScheme))
    }

    // MARK: - Team Logo (Standings)

    @ViewBuilder
    private func teamLogo(for standing: Standing) -> some View {
        let abbrev = standing.teamAbbrev?.lowercased() ?? ""
        let assetName = "team-\(standing.leagueId)-\(abbrev)"

        if let _ = UIImage(named: assetName) {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // Fallback placeholder
            Circle()
                .fill(Theme.separator(for: appState.effectiveColorScheme))
                .overlay {
                    Text(standing.teamAbbrev?.prefix(2) ?? "?")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
        }
    }

    // MARK: - Ranking Logo (from URL)

    @ViewBuilder
    private func rankingLogo(for team: RankedTeam) -> some View {
        if let logoUrl = team.logoUrl, let url = URL(string: logoUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure, .empty:
                    logoPlaceholder(abbrev: team.abbrev)
                @unknown default:
                    logoPlaceholder(abbrev: team.abbrev)
                }
            }
        } else {
            logoPlaceholder(abbrev: team.abbrev)
        }
    }

    private func logoPlaceholder(abbrev: String) -> some View {
        Circle()
            .fill(Theme.separator(for: appState.effectiveColorScheme))
            .overlay {
                Text(abbrev.prefix(2))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
            }
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

            Text("Standings for \(appState.selectedSport.displayName) are not available")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.secondaryBackground(for: appState.effectiveColorScheme))
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

    private func formatTrend(_ trend: String?) -> String {
        guard let trend = trend else { return "-" }
        if trend == "-" { return "-" }
        return trend
    }

    private func trendColor(_ trend: String?) -> Color {
        guard let trend = trend, trend != "-" else { return .primary }
        if trend.hasPrefix("+") { return .green }
        if trend.hasPrefix("-") { return .red }
        return .primary
    }
}

#Preview {
    StandingsContentView()
        .environment(AppState.shared)
}
