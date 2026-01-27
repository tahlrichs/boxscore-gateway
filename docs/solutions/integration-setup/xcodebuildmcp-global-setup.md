---
title: Setting up XcodeBuildMCP globally for Claude Code iOS development
category: integration-setup
tags:
  - mcp
  - xcode
  - ios
  - claude-code
  - automation
  - homebrew
module: XcodeBuildMCP
symptoms:
  - Claude Code cannot discover or interact with iOS projects
  - XcodeBuildMCP tools not available in Claude Code
  - Unable to build, test, or run iOS simulators from Claude Code
date: 2026-01-26
linear_issue: BOX-13
---

# Setting up XcodeBuildMCP Globally for Claude Code

Enable Claude Code to build, test, and control iOS simulators for any Xcode project using XcodeBuildMCP.

## Problem

Claude Code couldn't interact with Xcode projects—no ability to discover projects, build apps, run tests, or control simulators. This limits the AI-assisted iOS development workflow.

## Root Cause

XcodeBuildMCP was not configured in Claude Code's global configuration file (`~/.claude.json`), preventing Claude from accessing iOS build, test, and simulator control capabilities.

## Solution

### Prerequisites

| Requirement | Minimum Version | Check Command |
|-------------|-----------------|---------------|
| Node.js | 18+ | `node --version` |
| macOS | 14.5+ | `sw_vers` |
| Xcode | 16+ | `xcodebuild -version` |

### Step 1: Install AXe (for UI Testing)

```bash
brew install cameroncooke/axe/axe
```

**Note:** Homebrew will prompt for your macOS password. This is normal—it needs sudo access.

Verify installation:
```bash
axe --version
```

### Step 2: Add XcodeBuildMCP to ~/.claude.json

Edit `~/.claude.json` and add to the root `mcpServers` object:

```json
{
  "mcpServers": {
    "XcodeBuildMCP": {
      "command": "npx",
      "args": ["-y", "xcodebuildmcp@latest"],
      "env": {
        "XCODEBUILDMCP_SENTRY_DISABLED": "true",
        "INCREMENTAL_BUILDS_ENABLED": "true"
      },
      "type": "stdio"
    }
  }
}
```

**Important:** Merge with existing `mcpServers` entries, don't replace them.

### Step 3: Restart Claude Code

Close and reopen VS Code completely (not just reload window).

### Step 4: Verify Setup

1. Run `/mcp` — should show XcodeBuildMCP in the list
2. Ask Claude: "What Xcode schemes are available?"
3. Ask Claude: "List available iOS simulators"
4. Ask Claude: "Build the app for iPhone 17 Pro simulator"

## Configuration Reference

| Setting | Value | Purpose |
|---------|-------|---------|
| `XCODEBUILDMCP_SENTRY_DISABLED` | `true` | Disables telemetry |
| `INCREMENTAL_BUILDS_ENABLED` | `true` | Faster rebuilds |
| Config location | `~/.claude.json` (root) | Global for all projects |

## Capabilities Unlocked

- **Project Discovery**: Auto-detects .xcodeproj and .xcworkspace files
- **Build Operations**: Build for macOS, iOS simulator, or iOS device
- **Test Execution**: Run unit tests and UI tests
- **Simulator Control**: Boot, list, and target specific simulators
- **Error Visibility**: Build errors appear in Claude's responses
- **Incremental Builds**: Only recompile changed files

## Prevention & Best Practices

### Check Prerequisites First

Always verify your environment before starting:
```bash
node --version      # Should be 18+
sw_vers             # Should show macOS 14.5+
xcodebuild -version # Should show Xcode 16+
```

### Root vs Project-Level Configuration

- **Root level** (`~/.claude.json`): Available to all projects (recommended)
- **Project level** (`.claude.json` in project): Project-specific overrides only

Use root level for XcodeBuildMCP. Don't duplicate across both files.

### Set Session Defaults

After setup, set defaults to speed up workflows:
```
Ask Claude: "Set session defaults for BoxScore project, BoxScore scheme, iPhone 17 Pro simulator"
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| MCP not showing in `/mcp` | Close VS Code completely, reopen (not just reload) |
| "npx not found" | Install Node.js 18+ |
| "AXe not found" | Run `brew install cameroncooke/axe/axe` with password |
| No simulators | In Xcode: Settings > Platforms > iOS, download runtime |
| Build fails "Scheme not found" | Verify you're in the correct project directory |

## References

- [XcodeBuildMCP GitHub](https://github.com/cameroncooke/XcodeBuildMCP)
- [XcodeBuildMCP Official Site](https://www.xcodebuildmcp.com/)
- [Setup Plan](../plans/2026-01-26-feat-xcodebuildmcp-global-setup-plan.md)
- Linear Issue: BOX-13
