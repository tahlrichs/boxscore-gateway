//
//  BoxScoreApp.swift
//  BoxScore
//
//  Main entry point for the BoxScore app
//

import SwiftUI

@main
struct BoxScoreApp: App {

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
        }
    }
}

