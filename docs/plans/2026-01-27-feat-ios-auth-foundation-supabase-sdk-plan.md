---
title: "iOS Auth Foundation: Supabase SDK, Profile Button, Login/Profile Screens"
type: feat
date: 2026-01-27
linear_issue: BOX-19
status: reviewed
---

# iOS Auth Foundation: Supabase SDK, Profile Button, Login/Profile Screens

## Overview

Integrate Supabase Swift SDK into the iOS app and create the authentication UI. The blue circle in the top right becomes a profile button that shows login state and opens the appropriate screen.

**Brainstorm:** [2026-01-27-user-authentication-brainstorm.md](../brainstorms/2026-01-27-user-authentication-brainstorm.md)
**Blocked by:** BOX-18 ✅ (Gateway auth foundation complete)
**Blocks:** BOX-20 (Apple), BOX-21 (Google), BOX-22 (Email)

## Problem Statement

BoxScore needs user accounts for favorite teams, push notifications, and cross-device sync. The gateway auth foundation (BOX-18) is complete — now the iOS app needs to integrate with Supabase Auth and provide login/profile UI.

## Proposed Solution

Use **Supabase Swift SDK** for authentication state management. The SDK handles:
- Session persistence (automatic Keychain storage)
- Token refresh (automatic)
- Auth state changes (observable)

```
User taps Profile Button
         ↓
  ┌──────┴──────┐
  ↓             ↓
[Guest]    [Logged In]
  ↓             ↓
Login      Profile
Screen     Screen
```

## Technical Approach

### Phase 1: Supabase SDK Setup

Add Supabase Swift SDK via Swift Package Manager.

**In Xcode:**
1. File → Add Package Dependencies
2. Enter: `https://github.com/supabase/supabase-swift`
3. Select version: `2.0.0` or later
4. Add `Auth` and `Supabase` products to BoxScore target

**Create configuration:**

```swift
// Core/Config/SupabaseConfig.swift

import Supabase

enum SupabaseConfig {
    private static let urlString = "https://your-project.supabase.co"
    private static let anonKey = "your-anon-key"

    static let client: SupabaseClient = {
        guard let url = URL(string: urlString) else {
            fatalError("Invalid Supabase URL: \(urlString). Check SupabaseConfig.swift")
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }()
}
```

> **Note:** For production, move credentials to a plist or xcconfig not checked into source control.

### Phase 2: User Model

Single source of truth for authenticated user data. Combines Supabase user info with profile data from gateway.

**File: `Core/Auth/AuthenticatedUser.swift`**

```swift
import Foundation

struct AuthenticatedUser: Equatable {
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
```

**File: `Core/Auth/ProfileResponse.swift`**

```swift
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
```

### Phase 3: AuthManager

Simplified `@Observable` AuthManager. No enum — just an optional user.

**File: `Core/Auth/AuthManager.swift`**

```swift
import Foundation
import Supabase

@Observable
class AuthManager {

    // MARK: - Singleton
    static let shared = AuthManager()

    // MARK: - State
    private(set) var user: AuthenticatedUser?
    private(set) var isLoading = false
    private(set) var error: AuthError?

    // MARK: - Computed
    var isLoggedIn: Bool { user != nil }

    // MARK: - Private
    private var authStateTask: Task<Void, Never>?
    private let cache = UserDefaults.standard
    private let cacheKey = "cachedAuthUser"

    // MARK: - Initialization
    private init() {
        loadCachedUser()
        listenToAuthChanges()
    }

    deinit {
        authStateTask?.cancel()
    }

    // MARK: - Auth State Listener
    private func listenToAuthChanges() {
        authStateTask = Task { [weak self] in
            for await (event, session) in SupabaseConfig.client.auth.authStateChanges {
                await self?.handleAuthChange(event: event, session: session)
            }
        }
    }

    @MainActor
    private func handleAuthChange(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .initialSession, .signedIn:
            guard session != nil else {
                user = nil
                clearCache()
                return
            }
            await loadUserProfile()

        case .signedOut:
            user = nil
            clearCache()

        case .tokenRefreshed:
            // Token refreshed automatically by SDK - nothing to do
            break

        default:
            break
        }
    }

    // MARK: - Profile Loading
    @MainActor
    func loadUserProfile() async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            let response = try await fetchMe()
            user = response.toAuthenticatedUser()
            cacheUser(user)
        } catch let networkError as NetworkError {
            handleNetworkError(networkError)
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
    }

    private func fetchMe() async throws -> MeResponse {
        guard let token = try? await SupabaseConfig.client.auth.session.accessToken else {
            throw AuthError.notAuthenticated
        }
        return try await GatewayClient.shared.fetchMe(token: token)
    }

    @MainActor
    private func handleNetworkError(_ error: NetworkError) {
        switch error {
        case .httpError(let statusCode, _) where statusCode == 401:
            // Token invalid/expired and refresh failed - sign out
            Task { await signOut() }
        case .httpError(let statusCode, _) where statusCode == 403:
            self.error = .forbidden
        case .noConnection:
            // Offline - keep cached user, show offline indicator
            self.error = .offline
        default:
            self.error = .networkError(error.localizedDescription)
        }
    }

    // MARK: - Sign Out
    @MainActor
    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await SupabaseConfig.client.auth.signOut()
            // State change handled by listener
        } catch {
            // Sign out locally even if network fails
            user = nil
            clearCache()
        }
    }

    // MARK: - Delete Account
    @MainActor
    func deleteAccount() async throws {
        isLoading = true
        defer { isLoading = false }

        guard let token = try? await SupabaseConfig.client.auth.session.accessToken else {
            throw AuthError.notAuthenticated
        }

        // Call gateway to delete account (which calls Supabase admin API)
        try await GatewayClient.shared.deleteAccount(token: token)

        // Clear local state
        user = nil
        clearCache()
    }

    // MARK: - Caching (for instant profile display)
    private func loadCachedUser() {
        guard let data = cache.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(AuthenticatedUser.self, from: data) else {
            return
        }
        user = cached
    }

    private func cacheUser(_ user: AuthenticatedUser?) {
        guard let user = user,
              let data = try? JSONEncoder().encode(user) else {
            clearCache()
            return
        }
        cache.set(data, forKey: cacheKey)
    }

    private func clearCache() {
        cache.removeObject(forKey: cacheKey)
    }
}

// MARK: - Auth Errors
enum AuthError: Error, Equatable {
    case notAuthenticated
    case forbidden
    case offline
    case networkError(String)
    case deletionFailed(String)
    case unknown(String)

    var userMessage: String {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue."
        case .forbidden:
            return "You don't have permission to do that."
        case .offline:
            return "You're offline. Some features may be unavailable."
        case .networkError:
            return "Something went wrong. Please try again."
        case .deletionFailed:
            return "Could not delete account. Please try again."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

// Make AuthenticatedUser Codable for caching
extension AuthenticatedUser: Codable {}
```

**Key changes from original plan:**
- No `AuthState` enum — just `user: AuthenticatedUser?`
- Single `AuthenticatedUser` model (no separate Profile + User)
- `initial` computed property in one place
- Token read directly from Supabase SDK (no copying to AppConfig)
- Profile caching for instant display
- Proper 401/403 handling with user-friendly errors
- Task cancellation in deinit
- `deleteAccount()` method implemented

### Phase 4: GatewayClient Updates

**File: `Core/Networking/GatewayClient.swift`** (add methods)

```swift
/// Fetch current user profile
/// - Parameter token: Supabase access token
func fetchMe(token: String) async throws -> MeResponse {
    var request = URLRequest(url: baseURL.appendingPathComponent("/v1/auth/me"))
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    return try await performRequest(request)
}

/// Delete current user's account
/// - Parameter token: Supabase access token
func deleteAccount(token: String) async throws {
    var request = URLRequest(url: baseURL.appendingPathComponent("/v1/auth/me"))
    request.httpMethod = "DELETE"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (_, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw NetworkError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500, data: nil)
    }
}
```

**Note:** This passes the token directly rather than reading from AppConfig. No more UserDefaults for tokens.

### Phase 5: Gateway Delete Endpoint

The gateway needs a DELETE endpoint. Add to BOX-18 scope or create follow-up.

**File: `gateway/src/routes/auth.ts`** (add)

```typescript
/**
 * DELETE /v1/auth/me
 * Delete current user's account
 */
router.delete('/me', requireAuth, async (req: Request, res: Response, next: NextFunction) => {
  try {
    const userId = req.user!.id;

    // Delete profile first (cascade should handle this, but be explicit)
    await pool.query('DELETE FROM profiles WHERE id = $1', [userId]);

    // Delete from Supabase Auth using service role
    const { error } = await supabaseAdmin.auth.admin.deleteUser(userId);

    if (error) {
      throw new Error(`Failed to delete user: ${error.message}`);
    }

    res.status(204).send();
  } catch (error) {
    next(error);
  }
});
```

### Phase 6: Profile Button

Simplified to two visual states (guest / logged in). No loading state flash.

**File: `Components/Navigation/ProfileButton.swift`**

```swift
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
```

**Update `TopNavBar.swift`:**

```swift
// Replace lines 37-45 with:
ProfileButton {
    onProfileTap?()
}
```

### Phase 7: Login Screen

No generic SignInButton — each provider will use its official button (Apple HIG, Google branding).

**File: `Features/Auth/LoginView.swift`**

```swift
import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Header
                VStack(spacing: 12) {
                    Image(systemName: "sportscourt.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.blue)

                    Text("BoxScore")
                        .font(.largeTitle.bold())

                    Text("Sign in to save your favorite teams\nand sync across devices")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Sign-in buttons
                VStack(spacing: 12) {
                    // Apple Sign In - uses official Apple button (BOX-20)
                    appleSignInButton

                    // Google Sign In - uses official Google button (BOX-21)
                    googleSignInButton

                    // Divider
                    HStack {
                        Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                        Text("or")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                    }
                    .padding(.vertical, 8)

                    // Email Sign In (BOX-22)
                    emailSignInButton
                }
                .padding(.horizontal, 24)

                Spacer()

                // Continue as Guest
                Button("Continue as Guest") {
                    dismiss()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 32)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Sign In Buttons

    private var appleSignInButton: some View {
        // Placeholder - BOX-20 will replace with ASAuthorizationAppleIDButton
        Button {
            // Wired in BOX-20
        } label: {
            HStack {
                Image(systemName: "apple.logo")
                Text("Sign in with Apple")
            }
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.black)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var googleSignInButton: some View {
        // Placeholder - BOX-21 will replace with official Google button
        Button {
            // Wired in BOX-21
        } label: {
            HStack {
                Image(systemName: "g.circle.fill")
                Text("Sign in with Google")
            }
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(.systemGray6))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var emailSignInButton: some View {
        // Placeholder - BOX-22 will navigate to email form
        Button {
            // Wired in BOX-22
        } label: {
            HStack {
                Image(systemName: "envelope.fill")
                Text("Sign in with Email")
            }
            .font(.body.weight(.medium))
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(.systemGray6))
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
```

### Phase 8: Profile Screen

With functional Delete Account.

**File: `Features/Auth/ProfileView.swift`**

```swift
import SwiftUI

struct ProfileView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.dismiss) private var dismiss

    @State private var showSignOutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
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
                if isDeleting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Deleting account...")
                                .padding()
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        }
                }
            }
        }
    }

    private func deleteAccount() {
        isDeleting = true

        Task {
            do {
                try await authManager.deleteAccount()
                dismiss()
            } catch {
                deleteError = "Something went wrong. Please try again."
            }
            isDeleting = false
        }
    }
}
```

### Phase 9: Navigation Integration

**File: `Features/Home/HomeView.swift`** (modify)

```swift
// Add state
@State private var showAuthSheet = false
@Environment(AuthManager.self) private var authManager

// Update TopNavBar
TopNavBar(
    onMenuTap: { showMenu = true },
    onProfileTap: { showAuthSheet = true }
)

// Add sheet modifier
.sheet(isPresented: $showAuthSheet) {
    if authManager.isLoggedIn {
        ProfileView()
    } else {
        LoginView()
    }
}
```

**File: `App/BoxScoreApp.swift`** (modify)

```swift
@State private var authManager = AuthManager.shared

var body: some Scene {
    WindowGroup {
        HomeView()
            .environment(appState)
            .environment(authManager)
            .preferredColorScheme(preferredScheme)
    }
}
```

### Phase 10: JSON Decoder Configuration

Set snake_case conversion globally to eliminate CodingKeys boilerplate.

**File: `Core/Networking/GatewayClient.swift`** (update decoder)

```swift
private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()
```

## Acceptance Criteria

### Supabase SDK
- [ ] Supabase Swift SDK added via SPM (manual step in Xcode)
- [x] SupabaseClient configured with guard (no force-unwrap)

### AuthManager
- [x] `user: AuthenticatedUser?` — nil means guest
- [x] `isLoggedIn` computed property
- [x] Token read directly from Supabase SDK (not copied to UserDefaults)
- [x] Auth state changes handled via `authStateChanges` listener
- [x] Profile cached for instant display
- [x] 401 errors trigger sign out
- [x] Task cancelled in deinit
- [x] `signOut()` works even if network fails
- [x] `deleteAccount()` fully functional

### Profile Button
- [x] Shows person icon when guest
- [x] Shows initial when logged in (single implementation in `AuthenticatedUser.initial`)
- [x] Tap opens Login sheet when guest
- [x] Tap opens Profile sheet when logged in
- [x] Accessibility labels correct

### Login Screen
- [x] Presented as sheet
- [x] App branding (icon + name + description)
- [x] Apple Sign In button placeholder (BOX-20)
- [x] Google Sign In button placeholder (BOX-21)
- [x] Email Sign In button placeholder (BOX-22)
- [x] "Continue as Guest" dismisses sheet
- [x] X button dismisses sheet

### Profile Screen
- [x] Shows avatar with initial
- [x] Shows first name and email
- [x] Shows favorite teams (or empty state)
- [x] Sign Out with confirmation → dismisses sheet
- [x] Delete Account with confirmation → deletes and dismisses
- [x] Loading overlay during deletion
- [x] Error alert if deletion fails

### Guest Mode
- [x] App works fully without login
- [x] AuthManager handles nil user gracefully

## Files to Create/Modify

| File | Action |
|------|--------|
| `Core/Config/SupabaseConfig.swift` | Create |
| `Core/Auth/AuthenticatedUser.swift` | Create |
| `Core/Auth/ProfileResponse.swift` | Create |
| `Core/Auth/AuthManager.swift` | Create |
| `Components/Navigation/ProfileButton.swift` | Create |
| `Features/Auth/LoginView.swift` | Create |
| `Features/Auth/ProfileView.swift` | Create |
| `Components/Navigation/TopNavBar.swift` | Modify |
| `Features/Home/HomeView.swift` | Modify |
| `App/BoxScoreApp.swift` | Modify |
| `Core/Networking/GatewayClient.swift` | Modify |
| `gateway/src/routes/auth.ts` | Modify (add DELETE) |
| `BoxScore.xcodeproj` | Modify (SPM) |

## Review Feedback Applied

| Issue | Resolution |
|-------|------------|
| Auth token in UserDefaults | Token read directly from Supabase SDK |
| Task cancellation | Added deinit with cancel() |
| AuthState enum over-engineered | Simplified to `user: AuthenticatedUser?` |
| Dual profile storage | Single `AuthenticatedUser` model |
| Initials duplicated | Computed property on `AuthenticatedUser` |
| SignInButton premature | Removed; inline buttons for each provider |
| Race condition | Using `authStateChanges` with `.initialSession` |
| Missing 401 handling | Added with sign-out on invalid token |
| Force-unwrap config | Guard with fatalError |
| Delete Account placeholder | Fully implemented |

## Dependencies

- **Requires:** Supabase Swift SDK 2.0+
- **Requires:** BOX-18 complete (gateway auth middleware)
- **Requires:** Gateway DELETE /v1/auth/me endpoint
- **Blocks:** BOX-20, BOX-21, BOX-22 (sign-in button actions)

## References

- **Brainstorm:** [../brainstorms/2026-01-27-user-authentication-brainstorm.md](../brainstorms/2026-01-27-user-authentication-brainstorm.md)
- **BOX-18 Plan:** [./2026-01-27-feat-supabase-auth-foundation-plan.md](./2026-01-27-feat-supabase-auth-foundation-plan.md)
- **Supabase Swift SDK:** https://github.com/supabase/supabase-swift
- **Supabase Auth iOS Guide:** https://supabase.com/docs/guides/auth/quickstarts/swift
