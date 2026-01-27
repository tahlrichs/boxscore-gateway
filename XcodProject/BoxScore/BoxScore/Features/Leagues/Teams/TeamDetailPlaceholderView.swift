//
//  TeamDetailPlaceholderView.swift
//  BoxScore
//
//  Placeholder view for team detail (coming soon)
//

import SwiftUI

struct TeamDetailPlaceholderView: View {
    @Environment(AppState.self) private var appState
    let team: TeamItem

    var body: some View {
        VStack(spacing: 24) {
            // Team logo
            teamLogo
                .frame(width: 100, height: 100)

            // Team name
            VStack(spacing: 4) {
                Text(team.fullName)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(team.abbrev)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
                .frame(height: 20)

            // Coming soon message
            VStack(spacing: 12) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)

                Text("Team Details Coming Soon")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("Roster, schedule, and stats will be available in a future update.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Team Logo

    @ViewBuilder
    private var teamLogo: some View {
        let assetName = "team-\(appState.selectedSport.leagueId)-\(team.abbrev.lowercased())"

        if let _ = UIImage(named: assetName) {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // Fallback placeholder
            Circle()
                .fill(Color(.systemGray5))
                .overlay {
                    Text(team.abbrev.prefix(3))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
        }
    }
}

#Preview {
    NavigationStack {
        TeamDetailPlaceholderView(team: TeamItem(
            id: "nba_1610612747",
            abbrev: "LAL",
            name: "Lakers",
            city: "Los Angeles",
            logoURL: nil,
            primaryColor: "#552583",
            conference: "Western",
            division: "Pacific"
        ))
        .environment(AppState.shared)
    }
}
