//
//  PlayerProfileView.swift
//  BoxScore
//
//  Player profile screen with stats, game logs, splits, and career
//

import SwiftUI

// MARK: - Profile Tabs

enum PlayerProfileTab: String, CaseIterable {
    case season = "Season"
    case gameLog = "Game Log"
    case splits = "Splits"
    case career = "Career"
}

// MARK: - Main View

struct PlayerProfileView: View {
    let playerId: String
    @StateObject private var viewModel: PlayerProfileViewModel

    init(playerId: String) {
        self.playerId = playerId
        self._viewModel = StateObject(wrappedValue: PlayerProfileViewModel(playerId: playerId))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isLoading && viewModel.player == nil {
                    loadingView
                } else if let player = viewModel.player {
                    // Player header with bio
                    playerHeader(player)

                    // Tab picker
                    tabPicker

                    // Tab content
                    tabContent
                } else if let error = viewModel.error {
                    errorView(error)
                }
            }
            .padding()
        }
        .navigationTitle(viewModel.player?.displayName ?? "Player")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadPlayerProfile()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading player profile...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text("Error loading player")
                .font(.headline)
            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task { await viewModel.loadPlayerProfile() }
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: 300)
    }

    // MARK: - Player Header

    private func playerHeader(_ player: PlayerProfile) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Player headshot placeholder
            Image(systemName: "person.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(player.displayName)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    if let position = player.position {
                        Text(position)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if let teamId = player.currentTeamId {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(teamId.replacingOccurrences(of: "nba_", with: "").uppercased())
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Bio details
                HStack(spacing: 16) {
                    if let height = player.heightIn {
                        let feet = height / 12
                        let inches = height % 12
                        Text("\(feet)'\(inches)\"")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if let weight = player.weightLb {
                        Text("\(weight) lbs")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                if let school = player.school {
                    Text(school)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("Stats Tab", selection: $viewModel.selectedTab) {
            ForEach(PlayerProfileTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.selectedTab) { _, newTab in
            Task { await viewModel.loadTabData(for: newTab) }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch viewModel.selectedTab {
        case .season:
            seasonTabContent
        case .gameLog:
            gameLogTabContent
        case .splits:
            splitsTabContent
        case .career:
            careerTabContent
        }
    }

    // MARK: - Season Tab

    private var seasonTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Detect sport and show appropriate stats
            if let player = viewModel.player, player.sport.lowercased() == "nfl" {
                nflSeasonStatsView
            } else if let stats = viewModel.currentSeasonStats {
                nbaSeasonStatsView(stats)
            } else {
                Text("No season stats available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - NBA Season Stats

    private func nbaSeasonStatsView(_ stats: PlayerSeasonStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main stats grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                statBox("PPG", value: String(format: "%.1f", stats.ppg))
                statBox("RPG", value: String(format: "%.1f", stats.rpg))
                statBox("APG", value: String(format: "%.1f", stats.apg))
                statBox("FG%", value: String(format: "%.1f", stats.fgPct))
                statBox("3P%", value: String(format: "%.1f", stats.fg3Pct))
                statBox("FT%", value: String(format: "%.1f", stats.ftPct))
            }

            Divider()

            // Games info
            HStack {
                Text("\(stats.gamesPlayed) GP")
                Text("•")
                    .foregroundStyle(.tertiary)
                Text("\(stats.gamesStarted) GS")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - NFL Season Stats

    @ViewBuilder
    private var nflSeasonStatsView: some View {
        if let nflStats = viewModel.nflSeasonStats {
            let position = nflStats.positionCategory?.uppercased() ?? ""
            let stats = nflStats.statsJson

            VStack(alignment: .leading, spacing: 12) {
                // Position-specific stats
                switch position {
                case "QB":
                    nflQBStats(stats)
                case "RB":
                    nflRBStats(stats)
                case "WR", "TE":
                    nflReceiverStats(stats)
                case "DEF", "LB", "CB", "S", "DE", "DT":
                    nflDefenseStats(stats)
                case "K":
                    nflKickerStats(stats)
                default:
                    Text("Position: \(position)")
                        .foregroundStyle(.secondary)
                }

                Divider()

                HStack {
                    Text("\(nflStats.gamesPlayed) GP")
                    Text("•")
                        .foregroundStyle(.tertiary)
                    Text("\(nflStats.gamesStarted) GS")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        } else {
            Text("No NFL season stats available")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
        }
    }

    private func nflQBStats(_ stats: [String: Any]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            statBox("PASS YDS", value: "\(stats["passing_yards"] as? Int ?? 0)")
            statBox("TD", value: "\(stats["passing_touchdowns"] as? Int ?? 0)")
            statBox("INT", value: "\(stats["interceptions"] as? Int ?? 0)")
            statBox("CMP", value: "\(stats["completions"] as? Int ?? 0)")
            statBox("ATT", value: "\(stats["attempts"] as? Int ?? 0)")
            statBox("RTG", value: String(format: "%.1f", stats["passer_rating"] as? Double ?? 0))
        }
    }

    private func nflRBStats(_ stats: [String: Any]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            statBox("RUSH YDS", value: "\(stats["rushing_yards"] as? Int ?? 0)")
            statBox("RUSH TD", value: "\(stats["rushing_touchdowns"] as? Int ?? 0)")
            statBox("CAR", value: "\(stats["carries"] as? Int ?? 0)")
            statBox("REC YDS", value: "\(stats["receiving_yards"] as? Int ?? 0)")
            statBox("REC", value: "\(stats["receptions"] as? Int ?? 0)")
            statBox("REC TD", value: "\(stats["receiving_touchdowns"] as? Int ?? 0)")
        }
    }

    private func nflReceiverStats(_ stats: [String: Any]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            statBox("REC", value: "\(stats["receptions"] as? Int ?? 0)")
            statBox("TGT", value: "\(stats["targets"] as? Int ?? 0)")
            statBox("YDS", value: "\(stats["receiving_yards"] as? Int ?? 0)")
            statBox("TD", value: "\(stats["receiving_touchdowns"] as? Int ?? 0)")
            let yards = stats["receiving_yards"] as? Int ?? 0
            let rec = stats["receptions"] as? Int ?? 1
            statBox("AVG", value: String(format: "%.1f", Double(yards) / Double(max(rec, 1))))
            statBox("YAC", value: "\(stats["yards_after_catch"] as? Int ?? 0)")
        }
    }

    private func nflDefenseStats(_ stats: [String: Any]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            statBox("TOT", value: "\(stats["total_tackles"] as? Int ?? 0)")
            statBox("SOLO", value: "\(stats["solo_tackles"] as? Int ?? 0)")
            statBox("SACKS", value: String(format: "%.1f", stats["sacks"] as? Double ?? 0))
            statBox("INT", value: "\(stats["interceptions"] as? Int ?? 0)")
            statBox("FF", value: "\(stats["forced_fumbles"] as? Int ?? 0)")
            statBox("PD", value: "\(stats["passes_defended"] as? Int ?? 0)")
        }
    }

    private func nflKickerStats(_ stats: [String: Any]) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            let fgm = stats["field_goals_made"] as? Int ?? 0
            let fga = stats["field_goals_attempted"] as? Int ?? 0
            statBox("FG", value: "\(fgm)/\(fga)")
            statBox("FG%", value: String(format: "%.1f", fga > 0 ? Double(fgm) / Double(fga) * 100 : 0))
            statBox("LNG", value: "\(stats["long_fg"] as? Int ?? 0)")
            let xpm = stats["extra_points_made"] as? Int ?? 0
            let xpa = stats["extra_points_attempted"] as? Int ?? 0
            statBox("XP", value: "\(xpm)/\(xpa)")
            statBox("PTS", value: "\(fgm * 3 + xpm)")
            statBox("50+", value: "\(stats["fg_50_plus"] as? Int ?? 0)")
        }
    }

    // MARK: - Game Log Tab

    private var gameLogTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isLoadingGameLog {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else if viewModel.gameLogs.isEmpty {
                Text("No game logs available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                // Game log header
                HStack {
                    Text("Date")
                        .frame(width: 60, alignment: .leading)
                    Text("OPP")
                        .frame(width: 40, alignment: .leading)
                    Text("PTS")
                        .frame(width: 35, alignment: .trailing)
                    Text("REB")
                        .frame(width: 35, alignment: .trailing)
                    Text("AST")
                        .frame(width: 35, alignment: .trailing)
                    Text("FG%")
                        .frame(width: 45, alignment: .trailing)
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

                Divider()

                // Game log rows
                ForEach(viewModel.gameLogs) { game in
                    gameLogRow(game)
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func gameLogRow(_ game: NBAGameLogEntry) -> some View {
        HStack {
            Text(game.formattedDate)
                .frame(width: 60, alignment: .leading)
            Text(game.opponentAbbrev)
                .frame(width: 40, alignment: .leading)
            Text("\(game.points)")
                .frame(width: 35, alignment: .trailing)
            Text("\(game.rebounds.total)")
                .frame(width: 35, alignment: .trailing)
            Text("\(game.assists)")
                .frame(width: 35, alignment: .trailing)
            Text(String(format: "%.0f", (game.fieldGoals.percentage ?? 0) * 100))
                .frame(width: 45, alignment: .trailing)
        }
        .font(.caption)
    }

    // MARK: - Splits Tab

    private var splitsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.isLoadingSplits {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else if let splits = viewModel.splits {
                // Home/Away splits
                splitsSection(title: "Home/Away", splits: [
                    ("Home", splits.homeAway["HOME"]),
                    ("Away", splits.homeAway["AWAY"])
                ])

                Divider()

                // Last N games
                splitsSection(title: "Recent Games", splits: [
                    ("Last 5", splits.lastN["LAST5"]),
                    ("Last 10", splits.lastN["LAST10"]),
                    ("Last 20", splits.lastN["LAST20"])
                ])

                Divider()

                // By month
                if !splits.byMonth.isEmpty {
                    Text("By Month")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(splits.byMonth, id: \.month) { monthSplit in
                        splitRow(label: monthSplit.month, stats: monthSplit.stats)
                    }
                }
            } else {
                Text("No splits available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func splitsSection(title: String, splits: [(String, SplitStats?)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            ForEach(splits, id: \.0) { label, stats in
                if let stats = stats {
                    splitRow(label: label, stats: stats)
                }
            }
        }
    }

    private func splitRow(label: String, stats: SplitStats) -> some View {
        HStack {
            Text(label)
                .frame(width: 60, alignment: .leading)

            Spacer()

            Text("\(stats.gamesPlayed) GP")
                .frame(width: 50, alignment: .trailing)

            let ppg = stats.gamesPlayed > 0 ? Double(stats.points) / Double(stats.gamesPlayed) : 0
            Text(String(format: "%.1f PPG", ppg))
                .frame(width: 70, alignment: .trailing)

            let rpg = stats.gamesPlayed > 0 ? Double(stats.reb) / Double(stats.gamesPlayed) : 0
            Text(String(format: "%.1f RPG", rpg))
                .frame(width: 70, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    // MARK: - Career Tab

    private var careerTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isLoadingCareer {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else if viewModel.careerSeasons.isEmpty {
                Text("No career stats available")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                // Career header
                HStack {
                    Text("Season")
                        .frame(width: 55, alignment: .leading)
                    Text("GP")
                        .frame(width: 30, alignment: .trailing)
                    Text("PPG")
                        .frame(width: 40, alignment: .trailing)
                    Text("RPG")
                        .frame(width: 40, alignment: .trailing)
                    Text("APG")
                        .frame(width: 40, alignment: .trailing)
                    Text("FG%")
                        .frame(width: 45, alignment: .trailing)
                }
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

                Divider()

                // Career rows
                ForEach(viewModel.careerSeasons) { season in
                    careerSeasonRow(season)
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func careerSeasonRow(_ season: CareerSeasonSummary) -> some View {
        HStack {
            Text(season.seasonLabel)
                .frame(width: 55, alignment: .leading)
            Text("\(season.gamesPlayed)")
                .frame(width: 30, alignment: .trailing)
            Text(String(format: "%.1f", season.averages.ppg))
                .frame(width: 40, alignment: .trailing)
            Text(String(format: "%.1f", season.averages.rpg))
                .frame(width: 40, alignment: .trailing)
            Text(String(format: "%.1f", season.averages.apg))
                .frame(width: 40, alignment: .trailing)
            Text(String(format: "%.0f", (season.fieldGoals.percentage ?? 0) * 100))
                .frame(width: 45, alignment: .trailing)
        }
        .font(.caption)
    }

    // MARK: - Helper Views

    private func statBox(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - View Model

@MainActor
class PlayerProfileViewModel: ObservableObject {
    let playerId: String

    @Published var player: PlayerProfile?
    @Published var currentSeasonStats: PlayerSeasonStats?
    @Published var selectedTab: PlayerProfileTab = .season
    @Published var isLoading = false
    @Published var error: String?

    // Game log state
    @Published var gameLogs: [NBAGameLogEntry] = []
    @Published var isLoadingGameLog = false

    // Splits state
    @Published var splits: PlayerSplitsData?
    @Published var isLoadingSplits = false

    // Career state
    @Published var careerSeasons: [CareerSeasonSummary] = []
    @Published var isLoadingCareer = false

    // NFL stats state
    @Published var nflSeasonStats: NFLSeasonStats?

    private let client = GatewayClient.shared
    private var loadedTabs: Set<PlayerProfileTab> = [.season]

    init(playerId: String) {
        self.playerId = playerId
    }

    func loadPlayerProfile() async {
        isLoading = true
        error = nil

        do {
            let endpoint = GatewayEndpoint.player(id: playerId)
            let response: PlayerProfileResponse = try await client.fetch(endpoint)

            self.player = response.player
            self.currentSeasonStats = response.currentSeason
        } catch let networkError as NetworkError {
            self.error = networkError.errorDescription ?? "Failed to load profile"
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func loadTabData(for tab: PlayerProfileTab) async {
        guard !loadedTabs.contains(tab) else { return }

        switch tab {
        case .season:
            break // Already loaded with profile
        case .gameLog:
            await loadGameLog()
        case .splits:
            await loadSplits()
        case .career:
            await loadCareer()
        }

        loadedTabs.insert(tab)
    }

    private func loadGameLog() async {
        isLoadingGameLog = true

        do {
            let season = currentSeasonStats?.season ?? getCurrentSeason()
            let endpoint = GatewayEndpoint.playerGameLog(playerId: playerId, season: season, limit: 20)
            let response: GameLogResponse = try await client.fetch(endpoint)
            gameLogs = response.games
        } catch {
            // Silently fail, show empty state
            gameLogs = []
        }

        isLoadingGameLog = false
    }

    private func loadSplits() async {
        isLoadingSplits = true

        do {
            let season = currentSeasonStats?.season ?? getCurrentSeason()
            let endpoint = GatewayEndpoint.playerSplits(playerId: playerId, season: season)
            let response: SplitsResponse = try await client.fetch(endpoint)
            splits = response.splits
        } catch {
            splits = nil
        }

        isLoadingSplits = false
    }

    private func loadCareer() async {
        isLoadingCareer = true

        do {
            let endpoint = GatewayEndpoint.playerCareer(playerId: playerId)
            let response: CareerResponse = try await client.fetch(endpoint)
            careerSeasons = response.seasons
        } catch {
            careerSeasons = []
        }

        isLoadingCareer = false
    }

    private func getCurrentSeason() -> Int {
        let calendar = Calendar.current
        let now = Date()
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        return month >= 10 ? year : year - 1
    }
}

// MARK: - Models

struct PlayerProfileResponse: Codable {
    let player: PlayerProfile
    let currentSeason: PlayerSeasonStats
}

struct PlayerProfile: Codable {
    let id: String
    let sport: String
    let displayName: String
    let firstName: String?
    let lastName: String?
    let position: String?
    let heightIn: Int?
    let weightLb: Int?
    let school: String?
    let hometown: String?
    let headshotUrl: String?
    let currentTeamId: String?
    let isActive: Bool
    let jersey: String?
}

struct PlayerSeasonStats: Codable {
    let season: Int
    let gamesPlayed: Int
    let gamesStarted: Int
    let ppg: Double
    let rpg: Double
    let apg: Double
    let fgPct: Double
    let fg3Pct: Double
    let ftPct: Double
}

// MARK: - Game Log Models

struct GameLogResponse: Codable {
    let playerId: String
    let season: Int
    let games: [NBAGameLogEntry]
}

struct NBAGameLogEntry: Codable, Identifiable {
    let gameId: String
    let gameDate: String
    let teamId: String?
    let opponentTeamId: String?
    let isHome: Bool?
    let isStarter: Bool?
    let minutes: Int?
    let points: Int
    let fieldGoals: ShootingStats
    let threePointers: ShootingStats
    let freeThrows: ShootingStats
    let rebounds: ReboundStats
    let assists: Int
    let steals: Int
    let blocks: Int
    let turnovers: Int
    let personalFouls: Int
    let plusMinus: Int?
    let dnpReason: String?

    var id: String { gameId }

    var formattedDate: String {
        // Parse ISO date and format as "MM/DD"
        let parts = gameDate.prefix(10).split(separator: "-")
        guard parts.count >= 3 else { return gameDate }
        return "\(parts[1])/\(parts[2])"
    }

    var opponentAbbrev: String {
        guard let opponent = opponentTeamId else { return "-" }
        let prefix = isHome == true ? "vs" : "@"
        let team = opponent.replacingOccurrences(of: "nba_", with: "").uppercased()
        return "\(prefix)\(team.prefix(3))"
    }
}

struct ShootingStats: Codable {
    let made: Int
    let attempted: Int
    let percentage: Double?
}

struct ReboundStats: Codable {
    let offensive: Int
    let defensive: Int
    let total: Int
}

// MARK: - Splits Models

struct SplitsResponse: Codable {
    let playerId: String
    let season: Int
    let splits: PlayerSplitsData
}

struct PlayerSplitsData: Codable {
    let homeAway: [String: SplitStats]
    let lastN: [String: SplitStats]
    let byMonth: [MonthSplit]
}

struct SplitStats: Codable {
    let gamesPlayed: Int
    let minutes: Int?
    let points: Int
    let fgm: Int
    let fga: Int
    let fg3m: Int
    let fg3a: Int
    let ftm: Int
    let fta: Int
    let reb: Int
    let ast: Int
    let stl: Int
    let blk: Int
    let tov: Int
    let pf: Int

    enum CodingKeys: String, CodingKey {
        case gamesPlayed = "games_played"
        case minutes
        case points
        case fgm
        case fga
        case fg3m
        case fg3a
        case ftm
        case fta
        case reb
        case ast
        case stl
        case blk
        case tov
        case pf
    }
}

struct MonthSplit: Codable {
    let month: String
    let stats: SplitStats
}

// MARK: - Career Models

struct CareerResponse: Codable {
    let playerId: String
    let seasons: [CareerSeasonSummary]
}

struct CareerSeasonSummary: Codable, Identifiable {
    let season: Int
    let teamId: String?
    let gamesPlayed: Int
    let gamesStarted: Int
    let minutesTotal: Int
    let pointsTotal: Int
    let fieldGoals: ShootingStats
    let threePointers: ShootingStats
    let freeThrows: ShootingStats
    let rebounds: ReboundStats
    let assists: Int
    let steals: Int
    let blocks: Int
    let turnovers: Int
    let personalFouls: Int
    let averages: SeasonAverages

    var id: Int { season }

    var seasonLabel: String {
        let nextYear = (season + 1) % 100
        return "\(season)-\(String(format: "%02d", nextYear))"
    }
}

struct SeasonAverages: Codable {
    let ppg: Double
    let rpg: Double
    let apg: Double
}

// MARK: - NFL Models

struct NFLSeasonStatsResponse: Codable {
    let playerId: String
    let season: Int
    let stats: NFLSeasonStats
}

struct NFLSeasonStats: Codable {
    let gamesPlayed: Int
    let gamesStarted: Int
    let positionCategory: String?
    let statsJson: [String: Any]

    enum CodingKeys: String, CodingKey {
        case gamesPlayed = "games_played"
        case gamesStarted = "games_started"
        case positionCategory = "position_category"
        case statsJson = "stats_json"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        gamesPlayed = try container.decodeIfPresent(Int.self, forKey: .gamesPlayed) ?? 0
        gamesStarted = try container.decodeIfPresent(Int.self, forKey: .gamesStarted) ?? 0
        positionCategory = try container.decodeIfPresent(String.self, forKey: .positionCategory)

        // Decode stats_json as flexible dictionary
        if let jsonData = try? container.decode([String: AnyCodable].self, forKey: .statsJson) {
            statsJson = jsonData.mapValues { $0.value }
        } else {
            statsJson = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(gamesPlayed, forKey: .gamesPlayed)
        try container.encode(gamesStarted, forKey: .gamesStarted)
        try container.encodeIfPresent(positionCategory, forKey: .positionCategory)
        // Skip encoding statsJson for now
    }
}

// Helper for decoding Any values
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else {
            value = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let string = value as? String {
            try container.encode(string)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        }
    }
}

#Preview {
    NavigationStack {
        PlayerProfileView(playerId: "542839ef-df72-450b-98f8-a8bef0ddcc8a")
    }
}
