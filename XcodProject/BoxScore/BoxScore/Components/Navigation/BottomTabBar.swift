//
//  BottomTabBar.swift
//  BoxScore
//
//  Bottom navigation - black bar with Top, Scores, Standings
//

import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case top
    case scores
    case standings
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .top: return "Top"
        case .scores: return "Scores"
        case .standings: return "Standings"
        }
    }
}

struct BottomTabBar: View {
    @Binding var selectedTab: AppTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(AppTab.allCases.enumerated()), id: \.element.id) { index, tab in
                if index > 0 {
                    // Vertical divider
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 1, height: 24)
                }
                
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.title)
                        .font(.system(size: 16, weight: selectedTab == tab ? .bold : .regular))
                        .foregroundStyle(selectedTab == tab ? .white : .gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.black)
    }
}

#Preview {
    @Previewable @State var selected: AppTab = .scores
    VStack {
        Spacer()
        BottomTabBar(selectedTab: $selected)
    }
}
