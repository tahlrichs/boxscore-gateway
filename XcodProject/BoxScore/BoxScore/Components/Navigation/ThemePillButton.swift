//
//  ThemePillButton.swift
//  BoxScore
//
//  Created by BoxScore Team
//

import SwiftUI

/// Individual pill button for theme selection (ON, OFF, AUTO)
/// Styled as part of a segmented control
struct ThemePillButton: View {

    let title: String
    let mode: ThemeMode
    let currentMode: ThemeMode
    let onTap: () -> Void

    /// Whether this button is currently selected
    private var isSelected: Bool {
        mode == currentMode
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(height: 32)
                .frame(minWidth: 50)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.blue : Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Container for the three theme pill buttons (ON | OFF | AUTO)
/// Styled as an iOS-like segmented control
struct ThemePillGroup: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        HStack(spacing: 0) {
            // OFF (Light mode)
            ThemePillButton(
                title: "OFF",
                mode: .light,
                currentMode: appState.currentTheme
            ) {
                ThemeManager.shared.applyThemeChange(.light, to: appState)
            }

            Divider()
                .frame(height: 20)

            // ON (Dark mode)
            ThemePillButton(
                title: "ON",
                mode: .dark,
                currentMode: appState.currentTheme
            ) {
                ThemeManager.shared.applyThemeChange(.dark, to: appState)
            }

            Divider()
                .frame(height: 20)

            // AUTO (System)
            ThemePillButton(
                title: "AUTO",
                mode: .auto,
                currentMode: appState.currentTheme
            ) {
                ThemeManager.shared.applyThemeChange(.auto, to: appState)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}
