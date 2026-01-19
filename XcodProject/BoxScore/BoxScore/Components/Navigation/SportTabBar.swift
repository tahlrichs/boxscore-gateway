//
//  SportTabBar.swift
//  BoxScore
//
//  Horizontal scrolling sport selector - black bar with yellow indicator
//

import SwiftUI

struct SportTabBar: View {
    @Binding var selectedSport: Sport
    var onFavoritesTap: (() -> Void)? = nil

    // All sports to display (always show all)
    private let allSports: [Sport] = Sport.allCases

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                // Favorites star button
                Button {
                    onFavoritesTap?()
                } label: {
                    Image(systemName: "star.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.yellow)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                ForEach(allSports) { sport in
                    SportTabButton(
                        sport: sport,
                        isSelected: sport == selectedSport
                    ) {
                        selectedSport = sport
                    }
                }
            }
        }
        .frame(height: 44)
        .background(Color.black)
    }
}

struct SportTabButton: View {
    let sport: Sport
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(sport.displayName)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .foregroundStyle(.white)
                .frame(minWidth: 60)
                .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var selected: Sport = .nba
    SportTabBar(selectedSport: $selected)
}
