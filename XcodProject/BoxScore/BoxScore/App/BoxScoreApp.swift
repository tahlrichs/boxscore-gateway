//
//  BoxScoreApp.swift
//  BoxScore
//
//  Main entry point for the BoxScore app
//

import SwiftUI

@main
struct BoxScoreApp: App {

    @Environment(\.scenePhase) private var scenePhase
    private let appState = AppState.shared

    init() {
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
                .preferredColorScheme(appState.effectiveColorScheme)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    // Update theme when app becomes active (foreground)
                    // This ensures AUTO mode syncs with system settings
                    if newPhase == .active {
                        ThemeManager.shared.updateIfNeeded(appState: appState)
                    }
                }
        }
    }
}

