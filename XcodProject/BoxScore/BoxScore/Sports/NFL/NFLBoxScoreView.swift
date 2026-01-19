//
//  NFLBoxScoreView.swift
//  BoxScore
//
//  NFL-specific box score with tab-based group selection
//

import SwiftUI

struct NFLBoxScoreView: View {
    let boxScore: NFLTeamBoxScore
    let gameId: String
    let teamSide: TeamSide
    @Bindable var viewModel: HomeViewModel
    var onGroupExpand: (() -> Void)? = nil
    
    @State private var selectedGroupType: NFLGroupType = .offense
    
    private var selectedGroup: NFLGroup? {
        boxScore.groups.first { $0.type == selectedGroupType }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Check if we have any data
            if boxScore.groups.isEmpty {
                emptyStateView
            } else {
                // Tab bar for group selection
                groupTabBar
                
                // Selected group's sections
                if let group = selectedGroup {
                    ForEach(group.sections) { section in
                        sectionView(section)
                    }
                } else {
                    // No data for selected group
                    Text("No \(selectedGroupType.displayName.lowercased()) stats available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Text("No box score available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Game may not have started yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemGray6).opacity(0.5))
    }
    
    // MARK: - Group Tab Bar
    
    private var groupTabBar: some View {
        HStack(spacing: 0) {
            ForEach(NFLGroupType.allCases) { groupType in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selectedGroupType = groupType
                    }
                } label: {
                    Text(groupType.displayName)
                        .font(.caption)
                        .fontWeight(selectedGroupType == groupType ? .bold : .medium)
                        .foregroundStyle(selectedGroupType == groupType ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            selectedGroupType == groupType
                                ? Color.blue
                                : Color(.systemGray5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    // MARK: - Section View (Passing / Rushing / etc.)
    
    @ViewBuilder
    private func sectionView(_ section: NFLSection) -> some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text(section.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.leading, 12)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            
            // Table content
            if section.isEmpty {
                EmptyTableStateView(message: "No \(section.displayName)")
            } else {
                SimpleTableView(
                    columns: section.columns,
                    rows: section.rows,
                    teamTotalsRow: section.teamTotalsRow,
                    playerColumnWidth: NFLColumns.playerColumnWidth
                )
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            NFLBoxScoreView(
                boxScore: NFLMockData.chiefsBoxScore,
                gameId: "preview",
                teamSide: .away,
                viewModel: HomeViewModel()
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
