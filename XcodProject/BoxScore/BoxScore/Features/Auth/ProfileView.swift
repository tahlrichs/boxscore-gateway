//
//  ProfileView.swift
//  BoxScore
//
//  Profile screen showing user info with sign out and delete account
//

import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var showSignOutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var deleteError: String?

    var body: some View {
        NavigationStack {
            List {
                // User Info Section
                Section {
                    HStack(spacing: 16) {
                        // Avatar
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 60, height: 60)
                            .overlay {
                                Text(authManager.user?.initial ?? "?")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            if let name = authManager.user?.firstName {
                                Text(name)
                                    .font(.headline)
                            }
                            if let email = authManager.user?.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                }

                // Favorite Teams Section
                Section("Favorite Teams") {
                    if let teams = authManager.user?.favoriteTeams, !teams.isEmpty {
                        ForEach(teams, id: \.self) { teamId in
                            Text(teamId) // TODO: Resolve to team name in future ticket
                        }
                    } else {
                        Text("No favorite teams yet")
                            .foregroundStyle(.secondary)
                    }
                }

                // Account Section
                Section {
                    Button("Sign Out") {
                        showSignOutConfirmation = true
                    }

                    Button("Delete Account", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            // Sign Out Confirmation
            .confirmationDialog(
                "Sign Out",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authManager.signOut()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to sign out?")
            }
            // Delete Account Confirmation
            .confirmationDialog(
                "Delete Account",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    deleteAccount()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all your data. This cannot be undone.")
            }
            // Delete Error Alert
            .alert("Could Not Delete Account", isPresented: .init(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )) {
                Button("OK") { deleteError = nil }
            } message: {
                Text(deleteError ?? "Please try again.")
            }
            // Loading Overlay
            .overlay {
                if authManager.isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView()
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                }
            }
        }
    }

    private func deleteAccount() {
        Task {
            do {
                try await authManager.deleteAccount()
                dismiss()
            } catch {
                deleteError = "Something went wrong. Please try again."
            }
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthManager.shared)
}
