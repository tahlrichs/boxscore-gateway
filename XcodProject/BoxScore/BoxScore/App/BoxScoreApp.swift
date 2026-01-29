//
//  BoxScoreApp.swift
//  BoxScore
//
//  Main entry point for the BoxScore app
//

import GoogleSignIn
import SwiftUI

@main
struct BoxScoreApp: App {

    @State private var appState = AppState.shared
    @State private var authManager = AuthManager.shared
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
                .environment(authManager)
                .preferredColorScheme(preferredScheme)
                .onChange(of: systemColorScheme) { _, newScheme in
                    // Update effective scheme when system changes (for auto mode)
                    ThemeManager.shared.updateIfNeeded(appState: appState)
                }
                .onAppear {
                    // Initial update for auto mode
                    ThemeManager.shared.updateIfNeeded(appState: appState)
                }
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }

    /// The color scheme to apply based on user preference
    private var preferredScheme: ColorScheme? {
        switch appState.currentTheme {
        case .light: return .light
        case .dark: return .dark
        case .auto: return nil  // Follow system
        }
    }
}
