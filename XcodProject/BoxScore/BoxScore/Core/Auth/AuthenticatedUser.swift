//
//  AuthenticatedUser.swift
//  BoxScore
//
//  Unified model for authenticated user data
//

import Foundation

struct AuthenticatedUser: Equatable, Codable {
    let id: String
    let email: String?
    var firstName: String?
    var favoriteTeams: [String]

    /// Single initial for avatar display
    var initial: String {
        if let first = firstName?.trimmingCharacters(in: .whitespaces).first {
            return String(first).uppercased()
        }
        if let first = email?.first {
            return String(first).uppercased()
        }
        return "?"
    }
}
