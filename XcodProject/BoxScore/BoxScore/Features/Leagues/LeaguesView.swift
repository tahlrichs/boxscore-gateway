//
//  LeaguesView.swift
//  BoxScore
//
//  Main container for Leagues tab with sub-tabs (Standings, Teams, Stats)
//

import SwiftUI

struct LeaguesView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedSubTab: LeaguesSubTab = .standings

    var body: some View {
        VStack(spacing: 0) {
            if appState.selectedSport.isTeamBased {
                // Sub-tab bar (only for team sports)
                LeaguesSubTabBar(selectedTab: $selectedSubTab)

                // Content based on selected sub-tab
                switch selectedSubTab {
                case .standings:
                    StandingsContentView()
                case .teams:
                    TeamsListView()
                case .stats:
                    StatsPlaceholderView()
                }
            } else {
                // Golf - not team-based
                golfNotSupportedView
            }
        }
    }

    // MARK: - Golf Not Supported

    private var golfNotSupportedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("Not Available for Golf")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Leagues features are not available for golf.\nSwitch to a team sport to view standings, teams, and stats.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.secondaryBackground(for: appState.effectiveColorScheme))
    }
}

#Preview {
    LeaguesView()
        .environment(AppState.shared)
}
