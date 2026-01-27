//
//  AppState.swift
//  BoxScore
//
//  Shared app state for cross-tab synchronization
//

import Foundation
import SwiftUI

@Observable
class AppState {

    /// The currently selected sport, shared between Scores and Leagues tabs
    var selectedSport: Sport = .nba

    // MARK: - Theme State

    /// The user's theme preference (light, dark, or auto)
    var currentTheme: ThemeMode = .auto

    /// The effective color scheme currently applied (computed from currentTheme)
    var effectiveColorScheme: ColorScheme = .light

    /// Singleton instance for app-wide access
    static let shared = AppState()

    private init() {
        // Load saved theme preference and compute initial effective scheme
        let savedTheme = ThemeManager.shared.loadThemePreference()
        self.currentTheme = savedTheme
        self.effectiveColorScheme = ThemeManager.shared.computeEffectiveScheme(for: savedTheme)
    }
}
