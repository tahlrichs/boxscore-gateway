//
//  NHLBoxScoreView.swift
//  BoxScore
//
//  NHL box score with frozen player names - stats scroll horizontally
//  Displays skaters and goalies in separate sections
//

import SwiftUI

struct NHLBoxScoreView: View {
    let boxScore: NHLTeamBoxScore
    
    // Skater columns: TOI, G, A, PTS, +/-, PIM, SOG, HIT, BLK, FO
    private let skaterColumns: [(id: String, title: String, width: CGFloat)] = [
        ("toi", "TOI", 38),
        ("g", "G", 24),
        ("a", "A", 24),
        ("pts", "PTS", 28),
        ("pm", "+/-", 30),
        ("pim", "PIM", 28),
        ("sog", "SOG", 30),
        ("hit", "HIT", 28),
        ("blk", "BLK", 28),
        ("fo", "FO", 42),
    ]

    // Goalie columns: TOI, SV, SA, GA, SV%
    private let goalieColumns: [(id: String, title: String, width: CGFloat)] = [
        ("toi", "TOI", 38),
        ("sv", "SV", 28),
        ("sa", "SA", 28),
        ("ga", "GA", 28),
        ("svpct", "SV%", 44),
    ]

    private let playerColumnWidth: CGFloat = 85
    private let rowHeight: CGFloat = 24
    private let headerHeight: CGFloat = 20
    private let sectionHeaderHeight: CGFloat = 22
    
    private var skaterStatsWidth: CGFloat {
        skaterColumns.reduce(0) { $0 + $1.width }
    }
    
    private var goalieStatsWidth: CGFloat {
        goalieColumns.reduce(0) { $0 + $1.width }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Skaters section
            skatersSection
            
            // Goalies section
            if !boxScore.goalies.isEmpty {
                goaliesSection
            }
            
            // Scratches section (if any)
            if !boxScore.scratches.isEmpty {
                scratchesSection
            }
        }
    }
    
    // MARK: - Skaters Section
    
    private var skatersSection: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // FROZEN: Player name column
                frozenSkaterColumn
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
                    scrollableSkaterColumn
                        .frame(minWidth: skaterStatsWidth)
                }
            }
        }
    }
    
    private var frozenSkaterColumn: some View {
        VStack(spacing: 0) {
            // Header label replacing empty spacer
            HStack {
                Text("SKATERS")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.leading, 6)
            .frame(height: headerHeight)
            .background(Color(.systemGray6))

            // Skater rows
            ForEach(boxScore.skaters) { player in
                frozenPlayerRow(player.displayName, subtitle: "\(player.jerseyDisplay) \(player.positionShort)")
            }
        }
    }
    
    private var scrollableSkaterColumn: some View {
        VStack(spacing: 0) {
            // Column headers
            skaterColumnHeaders

            // Skater stats rows
            ForEach(boxScore.skaters) { player in
                skaterStatsRow(player)
            }
        }
    }
    
    private var skaterColumnHeaders: some View {
        HStack(spacing: 0) {
            ForEach(skaterColumns, id: \.id) { column in
                Text(column.title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: column.width, alignment: .center)
            }
        }
        .frame(height: headerHeight)
        .background(Color(.systemGray6))
    }
    
    private func skaterStatsRow(_ player: NHLSkaterLine) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if let stats = player.stats {
                    statCell(stats.timeOnIceDisplay, width: skaterColumns[0].width)
                    statCell(stats.goalsDisplay, width: skaterColumns[1].width, isBold: stats.goals > 0)
                    statCell(stats.assistsDisplay, width: skaterColumns[2].width, isBold: stats.assists > 0)
                    statCell(stats.pointsDisplay, width: skaterColumns[3].width, isBold: stats.points > 0)
                    statCell(stats.plusMinusDisplay, width: skaterColumns[4].width)
                    statCell(stats.penaltyMinutesDisplay, width: skaterColumns[5].width)
                    statCell(stats.shotsDisplay, width: skaterColumns[6].width)
                    statCell(stats.hitsDisplay, width: skaterColumns[7].width)
                    statCell(stats.blockedShotsDisplay, width: skaterColumns[8].width)
                    statCell(stats.faceoffDisplay, width: skaterColumns[9].width)
                } else {
                    ForEach(skaterColumns, id: \.id) { column in
                        statCell("-", width: column.width)
                    }
                }
            }
            .frame(height: rowHeight)
            .background(Color(.systemBackground))
            
            Divider()
        }
    }
    
    // MARK: - Goalies Section
    
    private var goaliesSection: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // FROZEN: Player name column
                frozenGoalieColumn
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
                    scrollableGoalieColumn
                        .frame(minWidth: goalieStatsWidth)
                }
            }
        }
    }
    
    private var frozenGoalieColumn: some View {
        VStack(spacing: 0) {
            // Goalies header
            sectionHeader("Goalies")
            
            // Goalie rows
            ForEach(boxScore.goalies) { goalie in
                let displayName = goalie.decision != nil ? "\(goalie.displayName) \(goalie.decisionDisplay)" : goalie.displayName
                frozenPlayerRow(displayName, subtitle: goalie.jerseyDisplay)
            }
        }
    }
    
    private var scrollableGoalieColumn: some View {
        VStack(spacing: 0) {
            // Section spacer with header
            goalieColumnHeaders
            
            // Goalie stats rows
            ForEach(boxScore.goalies) { goalie in
                goalieStatsRow(goalie)
            }
        }
    }
    
    private var goalieColumnHeaders: some View {
        HStack(spacing: 0) {
            ForEach(goalieColumns, id: \.id) { column in
                Text(column.title)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: column.width, alignment: .center)
            }
            Spacer()
        }
        .frame(height: sectionHeaderHeight)
        .background(Color(.systemGray4))
    }
    
    private func goalieStatsRow(_ goalie: NHLGoalieLine) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if let stats = goalie.stats {
                    statCell(stats.timeOnIceDisplay, width: goalieColumns[0].width)
                    statCell(stats.savesDisplay, width: goalieColumns[1].width)
                    statCell(stats.shotsAgainstDisplay, width: goalieColumns[2].width)
                    statCell(stats.goalsAgainstDisplay, width: goalieColumns[3].width)
                    statCell(stats.savePercentageDisplay, width: goalieColumns[4].width, isBold: true)
                } else {
                    ForEach(goalieColumns, id: \.id) { column in
                        statCell("-", width: column.width)
                    }
                }
                Spacer()
            }
            .frame(height: rowHeight)
            .background(Color(.systemBackground))
            
            Divider()
        }
    }
    
    // MARK: - Scratches Section
    
    private var scratchesSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Scratches")

            ForEach(boxScore.scratches) { scratch in
                VStack(spacing: 0) {
                    HStack {
                        Text(scratch.displayName)
                            .font(.system(size: 10))
                            .foregroundStyle(.primary)

                        Text(scratch.reason ?? "Healthy Scratch")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal, 6)
                    .frame(height: rowHeight)
                    .background(Color(.systemBackground))

                    Divider()
                }
            }
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 6)
        .frame(height: sectionHeaderHeight)
        .background(Color(.systemGray4))
    }

    private func frozenPlayerRow(_ name: String, subtitle: String? = nil) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .font(.system(size: 10))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 6)
            .frame(height: rowHeight)
            .background(Color(.systemBackground))

            Divider()
        }
    }


    private func statCell(_ value: String, width: CGFloat, isBold: Bool = false) -> some View {
        Text(value)
            .font(.system(size: 10, weight: isBold ? .semibold : .regular))
            .frame(width: width, alignment: .center)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 0) {
            NHLBoxScoreView(boxScore: NHLMockData.bruinsBoxScore)
        }
    }
}
