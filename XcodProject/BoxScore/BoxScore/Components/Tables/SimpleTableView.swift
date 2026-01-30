//
//  SimpleTableView.swift
//  BoxScore
//
//  Simple table component for box scores.
//  Player names are frozen (fixed), stats scroll horizontally.
//  Uses fixed row heights to ensure perfect alignment.
//

import SwiftUI

struct SimpleTableView: View {
    let columns: [TableColumn]
    let rows: [TableRow]
    let teamTotalsRow: TableRow?
    let playerColumnWidth: CGFloat
    
    // Fixed heights for alignment (compact)
    private let headerHeight: CGFloat = 20
    private let rowHeight: CGFloat = 24
    private let totalsRowHeight: CGFloat = 24
    
    let frozenColumnHeader: String?

    init(
        columns: [TableColumn],
        rows: [TableRow],
        teamTotalsRow: TableRow? = nil,
        playerColumnWidth: CGFloat = 140,
        frozenColumnHeader: String? = nil
    ) {
        self.columns = columns
        self.rows = rows
        self.teamTotalsRow = teamTotalsRow
        self.playerColumnWidth = playerColumnWidth
        self.frozenColumnHeader = frozenColumnHeader
    }
    
    private var statsWidth: CGFloat {
        columns.reduce(0) { $0 + $1.width }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // FROZEN: Player name column (doesn't scroll)
            VStack(spacing: 0) {
                // Header for player column
                playerColumnHeader
                
                // Player names
                ForEach(rows) { row in
                    playerNameCell(row)
                }
                
                // Team totals label
                if let totals = teamTotalsRow {
                    teamTotalsLabel(totals)
                }
            }
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
                VStack(spacing: 0) {
                    // Stats headers
                    statsHeader
                    
                    // Stats for each player
                    ForEach(rows) { row in
                        statsRow(row)
                    }
                    
                    // Team totals stats
                    if let totals = teamTotalsRow {
                        teamTotalsStats(totals)
                    }
                }
                .frame(minWidth: statsWidth)
            }
        }
    }
    
    // MARK: - Frozen Column (Player Names)
    
    private var playerColumnHeader: some View {
        Text(frozenColumnHeader ?? "PLAYER")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 8)
            .frame(height: headerHeight)
            .background(Color(.systemGray6))
    }

    private func playerNameCell(_ row: TableRow) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 3) {
                Text(row.leadingText)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)

                if let subtitle = row.subtitle {
                    Text(subtitle)
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.leading, 8)
            .padding(.trailing, 4)
            .frame(height: rowHeight)
            .background(row.highlightColor ?? Color(.systemBackground))

            Divider()
                .padding(.leading, 8)
        }
    }

    private func teamTotalsLabel(_ row: TableRow) -> some View {
        Text(row.leadingText)
            .font(.system(size: 10, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 8)
            .frame(height: totalsRowHeight)
            .background(Color(.systemGray5))
    }
    
    // MARK: - Scrollable Column (Stats)
    
    private var statsHeader: some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                Text(column.title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: column.width, alignment: columnAlignment(column.alignment))
            }
        }
        .frame(height: headerHeight)
        .background(Color(.systemGray6))
    }

    private func statsRow(_ row: TableRow) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(zip(columns.indices, columns)), id: \.0) { index, column in
                    let cellValue = index < row.cells.count ? row.cells[index] : "-"
                    Text(cellValue)
                        .font(.system(size: 10))
                        .foregroundStyle(cellValue == "-" ? .secondary : .primary)
                        .frame(width: column.width, alignment: columnAlignment(column.alignment))
                }
            }
            .frame(height: rowHeight)
            .background(row.highlightColor ?? Color(.systemBackground))

            Divider()
        }
    }

    private func teamTotalsStats(_ row: TableRow) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(zip(columns.indices, columns)), id: \.0) { index, column in
                let cellValue = index < row.cells.count ? row.cells[index] : "-"
                Text(cellValue)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(cellValue == "-" ? .secondary : .primary)
                    .frame(width: column.width, alignment: columnAlignment(column.alignment))
            }
        }
        .frame(height: totalsRowHeight)
        .background(Color(.systemGray5))
    }
    
    // MARK: - Helpers
    
    private func columnAlignment(_ alignment: HorizontalAlignment) -> Alignment {
        switch alignment {
        case .leading: return .leading
        case .trailing: return .trailing
        default: return .center
        }
    }
}

// MARK: - Empty State View

struct EmptyTableStateView: View {
    let message: String
    
    var body: some View {
        HStack {
            Spacer()
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.vertical, 12)
            Spacer()
        }
        .background(Color(.systemGray6).opacity(0.5))
    }
}

#Preview {
    VStack(spacing: 20) {
        SimpleTableView(
            columns: NBAColumns.standard,
            rows: [
                TableRow(id: "1", leadingText: "LeBron James", subtitle: "#23", cells: ["38", "32", "12-22", "3-8", "5-6", "8", "9", "2", "1", "4", "2", "+12"]),
                TableRow(id: "2", leadingText: "Anthony Davis", subtitle: "#3", cells: ["36", "28", "11-18", "1-3", "5-8", "14", "3", "1", "3", "2", "3", "+8"]),
            ],
            teamTotalsRow: TableRow(id: "team", isTeamTotals: true, leadingText: "TEAM", cells: ["240", "122", "47-93", "13-38", "15-22", "42", "30", "5", "6", "14", "18", "-"]),
            playerColumnWidth: 140
        )
        
        EmptyTableStateView(message: "No Kick Returns")
    }
    .padding()
}
