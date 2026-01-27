//
//  AppState.swift
//  BoxScore
//
//  Global app state for theme and preferences
//

import SwiftUI

@Observable
class AppState {

    // MARK: - Singleton

    static let shared = AppState()

    // MARK: - Theme

    /// User's selected theme mode (light, dark, or auto)
    var currentTheme: ThemeMode = .auto

    /// The effective color scheme to apply (stored, updated by ThemeManager)
    var effectiveColorScheme: ColorScheme = .light

    // MARK: - Initialization

    private init() {
        // Load saved preference and compute initial effective scheme
        let savedTheme = ThemeManager.shared.loadThemePreference()
        currentTheme = savedTheme
        effectiveColorScheme = ThemeManager.shared.computeEffectiveScheme(for: savedTheme)
    }
}
