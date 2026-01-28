//
//  ProfileButton.swift
//  BoxScore
//
//  Profile button showing auth state - person icon when guest, initial when logged in
//

import SwiftUI

struct ProfileButton: View {
    @Environment(AuthManager.self) private var authManager
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Circle()
                .fill(Color.blue)
                .frame(width: 32, height: 32)
                .overlay {
                    if let user = authManager.user {
                        Text(user.initial)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    } else {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white)
                            .font(.system(size: 14))
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(authManager.isLoggedIn ? "Your profile" : "Sign in")
    }
}
