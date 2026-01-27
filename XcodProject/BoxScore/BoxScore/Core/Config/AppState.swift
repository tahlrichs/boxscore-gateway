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

    /// User's selected theme mode
    var themeMode: ThemeMode {
        didSet {
            // Persist preference
            UserDefaults.standard.set(themeMode.rawValue, forKey: "themeMode")
        }
    }

    /// The effective color scheme based on user preference
    var effectiveColorScheme: ColorScheme {
        switch themeMode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .auto:
            // Return current system setting (will be updated by environment)
            return systemColorScheme
        }
    }

    /// Track system color scheme for auto mode
    var systemColorScheme: ColorScheme = .light

    // MARK: - Initialization

    private init() {
        // Load saved preference
        if let saved = UserDefaults.standard.string(forKey: "themeMode"),
           let mode = ThemeMode(rawValue: saved) {
            self.themeMode = mode
        } else {
            self.themeMode = .auto
        }
    }

    // MARK: - Actions

    /// Toggle between light and dark (skips auto)
    func toggleDarkMode() {
        switch themeMode {
        case .light:
            themeMode = .dark
        case .dark:
            themeMode = .light
        case .auto:
            // If auto, switch to opposite of current system
            themeMode = systemColorScheme == .dark ? .light : .dark
        }
    }

    /// Cycle through all modes: auto -> light -> dark -> auto
    func cycleThemeMode() {
        switch themeMode {
        case .auto:
            themeMode = .light
        case .light:
            themeMode = .dark
        case .dark:
            themeMode = .auto
        }
    }
}
