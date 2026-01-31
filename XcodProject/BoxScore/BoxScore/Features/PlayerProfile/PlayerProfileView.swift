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

// MARK: - View Model

@MainActor
class PlayerProfileViewModel: ObservableObject {
    let playerId: String

    @Published var response: StatCentralData?
    @Published var selectedTab: PlayerProfileTab = .statCentral
    @Published var isLoading = false
    @Published var error: String?
    @Published var showAllSeasons = false

    private let client = GatewayClient.shared

    init(playerId: String) {
        self.playerId = playerId
    }

    func load() async {
        isLoading = true
        error = nil

        do {
            let endpoint = GatewayEndpoint.playerStatCentral(playerId: playerId)
            let result: StatCentralResponse = try await client.fetch(endpoint)
            self.response = result.data
        } catch let networkError as NetworkError {
            self.error = networkError.errorDescription ?? "Failed to load profile"
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Computed Helpers

    var player: StatCentralPlayer? { response?.player }

    var headlineStats: (ppg: Double, rpg: Double, apg: Double, spg: Double)? {
        guard let first = response?.seasons.first else { return nil }
        return (first.ppg, first.rpg, first.apg, first.spg)
    }

    /// Rows visible when collapsed: current (bold), previous (normal), peek (faded), career
    var visibleSeasons: [SeasonRow] {
        guard let seasons = response?.seasons else { return [] }
        // Filter to TOTAL rows only (teamAbbreviation == nil means TOTAL or single-team)
        // When collapsed, show up to 3 seasons + career
        let mainRows = seasons.filter { $0.teamAbbreviation == nil || !hasTrades(for: $0.seasonLabel) }
        if showAllSeasons { return seasons }
        return Array(mainRows.prefix(3))
    }

    var careerRow: SeasonRow? { response?.career }

    var hasMoreSeasons: Bool {
        guard let seasons = response?.seasons else { return false }
        return seasons.count > 3
    }

    var isRookie: Bool {
        guard let seasons = response?.seasons else { return true }
        // A rookie has only 1 unique season label
        let uniqueSeasons = Set(seasons.map(\.seasonLabel))
        return uniqueSeasons.count <= 1
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

    /// Check if a season has trade rows (multiple entries with same seasonLabel)
    private func hasTrades(for seasonLabel: String) -> Bool {
        guard let seasons = response?.seasons else { return false }
        return seasons.filter({ $0.seasonLabel == seasonLabel }).count > 1
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
    let playerId: String
    @StateObject private var viewModel: PlayerProfileViewModel
    @Environment(\.colorScheme) private var colorScheme

    init(playerId: String) {
        self.playerId = playerId
        self._viewModel = StateObject(wrappedValue: PlayerProfileViewModel(playerId: playerId))
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
            headlineStatsView
            seasonStatsTable
        }
    }

    // MARK: - Headline Stats

    private var headlineStatsView: some View {
        Group {
            if let stats = viewModel.headlineStats {
                HStack(spacing: 0) {
                    headlineStat(value: stats.ppg, label: "PPG")
                    headlineStat(value: stats.rpg, label: "RPG")
                    headlineStat(value: stats.apg, label: "APG")
                    headlineStat(value: stats.spg, label: "SPG")
                }
                .padding()
                .background(Theme.cardBackground(for: colorScheme))
                .cornerRadius(12)
            }
        }
    }

    private func headlineStat(value: Double, label: String) -> some View {
        VStack(spacing: 4) {
            if viewModel.response?.seasons.first?.gamesPlayed == 0 {
                Text("--")
                    .font(Theme.displayFont(size: 28))
                    .foregroundStyle(Theme.text(for: colorScheme))
            } else {
                Text(String(format: "%.1f", value))
                    .font(Theme.displayFont(size: 28))
                    .foregroundStyle(Theme.text(for: colorScheme))
            }
            Text(label)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Season Stats Table

    private var seasonStatsTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Column headers
            seasonRowHeader
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()
                .background(Theme.separator(for: colorScheme))

            // Season rows
            let rows = viewModel.visibleSeasons
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, season in
                seasonRowView(season, style: viewModel.rowStyle(for: index))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)

                // Show trade breakdown rows when expanded
                if viewModel.showAllSeasons {
                    let trades = viewModel.tradeRows(for: season.seasonLabel)
                    if trades.count > 1 && season.teamAbbreviation == nil {
                        ForEach(trades) { tradeRow in
                            seasonRowView(tradeRow, style: .normal, indented: true)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                        }
                    }
                }
            }

            // Career row
            if let career = viewModel.careerRow {
                Divider()
                    .background(Theme.separator(for: colorScheme))
                seasonRowView(career, style: .normal, label: "Career")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }

            // Expand toggle
            if viewModel.hasMoreSeasons && !viewModel.isRookie {
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

    private var seasonRowHeader: some View {
        HStack(spacing: 0) {
            Text("SEASON")
                .frame(width: 65, alignment: .leading)
            Text("GP")
                .frame(width: 30, alignment: .trailing)
            Text("PPG")
                .frame(width: 40, alignment: .trailing)
            Text("RPG")
                .frame(width: 40, alignment: .trailing)
            Text("APG")
                .frame(width: 40, alignment: .trailing)
            Text("FG%")
                .frame(width: 42, alignment: .trailing)
            Text("FT%")
                .frame(width: 42, alignment: .trailing)
        }
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(Theme.tertiaryText(for: colorScheme))
    }

    private func seasonRowView(_ row: SeasonRow, style: PlayerProfileViewModel.RowStyle, indented: Bool = false, label: String? = nil) -> some View {
        let displayLabel: String = {
            if let label { return label }
            if let team = row.teamAbbreviation {
                return "\(row.seasonLabel) \(team)"
            }
            return row.seasonLabel
        }()

        let gpText = row.gamesPlayed > 0 ? "\(row.gamesPlayed)" : "0"
        let showDash = row.gamesPlayed == 0

        return HStack(spacing: 0) {
            Text(displayLabel)
                .frame(width: indented ? 55 : 65, alignment: .leading)
                .padding(.leading, indented ? 10 : 0)
            Text(gpText)
                .frame(width: 30, alignment: .trailing)
            Text(showDash ? "--" : String(format: "%.1f", row.ppg))
                .frame(width: 40, alignment: .trailing)
            Text(showDash ? "--" : String(format: "%.1f", row.rpg))
                .frame(width: 40, alignment: .trailing)
            Text(showDash ? "--" : String(format: "%.1f", row.apg))
                .frame(width: 40, alignment: .trailing)
            Text(showDash ? "--" : String(format: "%.1f", row.fgPct))
                .frame(width: 42, alignment: .trailing)
            Text(showDash ? "--" : String(format: "%.1f", row.ftPct))
                .frame(width: 42, alignment: .trailing)
        }
        .font(.caption)
        .fontWeight(style == .current ? .bold : .regular)
        .foregroundStyle(Theme.text(for: colorScheme))
        .opacity(style == .peek ? 0.4 : 1.0)
    }
}

#Preview {
    NavigationStack {
        PlayerProfileView(playerId: "542839ef-df72-450b-98f8-a8bef0ddcc8a")
    }
}
