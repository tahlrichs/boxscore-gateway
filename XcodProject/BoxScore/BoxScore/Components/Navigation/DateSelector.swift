//
//  DateSelector.swift
//  BoxScore
//
//  Horizontal scrolling date selector - MON Dec 29 format
//

import SwiftUI

struct DateSelector: View {
    let dates: [Date]
    @Binding var selectedDate: Date
    
    private let calendar = Calendar.current
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(dates, id: \.self) { date in
                        DateCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
                        ) {
                            selectedDate = date
                        }
                        .id(date)
                    }
                }
            }
            .frame(height: 44)
            .background(Color(.systemBackground))
            .onAppear {
                // Scroll to selected date when view appears
                scrollToSelectedDate(proxy: proxy)
            }
            .onChange(of: selectedDate) { oldValue, newValue in
                // Scroll to new date when selection changes
                if !calendar.isDate(oldValue, inSameDayAs: newValue) {
                    scrollToSelectedDate(proxy: proxy)
                }
            }
            .onChange(of: dates) { _, _ in
                // Scroll to selected date when dates are loaded/updated
                scrollToSelectedDate(proxy: proxy)
            }
        }
    }

    private func scrollToSelectedDate(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                proxy.scrollTo(selectedDate, anchor: .center)
            }
        }
    }
}

struct DateCell: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void
    
    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
    
    private var monthDay: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(dayOfWeek)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                
                Text(monthDay)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(width: 54, height: 44)
            .background(isSelected ? Color(.systemGray5) : Color.clear)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var selected = Date()
    let dates = (-7...7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: Date())) }
    DateSelector(dates: dates, selectedDate: $selected)
}
