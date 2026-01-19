//
//  WeekSelector.swift
//  BoxScore
//
//  Horizontal scrolling week selector for golf - "Week of Jan 12-18" format
//

import SwiftUI

struct WeekSelector: View {
    let weeks: [Date]  // Array of Monday dates representing each week
    @Binding var selectedWeek: Date

    private let calendar = Calendar.current

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(weeks, id: \.self) { weekStart in
                        WeekCell(
                            weekStart: weekStart,
                            isSelected: calendar.isDate(weekStart, inSameDayAs: selectedWeek)
                        ) {
                            selectedWeek = weekStart
                        }
                        .id(weekStart)
                    }
                }
            }
            .frame(height: 44)
            .background(Color(.systemBackground))
            .onAppear {
                scrollToSelectedWeek(proxy: proxy)
            }
            .onChange(of: selectedWeek) { oldValue, newValue in
                if !calendar.isDate(oldValue, inSameDayAs: newValue) {
                    scrollToSelectedWeek(proxy: proxy)
                }
            }
            .onChange(of: weeks) { _, _ in
                scrollToSelectedWeek(proxy: proxy)
            }
        }
    }

    private func scrollToSelectedWeek(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                proxy.scrollTo(selectedWeek, anchor: .center)
            }
        }
    }
}

struct WeekCell: View {
    let weekStart: Date
    let isSelected: Bool
    let action: () -> Void

    private let calendar = Calendar.current

    /// Week end date (Sunday)
    private var weekEnd: Date {
        calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    }

    /// Display format: "Jan 12-18"
    private var weekDisplay: String {
        let startFormatter = DateFormatter()
        startFormatter.dateFormat = "MMM d"
        let startStr = startFormatter.string(from: weekStart)

        let endFormatter = DateFormatter()
        // If same month, just show day number; otherwise show "MMM d"
        if calendar.component(.month, from: weekStart) == calendar.component(.month, from: weekEnd) {
            endFormatter.dateFormat = "d"
        } else {
            endFormatter.dateFormat = "MMM d"
        }
        let endStr = endFormatter.string(from: weekEnd)

        return "\(startStr)-\(endStr)"
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("WEEK")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Text(weekDisplay)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(width: 80, height: 44)
            .background(isSelected ? Color(.systemGray5) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helper Extension

extension WeekSelector {
    /// Get the Monday of the week containing a given date
    static func mondayOfWeek(containing date: Date) -> Date {
        let calendar = Calendar.current
        let dayOfWeek = calendar.component(.weekday, from: date)
        // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
        let daysFromMonday = dayOfWeek == 1 ? -6 : 2 - dayOfWeek
        let monday = calendar.date(byAdding: .day, value: daysFromMonday, to: date)!
        return calendar.startOfDay(for: monday)
    }

    /// Generate an array of week start dates (Mondays)
    static func generateWeeks(around date: Date, weeksBefore: Int = 26, weeksAfter: Int = 26) -> [Date] {
        let calendar = Calendar.current
        let currentMonday = mondayOfWeek(containing: date)

        var weeks: [Date] = []

        for offset in -weeksBefore...weeksAfter {
            if let weekStart = calendar.date(byAdding: .weekOfYear, value: offset, to: currentMonday) {
                weeks.append(weekStart)
            }
        }

        return weeks
    }
}

#Preview {
    @Previewable @State var selected = WeekSelector.mondayOfWeek(containing: Date())
    let weeks = WeekSelector.generateWeeks(around: Date(), weeksBefore: 4, weeksAfter: 4)
    WeekSelector(weeks: weeks, selectedWeek: $selected)
}
