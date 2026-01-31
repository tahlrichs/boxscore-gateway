//
//  PlayerProfileView.swift
//  BoxScore
//
//  Redesigned player profile with Stat Central tab
//

import SwiftUI

// MARK: - Profile Tabs

enum PlayerProfileTab: String, CaseIterable {
    case bio = "Bio"
    case statCentral = "Stat Central"
    case news = "News"
}

enum StatCentralSubTab: String, CaseIterable {
    case gameSplits = "Game Splits"
    case gameLog = "Game Log"
    case advanced = "Advanced"
}

// MARK: - View Model

@MainActor @Observable
class PlayerProfileViewModel {
    let playerId: String

    var response: StatCentralData?
    var selectedTab: PlayerProfileTab = .statCentral
    var selectedSubTab: StatCentralSubTab = .gameSplits
    var isLoading = false
    var error: String?
    var showAllSeasons = false

    private let client = GatewayClient.shared

    init(playerId: String) {
        self.playerId = playerId
    }

    func load() async {
        isLoading = true
        error = nil

        do {
            let endpoint = GatewayEndpoint.playerStatCentral(playerId: playerId)
            let result: StatCentralData = try await client.fetch(endpoint)
            self.response = result
        } catch let networkError as NetworkError {
            self.error = networkError.errorDescription ?? "Failed to load profile"
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Computed Helpers

    var player: StatCentralPlayer? { response?.player }

    /// Rows visible when collapsed: up to 3 TOTAL/single-team rows. When expanded: all rows.
    var visibleSeasons: [SeasonRow] {
        guard let seasons = response?.seasons else { return [] }
        if showAllSeasons { return seasons }
        let mainRows = seasons.filter { $0.teamAbbreviation == nil }
        return Array(mainRows.prefix(3))
    }

    var careerRow: SeasonRow? { response?.career }

    var hasMoreSeasons: Bool {
        guard let seasons = response?.seasons else { return false }
        return seasons.filter({ $0.teamAbbreviation == nil }).count > 3
    }

    func rowStyle(for index: Int) -> RowStyle {
        if showAllSeasons { return .normal }
        switch index {
        case 0: return .current
        case 1: return .previous
        case 2: return .peek
        default: return .normal
        }
    }

    /// Get per-team rows for a traded season
    func tradeRows(for seasonLabel: String) -> [SeasonRow] {
        guard let seasons = response?.seasons else { return [] }
        return seasons.filter { $0.seasonLabel == seasonLabel && $0.teamAbbreviation != nil }
    }

    enum RowStyle {
        case current, previous, peek, normal
    }
}

// MARK: - Main View

struct PlayerProfileView: View {
    @State private var viewModel: PlayerProfileViewModel
    @Environment(\.colorScheme) private var colorScheme

    init(playerId: String) {
        self._viewModel = State(wrappedValue: PlayerProfileViewModel(playerId: playerId))
    }

    var body: some View {
        ZStack {
            Theme.background(for: colorScheme).ignoresSafeArea()

            if viewModel.isLoading && viewModel.response == nil {
                loadingView
            } else if viewModel.response != nil {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        playerHeader
                        headlineStatsView
                        tabPicker
                        tabContent
                    }
                    .padding()
                }
            } else if let error = viewModel.error {
                errorView(error)
            }
        }
        .navigationTitle(viewModel.player?.displayName ?? "Player")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, minHeight: 300)
            .animation(Theme.standardAnimation, value: viewModel.isLoading)
    }

    // MARK: - Error

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(Theme.red)
            Text("Error loading player")
                .font(.headline)
                .foregroundStyle(Theme.text(for: colorScheme))
            Text(error)
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText(for: colorScheme))
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - Player Header

    private var playerHeader: some View {
        VStack(spacing: 12) {
            // Photo + name row
            HStack(alignment: .top, spacing: 16) {
                if let headshot = viewModel.player?.headshot, let url = URL(string: headshot) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Theme.secondaryText(for: colorScheme))
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.secondaryText(for: colorScheme))
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let player = viewModel.player {
                        HStack(spacing: 6) {
                            Text(player.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(Theme.text(for: colorScheme))
                            if !player.jersey.isEmpty {
                                Text("#\(player.jersey)")
                                    .font(.title3)
                                    .foregroundStyle(Theme.secondaryText(for: colorScheme))
                            }
                        }

                        Text(player.position)
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText(for: colorScheme))

                        if let college = player.college {
                            Text(college)
                                .font(.caption)
                                .foregroundStyle(Theme.tertiaryText(for: colorScheme))
                        }

                        if let hometown = player.hometown {
                            Text(hometown)
                                .font(.caption)
                                .foregroundStyle(Theme.tertiaryText(for: colorScheme))
                        }

                        if let draft = player.draftSummary {
                            Text(draft)
                                .font(.caption)
                                .foregroundStyle(Theme.tertiaryText(for: colorScheme))
                        }
                    }
                }

                Spacer()
            }
        }
        .padding()
        .background(Theme.cardBackground(for: colorScheme))
        .cornerRadius(12)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(PlayerProfileTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(Theme.standardAnimation) {
                        viewModel.selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(viewModel.selectedTab == tab ? .bold : .regular)
                        .foregroundStyle(viewModel.selectedTab == tab ? Theme.text(for: colorScheme) : Theme.secondaryText(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            viewModel.selectedTab == tab
                                ? Theme.cardBackground(for: colorScheme)
                                : Color.clear
                        )
                        .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(Theme.secondaryBackground(for: colorScheme))
        .cornerRadius(12)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .statCentral:
            statCentralContent
        case .bio, .news:
            comingSoonPlaceholder
        }
    }

    private var comingSoonPlaceholder: some View {
        Text("Coming Soon")
            .font(.subheadline)
            .foregroundStyle(Theme.tertiaryText(for: colorScheme))
            .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Stat Central

    private var statCentralContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            seasonStatsTable
            subTabPicker
            subTabContent
        }
    }

    // MARK: - Sub-Tab Picker

    private var subTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(StatCentralSubTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(Theme.standardAnimation) {
                        viewModel.selectedSubTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline)
                        .fontWeight(viewModel.selectedSubTab == tab ? .bold : .regular)
                        .foregroundStyle(viewModel.selectedSubTab == tab ? Theme.text(for: colorScheme) : Theme.secondaryText(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            viewModel.selectedSubTab == tab
                                ? Theme.cardBackground(for: colorScheme)
                                : Color.clear
                        )
                        .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(Theme.secondaryBackground(for: colorScheme))
        .cornerRadius(12)
    }

    // MARK: - Sub-Tab Content

    private var subTabContent: some View {
        Text("Coming Soon")
            .font(.subheadline)
            .foregroundStyle(Theme.tertiaryText(for: colorScheme))
            .frame(maxWidth: .infinity, minHeight: 200)
            .background(Theme.cardBackground(for: colorScheme))
            .cornerRadius(12)
    }

    // MARK: - Headline Stats

    @ViewBuilder
    private var headlineStatsView: some View {
        if let season = viewModel.response?.seasons.first, season.gamesPlayed > 0 {
            HStack(spacing: 0) {
                headlineStat(value: formatStat(season.points), label: "PPG")
                headlineStat(value: formatStat(season.rebounds), label: "RPG")
                headlineStat(value: formatStat(season.assists), label: "APG")
                headlineStat(value: formatStat(season.fgPct), label: "FG%")
                headlineStat(value: {
                    // Show "--" if no 3PT attempts (undefined %, not 0%)
                    guard let pct = season.fg3Pct, let att = season.fg3Attempted, att > 0 else { return "--" }
                    return String(format: "%.1f", pct)
                }(), label: "3P%")
            }
            .padding()
            .background(Theme.cardBackground(for: colorScheme))
            .cornerRadius(12)
        }
    }

    private func formatStat(_ value: Double?) -> String {
        guard let v = value else { return "--" }
        return String(format: "%.1f", v)
    }

    private func headlineStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.displayFont(size: 28))
                .foregroundStyle(Theme.text(for: colorScheme))
            Text(label)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Season Stats Table

    /// Stat columns for the expanded table: (id, header, keyPath to get display value)
    private struct StatColumn: Identifiable {
        let id: String
        let title: String
        let width: CGFloat
        let getValue: (SeasonRow) -> String
    }

    private var statColumns: [StatColumn] {
        let col = { (id: String, title: String, width: CGFloat, kp: @escaping (SeasonRow) -> Double?) -> StatColumn in
            StatColumn(id: id, title: title, width: width) { row in
                guard row.gamesPlayed > 0, let v = kp(row) else { return "--" }
                return String(format: "%.1f", v)
            }
        }
        let intCol = { (id: String, title: String, width: CGFloat, kp: @escaping (SeasonRow) -> Double?) -> StatColumn in
            StatColumn(id: id, title: title, width: width) { row in
                guard row.gamesPlayed > 0, let v = kp(row) else { return "--" }
                return "\(Int(v))"
            }
        }
        let pctCol = { (id: String, title: String, width: CGFloat, kp: @escaping (SeasonRow) -> Double?, att: @escaping (SeasonRow) -> Double?) -> StatColumn in
            StatColumn(id: id, title: title, width: width) { row in
                guard row.gamesPlayed > 0, let a = att(row), a > 0, let v = kp(row) else { return "--" }
                return String(format: "%.1f", v)
            }
        }

        return [
            StatColumn(id: "gp", title: "GP", width: 30) { "\($0.gamesPlayed)" },
            intCol("gs", "GS", 30, \.gamesStarted),
            col("min", "MIN", 36, \.minutes),
            col("pts", "PTS", 36, \.points),
            col("fg", "FG", 30, \.fgMade),
            col("fga", "FGA", 34, \.fgAttempted),
            pctCol("fgPct", "FG%", 38, \.fgPct, \.fgAttempted),
            col("3pm", "3PM", 34, \.fg3Made),
            col("3pa", "3PA", 34, \.fg3Attempted),
            pctCol("3pPct", "3P%", 38, \.fg3Pct, \.fg3Attempted),
            col("ft", "FT", 30, \.ftMade),
            col("fta", "FTA", 34, \.ftAttempted),
            pctCol("ftPct", "FT%", 38, \.ftPct, \.ftAttempted),
            col("oreb", "OREB", 38, \.offRebounds),
            col("dreb", "DREB", 38, \.defRebounds),
            col("reb", "REB", 34, \.rebounds),
            col("ast", "AST", 34, \.assists),
            col("stl", "STL", 30, \.steals),
            col("blk", "BLK", 32, \.blocks),
            col("to", "TO", 30, \.turnovers),
            col("pf", "PF", 28, \.personalFouls),
        ]
    }

    private let seasonColumnWidth: CGFloat = 70
    private let rowHeight: CGFloat = 28

    private var seasonStatsTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                // FROZEN: Season column
                frozenSeasonColumn
                    .frame(width: seasonColumnWidth)
                    .zIndex(1)

                // Subtle separator
                Rectangle()
                    .fill(Theme.separator(for: colorScheme))
                    .frame(width: 1)
                    .zIndex(1)

                // SCROLLABLE: Stat columns
                ScrollView(.horizontal, showsIndicators: false) {
                    scrollableStatColumns
                }
            }

            // Expand toggle
            if viewModel.hasMoreSeasons {
                Divider()
                    .background(Theme.separator(for: colorScheme))

                Button {
                    withAnimation(Theme.standardAnimation) {
                        viewModel.showAllSeasons.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.showAllSeasons ? "eye.slash" : "eye")
                        Text(viewModel.showAllSeasons ? "Show fewer seasons" : "Show earlier seasons")
                        Image(systemName: viewModel.showAllSeasons ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText(for: colorScheme))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(Theme.cardBackground(for: colorScheme))
        .cornerRadius(12)
    }

    // MARK: - Frozen Season Column

    private var frozenSeasonColumn: some View {
        VStack(spacing: 0) {
            // Header
            Text("SEASON")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Theme.tertiaryText(for: colorScheme))
                .frame(width: seasonColumnWidth, height: rowHeight, alignment: .leading)
                .padding(.leading, 8)

            Divider().background(Theme.separator(for: colorScheme))

            // Season rows
            let rows = viewModel.visibleSeasons
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, season in
                frozenSeasonLabel(season, style: viewModel.rowStyle(for: index))

                if viewModel.showAllSeasons {
                    let trades = viewModel.tradeRows(for: season.seasonLabel)
                    if trades.count > 1 && season.teamAbbreviation == nil {
                        ForEach(trades) { tradeRow in
                            frozenSeasonLabel(tradeRow, style: .normal, indented: true)
                        }
                    }
                }
            }

            // Career row
            if viewModel.careerRow != nil {
                Divider().background(Theme.separator(for: colorScheme))
                Text("Career")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Theme.text(for: colorScheme))
                    .frame(width: seasonColumnWidth, height: rowHeight, alignment: .leading)
                    .padding(.leading, 8)
            }
        }
    }

    private func frozenSeasonLabel(_ row: SeasonRow, style: PlayerProfileViewModel.RowStyle, indented: Bool = false) -> some View {
        let displayLabel: String = {
            if let team = row.teamAbbreviation {
                return "\(row.seasonLabel) \(team)"
            }
            return row.seasonLabel
        }()

        return Text(displayLabel)
            .font(.caption)
            .fontWeight(style == .current ? .bold : .regular)
            .foregroundStyle(Theme.text(for: colorScheme))
            .opacity(style == .peek ? 0.4 : 1.0)
            .frame(width: indented ? seasonColumnWidth - 10 : seasonColumnWidth, height: rowHeight, alignment: .leading)
            .padding(.leading, indented ? 18 : 8)
    }

    // MARK: - Scrollable Stat Columns

    private var scrollableStatColumns: some View {
        let columns = statColumns

        return VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(columns) { col in
                    Text(col.title)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.tertiaryText(for: colorScheme))
                        .frame(width: col.width, alignment: .trailing)
                }
            }
            .frame(height: rowHeight)

            Divider().background(Theme.separator(for: colorScheme))

            // Season rows
            let rows = viewModel.visibleSeasons
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, season in
                statRowView(season, style: viewModel.rowStyle(for: index), columns: columns)

                if viewModel.showAllSeasons {
                    let trades = viewModel.tradeRows(for: season.seasonLabel)
                    if trades.count > 1 && season.teamAbbreviation == nil {
                        ForEach(trades) { tradeRow in
                            statRowView(tradeRow, style: .normal, columns: columns)
                        }
                    }
                }
            }

            // Career row
            if let career = viewModel.careerRow {
                Divider().background(Theme.separator(for: colorScheme))
                statRowView(career, style: .normal, columns: columns)
            }
        }
    }

    private func statRowView(_ row: SeasonRow, style: PlayerProfileViewModel.RowStyle, columns: [StatColumn]) -> some View {
        HStack(spacing: 0) {
            ForEach(columns) { col in
                Text(col.getValue(row))
                    .font(.caption)
                    .foregroundStyle(Theme.text(for: colorScheme))
                    .frame(width: col.width, alignment: .trailing)
            }
        }
        .fontWeight(style == .current ? .bold : .regular)
        .opacity(style == .peek ? 0.4 : 1.0)
        .frame(height: rowHeight)
    }
}

#Preview {
    NavigationStack {
        PlayerProfileView(playerId: "542839ef-df72-450b-98f8-a8bef0ddcc8a")
    }
}
