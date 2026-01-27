//
//  TeamsListView.swift
//  BoxScore
//
//  Teams list view showing all teams for the selected sport
//

import SwiftUI

struct TeamsListView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = TeamsListViewModel()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Filter bar for college sports
                if viewModel.isCollegeSport {
                    filterBar
                }

                Group {
                    if viewModel.loadingState.isLoading && viewModel.teams.isEmpty {
                        loadingView
                    } else if viewModel.filteredTeams.isEmpty {
                        emptyStateView
                    } else {
                        teamsList
                    }
                }
            }
            .navigationDestination(for: TeamItem.self) { team in
                TeamDetailPlaceholderView(team: team)
            }
        }
        .refreshable {
            await viewModel.refreshTeams(for: appState.selectedSport)
        }
        .onAppear {
            Task {
                await viewModel.loadTeams(for: appState.selectedSport)
            }
        }
        .onChange(of: appState.selectedSport) { _, newSport in
            Task {
                await viewModel.loadTeams(for: newSport)
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        HStack {
            Spacer()

            Menu {
                // All Teams
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectedCollegeFilter = .all
                    }
                } label: {
                    HStack {
                        Text("All Teams")
                        if case .all = viewModel.selectedCollegeFilter {
                            Image(systemName: "checkmark")
                        }
                    }
                }

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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.background(for: appState.effectiveColorScheme))
    }

    // MARK: - Teams List

    private var teamsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Team rows (use filtered list)
                ForEach(viewModel.filteredTeams) { team in
                    Button {
                        navigationPath.append(team)
                    } label: {
                        teamRow(team)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(Theme.secondaryBackground(for: appState.effectiveColorScheme))
    }

    // MARK: - Team Row

    private func teamRow(_ team: TeamItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Team logo
                teamLogo(for: team)
                    .frame(width: 36, height: 36)

                // Team name
                VStack(alignment: .leading, spacing: 2) {
                    Text(team.fullName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(team.abbrev)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()
                .padding(.leading, 64)
        }
        .background(Theme.background(for: appState.effectiveColorScheme))
    }

    // MARK: - Team Logo

    @ViewBuilder
    private func teamLogo(for team: TeamItem) -> some View {
        let assetName = "team-\(appState.selectedSport.leagueId)-\(team.abbrev.lowercased())"

        if let _ = UIImage(named: assetName) {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // Fallback placeholder
            Circle()
                .fill(Theme.separator(for: appState.effectiveColorScheme))
                .overlay {
                    Text(team.abbrev.prefix(2))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading teams...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.secondaryBackground(for: appState.effectiveColorScheme))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            if viewModel.teams.isEmpty {
                Text("No Teams Available")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Teams for \(appState.selectedSport.displayName) are not available")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            } else {
                // Filter returned no results
                Text("No Teams Found")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("No teams match the current filter")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.secondaryBackground(for: appState.effectiveColorScheme))
    }
}

#Preview {
    TeamsListView()
        .environment(AppState.shared)
}
