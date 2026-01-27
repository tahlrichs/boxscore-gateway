//
//  HomeView.swift
//  BoxScore
//
//  Main home screen with sport tabs, date selector, and game cards
//

import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = HomeViewModel()
    @State private var selectedTab: AppTab = .scores
    @State private var showMenu = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
            VStack(spacing: 0) {
            // Top navigation bar (black)
            TopNavBar(onMenuTap: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showMenu = true
                }
            })

            // Sport tabs (black with yellow indicator)
            SportTabBar(selectedSport: Bindable(appState).selectedSport)

            // Date/Week selector only shown on Scores tab
            if selectedTab == .scores {
                // Golf uses week selector, other sports use date selector
                if viewModel.selectedSport.isGolf {
                    // Week selector for golf
                    WeekSelector(
                        weeks: viewModel.availableWeeks,
                        selectedWeek: $viewModel.selectedWeek
                    )

                    // Tour filter bar
                    golfFilterBar
                } else {
                    // Date selector (white)
                    DateSelector(
                        dates: viewModel.availableDates,
                        selectedDate: $viewModel.selectedDate
                    )

                    // Conference selector (only for college sports)
                    if viewModel.selectedSport.isCollegeSport {
                        conferenceFilterBar
                    }
                }
            }

            // Main content
            ZStack {
                Theme.secondaryBackground(for: appState.effectiveColorScheme)
                    .ignoresSafeArea()

                switch selectedTab {
                case .scores:
                    scoresView
                case .top:
                    placeholderView(title: "Top")
                case .leagues:
                    LeaguesView()
                }
            }

            // Bottom tab bar (black)
            BottomTabBar(selectedTab: $selectedTab)
            }

            // Slide-out menu overlay with integrated search
            SlideOutMenu(
                isPresented: $showMenu,
                onSelectPlayer: { playerId in
                    navigationPath.append(PlayerProfileRoute(playerId: playerId))
                },
                onSelectTeam: { teamId in
                    // TODO: Navigate to team profile
                }
            )
            }
            .navigationDestination(for: PlayerProfileRoute.self) { route in
                PlayerProfileView(playerId: route.playerId)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .onAppear {
            // Initialize viewModel's sport from shared state
            if viewModel.selectedSport != appState.selectedSport {
                viewModel.selectedSport = appState.selectedSport
            }
        }
        .onChange(of: appState.selectedSport) { _, newSport in
            // Sync shared state to viewModel
            if viewModel.selectedSport != newSport {
                viewModel.selectedSport = newSport
            }
        }
    }
    
    // MARK: - Conference Filter Bar

    private var conferenceFilterBar: some View {
        HStack {
            Spacer()

            ConferenceSelector(
                sport: viewModel.selectedSport,
                selectedConference: $viewModel.selectedConference
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Theme.background(for: appState.effectiveColorScheme))
    }

    // MARK: - Golf Filter Bar

    private var golfFilterBar: some View {
        HStack {
            Spacer()

            TourSelector(selectedTour: $viewModel.selectedTour)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Theme.background(for: appState.effectiveColorScheme))
    }
    
    // MARK: - Scores View

    private var scoresView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    if viewModel.selectedSport.isGolf {
                        // Golf tournaments view
                        golfTournamentsView(proxy: proxy)
                    } else {
                        // Regular games view
                        gamesListView(proxy: proxy)
                    }

                    // Error message
                    if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }
                }
                .padding(.top, 8)
            }
            .refreshable {
                if viewModel.selectedSport.isGolf {
                    await viewModel.refreshTournaments()
                } else {
                    await viewModel.refreshGames()
                }
            }
        }
    }

    // MARK: - Games List View

    @ViewBuilder
    private func gamesListView(proxy: ScrollViewProxy) -> some View {
        // Loading indicator
        if viewModel.loadingState.isLoading && viewModel.filteredGames.isEmpty {
            loadingView
        } else if viewModel.filteredGames.isEmpty {
            emptyStateView
        } else {
            ForEach(viewModel.filteredGames) { game in
                GameCardView(game: game, viewModel: viewModel, onExpand: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(game.id, anchor: .top)
                    }
                })
                .id(game.id)
            }
        }
    }

    // MARK: - Golf Tournaments View

    @ViewBuilder
    private func golfTournamentsView(proxy: ScrollViewProxy) -> some View {
        // Loading indicator
        if viewModel.tournamentsLoadingState.isLoading && viewModel.tournaments.isEmpty {
            loadingView
        } else if viewModel.tournaments.isEmpty {
            golfEmptyStateView
        } else {
            ForEach(viewModel.tournaments) { tournament in
                TournamentCardView(tournament: tournament, onExpand: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(tournament.id, anchor: .top)
                    }
                })
                .id(tournament.id)
            }
        }
    }

    // MARK: - Golf Empty State

    private var golfEmptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "flag.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No Tournaments")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("No \(viewModel.selectedTour.name) tournaments this week")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 100)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading games...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 100)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sportscourt")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("No Games")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("No \(viewModel.selectedSport.displayName) games on this date")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 100)
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button("Retry") {
                Task { await viewModel.loadGames() }
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.cardBackground(for: appState.effectiveColorScheme))
        .cornerRadius(8)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Placeholder Views
    
    private func placeholderView(title: String) -> some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            Text("Coming Soon")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    HomeView()
        .environment(AppState.shared)
}
