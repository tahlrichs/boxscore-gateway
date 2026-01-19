//
//  SlideOutMenu.swift
//  BoxScore
//
//  Slide-out menu from left edge with integrated search
//

import SwiftUI

struct SlideOutMenu: View {
    @Binding var isPresented: Bool
    var onSelectPlayer: (String) -> Void
    var onSelectTeam: (String) -> Void

    @State private var searchText: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching: Bool = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            let menuWidth = geometry.size.width * 0.85

            ZStack(alignment: .leading) {
            // Dark overlay
            if isPresented {
                Color.black
                    .opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissMenu()
                    }
            }

            // Sliding panel
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header with close button
                    menuHeader

                    // Search bar
                    searchBar

                    Divider()

                    // Search results or empty state
                    if isSearching {
                        loadingView
                    } else if !searchText.isEmpty && searchResults.isEmpty {
                        noResultsView
                    } else if !searchResults.isEmpty {
                        searchResultsList
                    } else {
                        searchPromptView
                    }

                    Spacer()

                    // Footer
                    menuFooter
                }
                .frame(width: menuWidth)
                .background(Color(.systemBackground))

                Spacer()
            }
            .offset(x: isPresented ? 0 : -menuWidth)
        }
        .gesture(
            DragGesture()
                .onEnded { value in
                    if value.translation.width < -50 {
                        dismissMenu()
                    }
                }
        )
        }
    }

    private func dismissMenu() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isPresented = false
        }
        // Clear search after dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            searchText = ""
            searchResults = []
        }
    }

    // MARK: - Menu Header

    private var menuHeader: some View {
        HStack {
            Text("Italics")
                .font(.title2)
                .fontWeight(.semibold)
                .italic()

            Spacer()

            Button {
                dismissMenu()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search players or teams", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onChange(of: searchText) { _, newValue in
                    performSearch(query: newValue)
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Search Results List

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchResults) { result in
                    SearchResultRow(result: result) {
                        switch result.type {
                        case .player:
                            dismissMenu()
                            onSelectPlayer(result.id)
                        case .team:
                            dismissMenu()
                            onSelectTeam(result.id)
                        }
                    }
                    Divider()
                        .padding(.leading, 60)
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
            Text("Searching...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No results found")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Try a different search term")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Search Prompt View

    private var searchPromptView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Search")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Find players and teams")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Menu Footer

    private var menuFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()

            HStack {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Text("Version 1.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Search Logic

    private func performSearch(query: String) {
        searchTask?.cancel()

        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        searchTask = Task {
            isSearching = true

            // Debounce
            try? await Task.sleep(nanoseconds: 300_000_000)

            guard !Task.isCancelled else { return }

            do {
                let results = try await fetchSearchResults(query: query)
                if !Task.isCancelled {
                    searchResults = results
                }
            } catch {
                if !Task.isCancelled {
                    searchResults = []
                }
            }

            if !Task.isCancelled {
                isSearching = false
            }
        }
    }

    private func fetchSearchResults(query: String) async throws -> [SearchResult] {
        let endpoint = GatewayEndpoint.playerSearch(
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            sport: nil,
            limit: 15
        )

        let client = GatewayClient.shared
        let response: PlayerSearchResponse = try await client.fetch(endpoint)

        return response.players.map { player in
            SearchResult(
                id: player.id,
                type: .player,
                title: player.displayName,
                subtitle: [player.position, player.sport.uppercased()].compactMap { $0 }.joined(separator: " • "),
                sport: player.sport
            )
        }
    }
}

// MARK: - Player Search Response (from Gateway)

struct PlayerSearchResponse: Codable {
    let players: [PlayerSearchResult]
    let meta: PlayerSearchMeta
}

struct PlayerSearchMeta: Codable {
    let query: String
    let sport: String?
    let count: Int
    let limit: Int
}

struct PlayerSearchResult: Codable, Identifiable {
    let id: String
    let sport: String
    let displayName: String
    let position: String?
    let currentTeamId: String?
}

// MARK: - Search Result Model

struct SearchResult: Identifiable {
    let id: String
    let type: SearchResultType
    let title: String
    let subtitle: String
    let sport: String

    enum SearchResultType {
        case player
        case team
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let result: SearchResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: result.type == .player ? "person.circle.fill" : "shield.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(sportColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)

                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var sportColor: Color {
        switch result.sport.lowercased() {
        case "nba": return .orange
        case "nfl": return .green
        case "nhl": return .blue
        case "mlb": return .red
        default: return .gray
        }
    }
}

#Preview {
    SlideOutMenu(
        isPresented: .constant(true),
        onSelectPlayer: { _ in },
        onSelectTeam: { _ in }
    )
}
