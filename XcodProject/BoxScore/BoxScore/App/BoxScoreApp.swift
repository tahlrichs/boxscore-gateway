//
//  BoxScoreApp.swift
//  BoxScore
//
//  Main entry point for the BoxScore app
//

import SwiftUI

@main
struct BoxScoreApp: App {

    @State private var appState = AppState.shared
    @Environment(\.colorScheme) private var systemColorScheme

    init() {
        // Validate custom fonts in debug builds
        #if DEBUG
        Theme.validateFonts()
        #endif

        // Perform gateway health check on startup
        Task {
            let isHealthy = await HealthCheckManager.shared.checkHealth()
            if !isHealthy {
                print("⚠️ Gateway health check failed on startup")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(appState)
                .preferredColorScheme(preferredScheme)
                .onChange(of: systemColorScheme) { _, newScheme in
                    appState.systemColorScheme = newScheme
                }
                .onAppear {
                    appState.systemColorScheme = systemColorScheme
                }
        }
    }

    /// The color scheme to apply based on user preference
    private var preferredScheme: ColorScheme? {
        switch appState.themeMode {
        case .light: return .light
        case .dark: return .dark
        case .auto: return nil  // Follow system
        }
    }
}

