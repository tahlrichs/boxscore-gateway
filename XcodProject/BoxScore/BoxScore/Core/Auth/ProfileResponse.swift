//
//  ProfileResponse.swift
//  BoxScore
//
//  Response types for gateway auth endpoints
//

import Foundation

/// Response from GET /v1/auth/me
struct MeResponse: Codable {
    let user: UserInfo
    let profile: ProfileData?

    struct UserInfo: Codable {
        let id: String
        let email: String?
    }

    struct ProfileData: Codable {
        let firstName: String?
        let favoriteTeams: [String]
    }

    /// Convert to our unified user model
    func toAuthenticatedUser() -> AuthenticatedUser {
        AuthenticatedUser(
            id: user.id,
            email: user.email,
            firstName: profile?.firstName,
            favoriteTeams: profile?.favoriteTeams ?? []
        )
    }
}
