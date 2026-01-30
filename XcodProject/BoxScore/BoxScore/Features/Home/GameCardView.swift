//
//  GameCardView.swift
//  BoxScore
//
//  Simple game card - tap to expand box score
//

import SwiftUI

struct GameCardView: View {
    let game: Game
    @Bindable var viewModel: HomeViewModel
    var onExpand: (() -> Void)? = nil

    @Environment(AppState.self) private var appState

    // Which team's box score is showing (nil = collapsed)
    @State private var expandedTeam: TeamSide? = nil

    // MARK: - Team Logo Helper

    private func teamLogoName(for team: TeamInfo) -> String {
        let league = game.sport.rawValue.lowercased()
        let abbr = team.abbreviation.lowercased()
        return "team-\(league)-\(abbr)"
    }

    @ViewBuilder
    private func teamLogo(for team: TeamInfo, size: CGFloat = 28) -> some View {
        let imageName = teamLogoName(for: team)
        if let _ = UIImage(named: imageName) {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            // Fallback: empty space if no logo
            Color.clear
                .frame(width: size, height: size)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main score card - tap either side to expand that team
            scoreCard
            
            // Expanded box score (only one at a time)
            if let side = expandedTeam {
                teamBoxScoreSection(for: side)
            }
        }
        .background(Theme.cardBackground(for: appState.effectiveColorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 10)
    }
    
    // MARK: - Score Card

    private var scoreCard: some View {
        Group {
            // Use scheduled layout if status is scheduled OR if both scores are nil (defensive check)
            if game.status.isScheduled || (game.awayScore == nil && game.homeScore == nil) {
                // Scheduled game layout - no scores, centered teams
                scheduledGameLayout
            } else {
                // Live or final game layout - with scores
                liveOrFinalGameLayout
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    // MARK: - Scheduled Game Layout

    private var scheduledGameLayout: some View {
        HStack(spacing: 0) {
            // Away team - centered in left half
            Button {
                toggleExpanded(.away)
            } label: {
                VStack(spacing: 2) {
                    teamLogo(for: game.awayTeam, size: 36)
                    Text(game.awayTeam.abbreviation)
                        .font(Theme.displayFont(size: 13))
                        .foregroundStyle(.primary)
                }
                .frame(width: 50)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(expandedTeam == .away ? Color.yellow.opacity(0.15) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)

            // Center: Status and @
            VStack(spacing: 2) {
                Text(game.status.displayText)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)

                Text("@")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50)

            // Home team - centered in right half
            Button {
                toggleExpanded(.home)
            } label: {
                VStack(spacing: 2) {
                    teamLogo(for: game.homeTeam, size: 36)
                    Text(game.homeTeam.abbreviation)
                        .font(Theme.displayFont(size: 13))
                        .foregroundStyle(.primary)
                }
                .frame(width: 50)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(expandedTeam == .home ? Color.yellow.opacity(0.15) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Live/Final Game Layout

    private var liveOrFinalGameLayout: some View {
        let scoreSize: CGFloat = game.status.isFinal ? 32 : 28

        return HStack(spacing: 0) {
            // Away team logo + abbr (fixed width)
            Button {
                toggleExpanded(.away)
            } label: {
                VStack(spacing: 2) {
                    teamLogo(for: game.awayTeam, size: 36)
                    Text(game.awayTeam.abbreviation)
                        .font(Theme.displayFont(size: 13))
                        .foregroundStyle(.primary)
                }
                .frame(width: 50)
            }
            .buttonStyle(.plain)

            // Away score (centered in remaining space)
            Text("\(game.awayScore ?? 0)")
                .font(Theme.displayFont(size: scoreSize))
                .foregroundStyle(.primary)
                .fixedSize()
                .frame(maxWidth: .infinity)

            // Center: Status and @
            VStack(spacing: 2) {
                Text(game.status.displayText)
                    .font(.system(size: 11, weight: game.status.isFinal ? .bold : .medium))
                    .foregroundStyle(game.status.isLive ? .red : .primary)

                Text("@")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 50)

            // Home score (centered in remaining space)
            Text("\(game.homeScore ?? 0)")
                .font(Theme.displayFont(size: scoreSize))
                .foregroundStyle(.primary)
                .fixedSize()
                .frame(maxWidth: .infinity)

            // Home team logo + abbr (fixed width)
            Button {
                toggleExpanded(.home)
            } label: {
                VStack(spacing: 2) {
                    teamLogo(for: game.homeTeam, size: 36)
                    Text(game.homeTeam.abbreviation)
                        .font(Theme.displayFont(size: 13))
                        .foregroundStyle(.primary)
                }
                .frame(width: 50)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Toggle Logic
    
    private func toggleExpanded(_ side: TeamSide) {
        withAnimation(Theme.standardAnimation) {
            if expandedTeam == side {
                // Collapse if tapping same team
                expandedTeam = nil
            } else {
                // Expand this team (replaces any currently open)
                expandedTeam = side
                
                // Fetch box score data if not already loaded
                Task {
                    await viewModel.fetchBoxScore(for: game.id)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    onExpand?()
                }
            }
        }
    }
    
    // MARK: - Team Box Score Section
    
    @ViewBuilder
    private func teamBoxScoreSection(for side: TeamSide) -> some View {
        let boxScore = side == .away ? game.awayBoxScore : game.homeBoxScore
        let team = side == .away ? game.awayTeam : game.homeTeam
        let isLoading = viewModel.isBoxScoreLoading(gameId: game.id)
        
        VStack(spacing: 0) {
            // Team header - black background
            HStack {
                Text(team.fullName.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.black)

            // Sport-specific box score (or loading placeholder)
            if isLoading && boxScore.isEmpty {
                // Loading placeholder - fixed height with centered spinner
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 300)
                .background(Theme.secondaryBackground(for: appState.effectiveColorScheme))
            } else {
                switch boxScore {
                case .nba(let nbaBoxScore):
                    if nbaBoxScore.starters.isEmpty {
                        boxScoreEmptyState
                    } else {
                        NBABoxScoreView(
                            boxScore: nbaBoxScore,
                            isCollegeBasketball: game.sport == .ncaam,
                            isGameFinal: game.status.isFinal
                        )
                    }

                case .nfl(let nflBoxScore):
                    if nflBoxScore.groups.isEmpty {
                        boxScoreEmptyState
                    } else {
                        NFLBoxScoreView(
                            boxScore: nflBoxScore,
                            gameId: game.id,
                            teamSide: side,
                            viewModel: viewModel,
                            onGroupExpand: onExpand
                        )
                    }

                case .nhl(let nhlBoxScore):
                    if nhlBoxScore.skaters.isEmpty {
                        boxScoreEmptyState
                    } else {
                        NHLBoxScoreView(boxScore: nhlBoxScore)
                    }
                }
            }
        }
        .animation(Theme.standardAnimation, value: isLoading)
    }

    /// Empty state when box score data is unavailable
    private var boxScoreEmptyState: some View {
        VStack(spacing: 8) {
            Text("No box score available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Game may not have started yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Theme.secondaryBackground(for: appState.effectiveColorScheme))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            GameCardView(
                game: NBAMockData.game1,
                viewModel: HomeViewModel()
            )
            GameCardView(
                game: NBAMockData.game2,
                viewModel: HomeViewModel()
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
