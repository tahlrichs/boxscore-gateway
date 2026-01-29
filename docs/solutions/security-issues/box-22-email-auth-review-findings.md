---
title: "Email/Password Auth Code Review Findings"
date: 2026-01-28
category: security-issues
tags:
  - email-auth
  - password-auth
  - supabase
  - security
  - code-review
  - sql-security
  - error-handling
  - swiftui
module: Auth
linear_issue: BOX-22
symptoms:
  - "SQL search_path vulnerability on SECURITY DEFINER trigger function"
  - "COALESCE('') creates empty strings instead of NULL for missing first_name"
  - "Fragile string-based error matching on localizedDescription"
  - "isLoading not reset on successful authentication"
  - "Duplicate loading indicators (button spinner + full-screen overlay)"
  - "No character limit on firstName field"
---

# Email/Password Auth Code Review Findings

## Problem

After implementing email/password authentication (BOX-22), code review identified 6 issues across security, data consistency, error handling, UX, and input validation.

## Issues & Fixes

### 1. search_path Vulnerability (Security)

**File:** `gateway/src/db/migrations/004_profile_first_name_from_metadata.sql`

SECURITY DEFINER functions execute with owner privileges. Using `SET search_path = public` allows namespace shadowing attacks.

```sql
-- Before
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public;

-- After
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = '';
```

### 2. NULL vs Empty String (Data Consistency)

**File:** `gateway/src/db/migrations/004_profile_first_name_from_metadata.sql`

`COALESCE(->>'first_name', '')` converted NULL to empty string, creating two representations of "no name" (Apple/Google users have NULL, email users would get `''`).

```sql
-- Before
COALESCE(NEW.raw_user_meta_data->>'first_name', '')

-- After
NEW.raw_user_meta_data->>'first_name'  -- Returns NULL when key missing
```

### 3. Typed Error Handling (Reliability)

**File:** `XcodProject/BoxScore/BoxScore/Features/Auth/EmailAuthView.swift`

String matching on `error.localizedDescription` is brittle across SDK versions and locales. Use the typed `Auth.AuthError` with `errorCode`.

```swift
// Before
let message = error.localizedDescription.lowercased()
if message.contains("user_already_exists") { ... }

// After
import Auth

if let authError = error as? Auth.AuthError {
    switch authError.errorCode {
    case .userAlreadyExists, .emailExists: ...
    case .invalidCredentials: ...
    case .weakPassword: ...
    case .overRequestRateLimit, .overEmailSendRateLimit: ...
    default: break
    }
}
```

### 4. Loading State Reset (UX Bug)

**File:** `XcodProject/BoxScore/BoxScore/Features/Auth/EmailAuthView.swift`

`isLoading` was only set to `false` in the catch block. On success, the overlay persisted until view dismissal.

```swift
// Before
Task {
    do { ... }
    catch { isLoading = false }
}

// After
Task {
    defer { isLoading = false }
    do { ... }
    catch { errorMessage = mapError(error) }
}
```

### 5. Duplicate Loading Indicators (UX)

**File:** `XcodProject/BoxScore/BoxScore/Features/Auth/EmailAuthView.swift`

Both a button ProgressView and full-screen overlay showed simultaneously. Removed button spinner, kept overlay.

### 6. Name Length Cap (Input Validation)

**File:** `XcodProject/BoxScore/BoxScore/Features/Auth/EmailAuthView.swift`

firstName sent unbounded to Supabase metadata. Added trim + 40-char cap.

```swift
let trimmedName = String(firstName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
```

## Prevention

- Use typed error codes, not string matching, for SDK errors
- Use `defer` for cleanup in async Task blocks
- Always `SET search_path = ''` on SECURITY DEFINER functions
- Keep NULL/empty string consistent across all auth paths
- Cap user text input before sending to server
- One loading indicator per action

## Related

- [BOX-19 Auth Review Findings](../integration-issues/box-19-auth-review-findings.md)
- [Auth Foundation Code Review Cleanup](../code-quality-issues/auth-foundation-code-review-cleanup.md)
- [iOS Auth Review Cleanup](../code-quality-issues/ios-auth-review-cleanup.md)
- Linear: BOX-22, BOX-25 (deferred auth centralization refactor)
- Branch: `feat/box-22-email-password-auth`
