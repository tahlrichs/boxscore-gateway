//
//  ConferenceSelector.swift
//  BoxScore
//
//  Conference filter dropdown for college sports
//

import SwiftUI

struct ConferenceSelector: View {
    let sport: Sport
    @Binding var selectedConference: CollegeConference?
    @State private var showingPicker = false
    
    private var conferences: [CollegeConference] {
        CollegeConference.conferences(for: sport)
    }
    
    private var displayName: String {
        selectedConference?.name ?? "Top 25"
    }
    
    var body: some View {
        Menu {
            ForEach(conferences) { conference in
                Button(action: {
                    selectedConference = conference
                }) {
                    HStack {
                        Text(conference.name)
                        if selectedConference?.id == conference.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        Spacer()
        HStack {
            Spacer()
            ConferenceSelector(
                sport: .ncaaf,
                selectedConference: .constant(CollegeConference.top25NCAAF)
            )
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
