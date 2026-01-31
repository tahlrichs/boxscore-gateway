---
title: "Gateway Response Double Data Unwrap Bug"
category: "integration-issues"
tags: ["gateway-integration", "data-modeling", "iOS-networking", "decoder-pattern", "type-safety"]
module: "PlayerProfileView (iOS) + GatewayClient"
symptoms: ["RuntimeError: Cannot decode nested data structure", "Missing stat data in player profile", "App crash when loading player statistics"]
severity: "P1"
date_resolved: "2026-01-31"
linear: "BOX-39"
---

## Problem

The iOS PlayerProfileView stat central redesign created an unintentional double data unwrap that would cause a runtime crash when fetching player statistics.

**The Issue:**
- The `GatewayClient.fetch()` method automatically decodes responses as `GatewayResponse<T>` and unwraps the `data` field in the response body
- We defined `StatCentralResponse` with its own `data: StatCentralData` field, creating a double-nesting pattern
- This caused the decoder to expect `{ "data": { "data": { ... } } }` which never matched the actual gateway response format: `{ "data": { ... } }`

**Example of the mismatch:**

Gateway returns:
```json
{
  "data": {
    "seasons": [...],
    "player": {...}
  }
}
```

But the model was:
```swift
struct StatCentralResponse: Decodable {
  let data: StatCentralData  // ❌ Creates second unwrap
}

struct StatCentralData: Decodable {
  let seasons: [Season]
  let player: Player
}
```

So when `GatewayClient` unwrapped the outer `data`, it tried to decode `StatCentralData` which was missing its own `data` wrapper, causing a decode failure that would crash the app at runtime.

---

## Root Cause

This pattern emerged because:

1. **Inconsistent response handling assumption**: The developer assumed the gateway wraps all responses with a `data` field at two levels (gateway wrapper + endpoint-specific wrapper)
2. **Deviation from established patterns**: All other endpoints in the codebase (games, boxscores, etc.) decode directly to their model type without an intermediate response wrapper
3. **Lack of awareness of GatewayClient behavior**: The `fetch()` method's automatic `data` unwrapping wasn't clearly understood when designing the new model
4. **No compile-time validation**: Swift's Decodable protocol doesn't prevent double-wrapping patterns; it only fails at runtime when the JSON structure doesn't match

**Why this is dangerous:**
- The bug would only surface when the endpoint is called in production—not during local development if using mock data
- It's a silent pattern error that could recur whenever someone adds a new endpoint without reviewing how `GatewayClient` works

---

## Solution

**Removed the intermediate `StatCentralResponse` wrapper entirely.**

Before:
```swift
// ❌ WRONG - Creates double unwrap
struct StatCentralResponse: Decodable {
  let data: StatCentralData
}

struct StatCentralData: Decodable {
  let seasons: [Season]
  let player: Player
}

// In ViewModel
let response: GatewayResponse<StatCentralResponse> = try await client.fetch(...)
let data = response.data.data  // ❌ Double unwrap
```

After:
```swift
// ✅ CORRECT - Decode directly as the data model
struct StatCentralData: Decodable {
  let seasons: [Season]
  let player: Player
}

// In ViewModel
let response: GatewayResponse<StatCentralData> = try await client.fetch(...)
let data = response.data  // ✅ Single unwrap, matches gateway behavior
```

This aligns with how other endpoints are decoded in the codebase (e.g., `GatewayResponse<[Game]>`, `GatewayResponse<BoxScore>`).

---

## Prevention

**For future endpoint integrations:**

1. **Review GatewayClient's behavior first**: Understand that `fetch()` automatically unwraps the `data` field from the gateway response. Your model should represent the *content* of that `data` field, not wrap it again.

2. **Follow the established pattern in the codebase**: Look at existing endpoints like:
   - `scoreboard.ts` → decoded as `GatewayResponse<[Game]>` directly
   - `boxscore.ts` → decoded as `GatewayResponse<BoxScore>` directly
   - NOT as `GatewayResponse<BoxScoreResponse<BoxScore>>`

3. **Test with real gateway responses early**: If possible, test decoding against actual JSON from the gateway rather than relying only on mock data. This catches struct/JSON mismatches before code review.

4. **Add a checklist comment in model files**:
   ```swift
   // Decoding checklist:
   // [ ] Does GatewayClient.fetch() auto-unwrap the "data" field?
   // [ ] Is this model designed to represent the CONTENT of "data", not wrap it?
   // [ ] Did I check similar endpoints (Games, BoxScore) for the pattern?
   ```

5. **Code review gate**: When reviewing new endpoints, explicitly check the GatewayClient integration and ask: "Why is this wrapper needed? Is it matching the pattern used elsewhere?"

---

## Secondary Learnings

### P2 - Observable Pattern Mismatch
**Finding:** The ViewModel used `ObservableObject + @Published + @StateObject` (pre-iOS 17 pattern) while the entire codebase uses `@Observable + @State` (iOS 17+ convention as stated in CLAUDE.md).

**Impact:** Medium — inconsistent patterns make the codebase harder to maintain.

**Fix:** Converted to `@Observable` with `@State` properties, matching the established convention.

### P3 - Over-Complicated View Logic
**Findings:**
- `visibleSeasons` filter used a redundant `hasTrades` helper when the data contract guarantees TOTAL rows have `teamAbbreviation == nil`
- `isRookie` check was redundant with `hasMoreSeasons` logic
- GP==0 check was performed 4 times in the view instead of once in the ViewModel
- Complex conditional logic could have been simplified to 2-3 boolean properties

**Impact:** Low severity — functional but maintainability concern.

**Fix:** Moved all computed logic to ViewModel, exposing clean boolean flags to the view. Simplified from ~40 lines of conditional logic in the view to 3-4 data bindings.

---

## Related

- **GatewayClient.swift** - The `fetch()` method and how it unwraps `GatewayResponse<T>`
- **scoreboard.ts** - Reference implementation of proper gateway response handling
- **boxscore.ts** - Another reference implementation
- **CLAUDE.md** - Project conventions for iOS 17+ observability patterns
- **PlayerProfileView.swift** - The affected view component
- **HomeViewModel.swift** - Reference for correct @Observable usage

---

## Takeaway

**The most reusable lesson:** Whenever adding a new endpoint to the iOS app, the question to ask is: "Does my model struct wrap the gateway's `data` field, or does it represent its content?" If it wraps, you'll get a double-unwrap bug. The `GatewayClient` already handles one unwrap, so your model should go straight to the content.

This is a low-level but high-impact pattern that's easy to miss if you're not familiar with the gateway architecture.
