//
//  SupabaseConfig.swift
//  BoxScore
//
//  Supabase client configuration
//

import Foundation
import Supabase

enum SupabaseConfig {
    // TODO: Move to xcconfig or plist not checked into source control for production
    private static let urlString = "https://ssbphvkxsxajygivommq.supabase.co"
    private static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNzYnBodmt4c3hhanlnaXZvbW1xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg2NTUwNDAsImV4cCI6MjA4NDIzMTA0MH0.4h_JZELMJkszhX2vk8GrkK1BDoL6b89sJIARisM0rhA"

    static let client: SupabaseClient = {
        guard let url = URL(string: urlString) else {
            fatalError("Invalid Supabase URL: \(urlString). Check SupabaseConfig.swift")
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }()
}
