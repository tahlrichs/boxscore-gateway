//
//  StatsPlaceholderView.swift
//  BoxScore
//
//  Placeholder view for Stats sub-tab (coming soon)
//

import SwiftUI

struct StatsPlaceholderView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("Stats Coming Soon")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("League stats for \(appState.selectedSport.displayName) will be available in a future update.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    StatsPlaceholderView()
        .environment(AppState.shared)
}
