//
//  ThemeManager.swift
//  BoxScore
//
//  Created by BoxScore Team
//

import SwiftUI
import UIKit

/// Manages theme persistence and system appearance detection
final class ThemeManager {

    // MARK: - Singleton

    static let shared = ThemeManager()

    private init() {}

    // MARK: - UserDefaults Keys

    private let themeModeKey = "theme_mode"

    // MARK: - Persistence

    /// Load the saved theme preference from UserDefaults
    func loadThemePreference() -> ThemeMode {
        guard let savedMode = UserDefaults.standard.string(forKey: themeModeKey),
              let mode = ThemeMode(rawValue: savedMode) else {
            return .auto  // Default to auto mode
        }
        return mode
    }

    /// Save the theme preference to UserDefaults
    func saveThemePreference(_ mode: ThemeMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: themeModeKey)
    }

    // MARK: - System Appearance Detection

    /// Detect the current system appearance (light or dark)
    func detectSystemAppearance() -> ColorScheme {
        // Use the current trait collection to determine system appearance
        let style = UITraitCollection.current.userInterfaceStyle
        return style == .dark ? .dark : .light
    }

    /// Compute the effective color scheme based on theme mode
    func computeEffectiveScheme(for mode: ThemeMode) -> ColorScheme {
        switch mode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .auto:
            return detectSystemAppearance()
        }
    }

    // MARK: - Update Logic

    /// Update the app state if needed (e.g., when app becomes active)
    /// Only updates if in AUTO mode and system appearance has changed
    func updateIfNeeded(appState: AppState) {
        // Only update if in auto mode
        guard appState.currentTheme == .auto else { return }

        // Detect current system appearance
        let systemScheme = detectSystemAppearance()

        // Update if different from current effective scheme
        if appState.effectiveColorScheme != systemScheme {
            appState.effectiveColorScheme = systemScheme
        }
    }

    /// Apply a theme mode change immediately
    /// Updates both the theme preference and the effective color scheme
    func applyThemeChange(_ mode: ThemeMode, to appState: AppState) {
        // Save preference
        saveThemePreference(mode)

        // Update app state
        appState.currentTheme = mode

        // Compute and apply effective scheme
        let effectiveScheme = computeEffectiveScheme(for: mode)
        appState.effectiveColorScheme = effectiveScheme
    }
}
