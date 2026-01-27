//
//  LeaguesSubTabBar.swift
//  BoxScore
//
//  Horizontal sub-tab bar for Leagues section (Standings | Teams | Stats)
//

import SwiftUI

struct LeaguesSubTabBar: View {
    @Binding var selectedTab: LeaguesSubTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(LeaguesSubTab.allCases) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 14, weight: selectedTab == tab ? .semibold : .regular))
                        .foregroundStyle(selectedTab == tab ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedTab == tab
                                ? Color.black
                                : Color(.systemGray6)
                        )
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

#Preview {
    @Previewable @State var selected: LeaguesSubTab = .standings
    VStack {
        LeaguesSubTabBar(selectedTab: $selected)
        Spacer()
    }
}
