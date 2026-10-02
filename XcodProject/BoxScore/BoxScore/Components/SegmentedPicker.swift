//
//  SegmentedPicker.swift
//  BoxScore
//
//  Reusable segmented picker matching the app's tab picker style
//

import SwiftUI

struct SegmentedPicker<T: Hashable & CaseIterable & RawRepresentable>: View where T.AllCases: RandomAccessCollection, T.RawValue == String {
    @Binding var selection: T
    var options: [T]
    var colorScheme: ColorScheme

    init(selection: Binding<T>, options: [T]? = nil, colorScheme: ColorScheme) {
        self._selection = selection
        self.options = options ?? Array(T.allCases)
        self.colorScheme = colorScheme
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(Theme.standardAnimation) {
                        selection = option
                    }
                } label: {
                    Text(option.rawValue)
                        .font(.subheadline)
                        .fontWeight(selection == option ? .bold : .regular)
                        .foregroundStyle(selection == option ? Theme.text(for: colorScheme) : Theme.secondaryText(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selection == option
                                ? Theme.cardBackground(for: colorScheme)
                                : Color.clear
                        )
                        .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(Theme.secondaryBackground(for: colorScheme))
        .cornerRadius(12)
    }
}
