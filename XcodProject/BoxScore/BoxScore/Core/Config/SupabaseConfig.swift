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
    private static let anonKey = "sb_publishable_CrEAszdMawIT1if8-QEobw_c1tMv5ez"

    static let client: SupabaseClient = {
        guard let url = URL(string: urlString) else {
            fatalError("Invalid Supabase URL: \(urlString). Check SupabaseConfig.swift")
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }()
}
