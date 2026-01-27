---
title: Set Up XcodeBuildMCP Globally
type: feat
date: 2026-01-26
linear_issue: BOX-13
---

# Set Up XcodeBuildMCP Globally

Install and configure XcodeBuildMCP so Claude Code can build, test, and control iOS simulators for any Xcode project.

## Acceptance Criteria

- [x] XcodeBuildMCP appears when running `/mcp` in Claude Code
- [x] Works from any directory (globally configured)
- [x] Can discover Xcode projects and schemes
- [x] Can build apps for simulator
- [x] Can run unit tests
- [x] Can run UI tests (AXe installed)
- [x] Build errors are visible in Claude's responses
- [x] Survives VS Code restart

## Prerequisites

Before setup, verify these are installed:

| Requirement | Minimum Version | Check Command |
|-------------|-----------------|---------------|
| Node.js | 18+ | `node --version` |
| macOS | 14.5+ | `sw_vers` |
| Xcode | 16+ | `xcodebuild -version` |

## Setup Steps

### 1. Install AXe (for UI Testing)

```bash
brew install cameroncooke/axe/axe
```

### 2. Add XcodeBuildMCP to Claude Code

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

**Note:** Merge with existing `mcpServers` entries (like "pencil"), don't replace them.

### 3. Restart Claude Code

Close and reopen VS Code, or run the "Developer: Reload Window" command.

### 4. Verify Setup

1. Run `/mcp` — should show XcodeBuildMCP in the list
2. Open BoxScore project
3. Ask Claude: "What Xcode schemes are available?"
4. Ask Claude: "Build the BoxScore app for iPhone 17 Pro simulator"

## Configuration Details

| Setting | Value | Purpose |
|---------|-------|---------|
| `XCODEBUILDMCP_SENTRY_DISABLED` | `true` | Disables telemetry |
| `INCREMENTAL_BUILDS_ENABLED` | `true` | Faster rebuilds |
| Config location | `~/.claude.json` (root level) | Makes it global for all projects |

## Capabilities Enabled

- **Project Discovery**: Auto-detects .xcodeproj and .xcworkspace files
- **Build Operations**: Build for macOS, iOS simulator, or iOS device
- **Test Execution**: Run unit tests and UI tests
- **Simulator Control**: Boot, list, and target specific simulators
- **Error Visibility**: Build errors appear in Claude's responses
- **Incremental Builds**: Only recompile changed files

## Troubleshooting

| Issue | Solution |
|-------|----------|
| MCP not showing in `/mcp` | Restart VS Code completely (not just reload) |
| "npx not found" | Install Node.js 18+ |
| Build fails with no simulators | Install simulators in Xcode > Settings > Platforms |
| UI tests fail | Verify AXe installed: `axe --version` |

## References

- [XcodeBuildMCP GitHub](https://github.com/cameroncooke/XcodeBuildMCP)
- [XcodeBuildMCP Official Site](https://www.xcodebuildmcp.com/)
- Linear Issue: BOX-13
