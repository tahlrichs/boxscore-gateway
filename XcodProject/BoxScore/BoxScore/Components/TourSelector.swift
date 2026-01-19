//
//  TourSelector.swift
//  BoxScore
//
//  Tour filter dropdown for golf (PGA Tour, LPGA Tour)
//

import SwiftUI

struct TourSelector: View {
    @Binding var selectedTour: GolfTour

    private var displayName: String {
        selectedTour.name
    }

    var body: some View {
        Menu {
            ForEach(GolfTour.allTours) { tour in
                Button(action: {
                    selectedTour = tour
                }) {
                    HStack {
                        Text(tour.name)
                        if selectedTour.id == tour.id {
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
            TourSelector(selectedTour: .constant(.pga))
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
