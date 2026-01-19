//
//  NBABoxScoreView.swift
//  BoxScore
//
//  NBA box score with frozen player names - stats scroll horizontally
//

import SwiftUI

struct NBABoxScoreView: View {
    let boxScore: NBATeamBoxScore
    var isCollegeBasketball: Bool = false
    var isGameFinal: Bool = false

    // For college basketball, filter out players with 0 minutes
    private var filteredStarters: [NBAPlayerLine] {
        if isCollegeBasketball {
            return boxScore.starters.filter { $0.stats?.minutes ?? 0 > 0 }
        }
        return boxScore.starters
    }

    private var filteredBench: [NBAPlayerLine] {
        if isCollegeBasketball {
            return boxScore.bench.filter { $0.stats?.minutes ?? 0 > 0 }
        }
        return boxScore.bench
    }

    // Column definitions: MIN, PTS, FG, 3PT, FT, OREB, DREB, REB, AST, STL, BLK, TO, PF, +/-
    private let statColumns: [(id: String, title: String, width: CGFloat)] = [
        ("min", "MIN", 30),
        ("pts", "PTS", 28),
        ("fg", "FG", 38),
        ("3pt", "3PT", 38),
        ("ft", "FT", 38),
        ("oreb", "OREB", 34),
        ("dreb", "DREB", 34),
        ("reb", "REB", 28),
        ("ast", "AST", 28),
        ("stl", "STL", 28),
        ("blk", "BLK", 28),
        ("to", "TO", 26),
        ("pf", "PF", 26),
        ("pm", "+/-", 32),
    ]

    private let playerColumnWidth: CGFloat = 85
    private let rowHeight: CGFloat = 24
    private let sectionHeaderHeight: CGFloat = 22
    
    private var statsWidth: CGFloat {
        statColumns.reduce(0) { $0 + $1.width } + 1 // +1 for separator
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // FROZEN: Player name column (doesn't scroll)
            frozenPlayerColumn
                .frame(width: playerColumnWidth)
                .background(Color(.systemBackground))
                .zIndex(1)
            
            // Subtle separator
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: 1)
                .zIndex(1)
            
            // SCROLLABLE: Stats columns
            ScrollView(.horizontal, showsIndicators: false) {
                scrollableStatsColumn
                    .frame(minWidth: statsWidth)
            }
        }
    }
    
    // MARK: - Frozen Player Column

    private var frozenPlayerColumn: some View {
        VStack(spacing: 0) {
            // Starters section
            if !filteredStarters.isEmpty {
                sectionHeader("Starters", isDark: true)
                ForEach(filteredStarters) { player in
                    frozenPlayerRow(player.displayName, playerId: player.id)
                }
            }

            // Bench section (hide DNP for college basketball)
            let showDnp = !isCollegeBasketball && !boxScore.dnp.isEmpty
            if !filteredBench.isEmpty || showDnp {
                sectionHeader("Bench", isDark: false)
                ForEach(filteredBench) { player in
                    frozenPlayerRow(player.displayName, playerId: player.id)
                }
                if showDnp {
                    ForEach(boxScore.dnp) { player in
                        frozenPlayerRow(player.displayName, playerId: player.id)
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String, isDark: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isDark ? .white : .primary)
            Spacer()
        }
        .padding(.horizontal, 6)
        .frame(height: sectionHeaderHeight)
        .background(isDark ? Color.black.opacity(0.85) : Color(.systemGray4))
    }

    private func frozenPlayerRow(_ name: String, playerId: String) -> some View {
        VStack(spacing: 0) {
            NavigationLink(value: PlayerProfileRoute(playerId: playerId)) {
                Text(name)
                    .font(.system(size: 10))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .frame(height: rowHeight)
                    .background(Color(.systemBackground))
            }
            .buttonStyle(.plain)

            Divider()
        }
    }

    // MARK: - Scrollable Stats Column

    private var scrollableStatsColumn: some View {
        VStack(spacing: 0) {
            // Starters section with column headers
            if !filteredStarters.isEmpty {
                statsColumnHeaders(isDark: true)
                ForEach(filteredStarters) { player in
                    playerStatsRow(player)
                }
            }

            // Bench section with column headers (hide DNP for college basketball)
            let showDnp = !isCollegeBasketball && !boxScore.dnp.isEmpty
            if !filteredBench.isEmpty || showDnp {
                statsColumnHeaders(isDark: false)
                ForEach(filteredBench) { player in
                    playerStatsRow(player)
                }
                if showDnp {
                    ForEach(boxScore.dnp) { player in
                        dnpPlayerStatsRow(player)
                    }
                }
            }
        }
    }

    private func statsColumnHeaders(isDark: Bool) -> some View {
        HStack(spacing: 0) {
            // MIN column (lighter text)
            Text(statColumns[0].title)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(isDark ? .white.opacity(0.5) : Color(.tertiaryLabel))
                .frame(width: statColumns[0].width, alignment: .center)

            // Separator between MIN and stats
            Rectangle()
                .fill(isDark ? Color.white.opacity(0.3) : Color(.systemGray4))
                .frame(width: 1)

            // Remaining stat columns
            ForEach(statColumns.dropFirst(), id: \.id) { column in
                Text(column.title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isDark ? .white.opacity(0.8) : Color(.secondaryLabel))
                    .frame(width: column.width, alignment: .center)
            }
        }
        .frame(height: sectionHeaderHeight)
        .background(isDark ? Color.black.opacity(0.85) : Color(.systemGray4))
    }

    private func playerStatsRow(_ player: NBAPlayerLine) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if let stats = player.stats {
                    // MIN column (lighter text, show "-" if 0)
                    let minDisplay = stats.minutes == 0 ? "-" : stats.minutesDisplay
                    Text(minDisplay)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .frame(width: statColumns[0].width, alignment: .center)

                    // Separator
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 1)

                    // Stats (show "-" for zeros if player hasn't played)
                    let hasPlayed = stats.minutes > 0
                    statCell(hasPlayed ? stats.pointsDisplay : "-", width: statColumns[1].width, isBold: hasPlayed && stats.points > 0)
                    statCell(hasPlayed ? stats.fgDisplay : "-", width: statColumns[2].width)
                    statCell(hasPlayed ? stats.threeDisplay : "-", width: statColumns[3].width)
                    statCell(hasPlayed ? stats.ftDisplay : "-", width: statColumns[4].width)
                    statCell(hasPlayed ? stats.offRebDisplay : "-", width: statColumns[5].width)
                    statCell(hasPlayed ? stats.defRebDisplay : "-", width: statColumns[6].width)
                    statCell(hasPlayed ? stats.reboundsDisplay : "-", width: statColumns[7].width)
                    statCell(hasPlayed ? stats.assistsDisplay : "-", width: statColumns[8].width)
                    statCell(hasPlayed ? stats.stealsDisplay : "-", width: statColumns[9].width)
                    statCell(hasPlayed ? stats.blocksDisplay : "-", width: statColumns[10].width)
                    statCell(hasPlayed ? stats.turnoversDisplay : "-", width: statColumns[11].width)
                    statCell(hasPlayed ? stats.foulsDisplay : "-", width: statColumns[12].width)
                    statCell(hasPlayed ? stats.plusMinusDisplay : "-", width: statColumns[13].width)
                } else {
                    // No stats at all
                    Text("-")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .frame(width: statColumns[0].width, alignment: .center)

                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 1)

                    ForEach(statColumns.dropFirst(), id: \.id) { column in
                        statCell("-", width: column.width)
                    }
                }
            }
            .frame(height: rowHeight)
            .background(Color(.systemBackground))

            Divider()
        }
    }

    private func dnpPlayerStatsRow(_ player: NBAPlayerLine) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // MIN column shows "-"
                Text("-")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(width: statColumns[0].width, alignment: .center)

                // Separator
                Rectangle()
                    .fill(Color(.systemGray4))
                    .frame(width: 1)

                // Show different text based on game status
                if isGameFinal {
                    Text("DNP - \(player.dnpReason ?? "COACH'S DECISION")")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 6)
                } else {
                    Text("Has not entered the game")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 6)
                }

                Spacer()
            }
            .frame(height: rowHeight)
            .background(Color(.systemBackground))

            Divider()
        }
    }

    private func statCell(_ value: String, width: CGFloat, isBold: Bool = false) -> some View {
        Text(value)
            .font(.system(size: 10, weight: isBold ? .semibold : .regular))
            .foregroundStyle(value == "-" ? .tertiary : .primary)
            .frame(width: width, alignment: .center)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 0) {
            NBABoxScoreView(boxScore: NBAMockData.lakersBoxScore)
        }
    }
}
