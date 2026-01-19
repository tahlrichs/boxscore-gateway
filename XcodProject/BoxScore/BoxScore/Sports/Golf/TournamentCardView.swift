//
//  TournamentCardView.swift
//  BoxScore
//
//  Golf tournament card with expandable leaderboard
//

import SwiftUI

struct TournamentCardView: View {
    let tournament: GolfTournament
    @State private var isExpanded = false
    var onExpand: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Card container
            VStack(spacing: 0) {
                // Header section
                headerSection

                // Top 3 golfers (always visible)
                top3Section

                // Expanded leaderboard
                if isExpanded {
                    expandedLeaderboard
                }

                // Expand/collapse button
                expandButton
            }
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Tournament name
            Text(tournament.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            // Status row (combined with venue)
            HStack(spacing: 4) {
                Text(tournament.statusDisplay)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(statusColor)

                Text("•")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)

                Text(tournament.dateRangeDisplay)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                if !tournament.venue.isEmpty {
                    Text("•")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)

                    Text(tournament.venue)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var statusColor: Color {
        switch tournament.roundStatus.lowercased() {
        case "in progress":
            return .green
        case "complete", "final":
            return .secondary
        default:
            return .blue
        }
    }

    // MARK: - Top 3 Section

    private var top3Section: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 12)

            // Show winner/defending champ if no leaderboard, otherwise show top 3
            if tournament.leaderboard.isEmpty, let winner = tournament.winner {
                winnerRow(winner: winner)
            } else if tournament.top3.isEmpty, let winner = tournament.winner {
                winnerRow(winner: winner)
            } else {
                ForEach(tournament.top3) { golfer in
                    compactGolferRow(golfer: golfer)

                    if golfer.id != tournament.top3.last?.id {
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
        }
    }

    // MARK: - Winner Row

    private func winnerRow(winner: GolfWinner) -> some View {
        HStack(spacing: 8) {
            // Trophy or medal icon
            Image(systemName: winner.isDefendingChamp == true ? "medal.fill" : "trophy.fill")
                .font(.system(size: 14))
                .foregroundStyle(winner.isDefendingChamp == true ? .blue : .yellow)
                .frame(width: 24)

            // Label and name
            VStack(alignment: .leading, spacing: 2) {
                Text(winner.isDefendingChamp == true ? "Defending Champion" : "Winner")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Text(winner.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    if let score = winner.score {
                        Text("(\(score))")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(scoreColor(forScoreString: score))
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func scoreColor(forScoreString score: String) -> Color {
        if score.hasPrefix("-") {
            return .red // Under par (good in golf)
        } else if score.hasPrefix("+") {
            return .primary
        }
        return .primary // Even or unknown
    }

    // MARK: - Expanded Leaderboard

    private var expandedLeaderboard: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 12)

            // Column headers (sticky)
            leaderboardHeader

            // Scrollable golfer list (show up to 30 golfers after top 3)
            let additionalGolfers = Array(tournament.leaderboard.dropFirst(3).prefix(27))
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(additionalGolfers) { golfer in
                        golferRow(golfer: golfer, showRounds: true)

                        if golfer.id != additionalGolfers.last?.id {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
            }
            .frame(maxHeight: 250) // Limit height to make it scrollable
        }
    }

    private var leaderboardHeader: some View {
        HStack(spacing: 0) {
            Text("POS")
                .frame(width: 28, alignment: .center)

            Text("PLAYER")
                .frame(maxWidth: .infinity, alignment: .leading)

            // Round columns
            ForEach(1...4, id: \.self) { round in
                Text("R\(round)")
                    .frame(width: 26, alignment: .center)
            }

            Text("TOT")
                .frame(width: 32, alignment: .center)
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
    }

    // MARK: - Compact Golfer Row (Top 3)

    private func compactGolferRow(golfer: GolferLine) -> some View {
        HStack(spacing: 4) {
            // Position
            Text(golfer.stats?.positionDisplay ?? "-")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24, alignment: .leading)
                .foregroundStyle(.secondary)

            // Player name
            Text(golfer.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            // Thru indicator (compact)
            if let thru = golfer.stats?.thru {
                Text(thru == "F" ? "F" : thru)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(width: 20)
            }

            // Total score
            Text(golfer.stats?.score ?? "E")
                .font(.system(size: 13, weight: .bold))
                .frame(width: 36, alignment: .trailing)
                .foregroundStyle(scoreColor(for: golfer.stats?.toParTotal ?? 0))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    // MARK: - Expanded Golfer Row

    private func golferRow(golfer: GolferLine, showRounds: Bool) -> some View {
        HStack(spacing: 0) {
            // Position
            Text(golfer.stats?.positionDisplay ?? "-")
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 28, alignment: .center)
                .foregroundStyle(.secondary)

            // Player name
            Text(golfer.displayName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if showRounds {
                // Round scores
                let rounds = golfer.stats?.rounds ?? []
                ForEach(0..<4, id: \.self) { index in
                    Text(index < rounds.count ? rounds[index] : "-")
                        .font(.system(size: 10))
                        .frame(width: 26, alignment: .center)
                        .foregroundStyle(.secondary)
                }
            }

            // Total score
            Text(golfer.stats?.score ?? "E")
                .font(.system(size: 12, weight: .bold))
                .frame(width: 32, alignment: .center)
                .foregroundStyle(scoreColor(for: golfer.stats?.toParTotal ?? 0))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func scoreColor(for toPar: Int) -> Color {
        if toPar < 0 {
            return .red // Under par (good in golf)
        } else if toPar > 0 {
            return .primary
        }
        return .primary // Even
    }

    // MARK: - Expand Button

    @ViewBuilder
    private var expandButton: some View {
        // Only show expand button if there's a leaderboard with more than 3 golfers
        if tournament.leaderboard.count > 3 {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                    if isExpanded {
                        onExpand?()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(isExpanded ? "Less" : "Leaderboard")
                        .font(.system(size: 11, weight: .medium))

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(Color(.systemGray6).opacity(0.5))
        }
    }
}

// MARK: - Preview

#Preview {
    let mockGolfers = [
        GolferLine(
            id: "1",
            name: "Scottie Scheffler",
            stats: GolferStats(position: 1, score: "-12", toParTotal: -12, rounds: ["66", "68", "69", "65"], thru: "F", today: "-7")
        ),
        GolferLine(
            id: "2",
            name: "Rory McIlroy",
            stats: GolferStats(position: 2, score: "-10", toParTotal: -10, rounds: ["68", "67", "70", "67"], thru: "F", today: "-5")
        ),
        GolferLine(
            id: "3",
            name: "Jon Rahm",
            stats: GolferStats(position: 3, score: "-9", toParTotal: -9, rounds: ["69", "68", "68", "68"], thru: "F", today: "-4")
        ),
        GolferLine(
            id: "4",
            name: "Patrick Cantlay",
            stats: GolferStats(position: 4, score: "-8", toParTotal: -8, rounds: ["70", "67", "69", "68"], thru: "F", today: "-4")
        ),
    ]

    let tournament = GolfTournament(
        id: "pga_123",
        name: "The American Express",
        tour: "pga",
        venue: "PGA West (Stadium Course)",
        location: "La Quinta, CA",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3 * 24 * 60 * 60),
        currentRound: 4,
        roundStatus: "Complete",
        purse: "$8,400,000",
        leaderboard: mockGolfers
    )

    ScrollView {
        TournamentCardView(tournament: tournament)
    }
    .background(Color(.systemGroupedBackground))
}
