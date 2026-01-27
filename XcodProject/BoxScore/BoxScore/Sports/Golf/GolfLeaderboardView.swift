//
//  GolfLeaderboardView.swift
//  BoxScore
//
//  Detailed golf leaderboard view showing all golfers with round-by-round scores
//

import SwiftUI

struct GolfLeaderboardView: View {
    let golfers: [GolferLine]
    let onSelectGolfer: ((String) -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    init(golfers: [GolferLine], onSelectGolfer: ((String) -> Void)? = nil) {
        self.golfers = golfers
        self.onSelectGolfer = onSelectGolfer
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            headerRow

            // Golfer rows
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(golfers) { golfer in
                        golferRow(golfer)

                        if golfer.id != golfers.last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack(spacing: 0) {
            Text("POS")
                .frame(width: 36, alignment: .center)

            Text("PLAYER")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("R1")
                .frame(width: 32, alignment: .center)

            Text("R2")
                .frame(width: 32, alignment: .center)

            Text("R3")
                .frame(width: 32, alignment: .center)

            Text("R4")
                .frame(width: 32, alignment: .center)

            Text("TOTAL")
                .frame(width: 48, alignment: .center)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.separator(for: colorScheme))
    }

    // MARK: - Golfer Row

    private func golferRow(_ golfer: GolferLine) -> some View {
        Button {
            onSelectGolfer?(golfer.id)
        } label: {
            HStack(spacing: 0) {
                // Position
                positionBadge(golfer.stats?.position ?? 0)

                // Player info
                playerInfo(golfer)

                // Round scores
                roundScores(golfer.stats?.rounds ?? [])

                // Total
                totalScore(golfer.stats?.score ?? "E", toPar: golfer.stats?.toParTotal ?? 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.cardBackground(for: colorScheme))
        }
        .buttonStyle(.plain)
    }

    private func positionBadge(_ position: Int) -> some View {
        Group {
            if position > 0 && position <= 3 {
                // Top 3 get special treatment
                ZStack {
                    Circle()
                        .fill(positionColor(position))
                        .frame(width: 28, height: 28)

                    Text("\(position)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            } else {
                Text(position > 0 ? "\(position)" : "-")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: 36, alignment: .center)
    }

    private func positionColor(_ position: Int) -> Color {
        switch position {
        case 1: return .yellow.opacity(0.8)  // Gold
        case 2: return .gray.opacity(0.6)    // Silver
        case 3: return .brown.opacity(0.6)   // Bronze
        default: return .clear
        }
    }

    private func playerInfo(_ golfer: GolferLine) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                // Country flag if available
                if let country = golfer.country, !country.isEmpty {
                    Text(countryFlag(country))
                        .font(.system(size: 12))
                }

                Text(golfer.displayName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            // Thru and today's score
            if let stats = golfer.stats {
                HStack(spacing: 4) {
                    Text(stats.thru == "F" ? "Finished" : "Thru \(stats.thru)")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)

                    if stats.thru != "F" {
                        Text("•")
                            .foregroundStyle(.tertiary)

                        Text("Today: \(stats.today)")
                            .font(.system(size: 10))
                            .foregroundStyle(todayScoreColor(stats.today))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func roundScores(_ rounds: [String]) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<4, id: \.self) { index in
                Text(index < rounds.count ? rounds[index] : "-")
                    .font(.system(size: 12))
                    .frame(width: 32, alignment: .center)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func totalScore(_ score: String, toPar: Int) -> some View {
        Text(score)
            .font(Theme.displayFont(size: 14))
            .frame(width: 48, alignment: .center)
            .foregroundStyle(scoreColor(toPar))
    }

    // MARK: - Helpers

    private func scoreColor(_ toPar: Int) -> Color {
        if toPar < 0 {
            return .red
        } else if toPar > 0 {
            return .primary
        }
        return .primary
    }

    private func todayScoreColor(_ today: String) -> Color {
        if today.hasPrefix("-") {
            return .red
        } else if today.hasPrefix("+") {
            return .primary
        }
        return .secondary
    }

    private func countryFlag(_ country: String) -> String {
        // Convert country code to flag emoji
        let base: UInt32 = 127397
        var flag = ""
        for scalar in country.uppercased().unicodeScalars {
            if let unicode = UnicodeScalar(base + scalar.value) {
                flag.unicodeScalars.append(unicode)
            }
        }
        return flag.isEmpty ? "" : flag
    }
}

// MARK: - Preview

#Preview {
    let mockGolfers = [
        GolferLine(
            id: "1",
            name: "Scottie Scheffler",
            country: "US",
            stats: GolferStats(position: 1, score: "-12", toParTotal: -12, rounds: ["66", "68", "69", "65"], thru: "F", today: "-7")
        ),
        GolferLine(
            id: "2",
            name: "Rory McIlroy",
            country: "IE",
            stats: GolferStats(position: 2, score: "-10", toParTotal: -10, rounds: ["68", "67", "70", "67"], thru: "F", today: "-5")
        ),
        GolferLine(
            id: "3",
            name: "Jon Rahm",
            country: "ES",
            stats: GolferStats(position: 3, score: "-9", toParTotal: -9, rounds: ["69", "68", "68", "68"], thru: "F", today: "-4")
        ),
        GolferLine(
            id: "4",
            name: "Patrick Cantlay",
            country: "US",
            stats: GolferStats(position: 4, score: "-8", toParTotal: -8, rounds: ["70", "67", "69", "68"], thru: "12", today: "-2")
        ),
    ]

    GolfLeaderboardView(golfers: mockGolfers)
}
