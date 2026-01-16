# Obsidian Playwright MCP - Skill Guide

## Overview

This is an **MCP (Model Context Protocol) server** that enables AI coding assistants to **automate and debug Obsidian** using Playwright. It connects to Obsidian via Chrome DevTools Protocol (CDP) and provides tools for:

- 📸 Taking screenshots
- 🖥️ Executing JavaScript in Obsidian's renderer process
- 📋 Capturing console logs (errors, warnings, debug output)
- 📂 Getting vault and active file information

## Architecture

```
┌─────────────────────┐     CDP (port 8315)     ┌─────────────────┐
│  AI Coding Agent    │ ◄──────────────────────► │    Obsidian     │
│  (Claude/Gemini)    │                          │  (Electron App) │
└─────────────────────┘                          └─────────────────┘
          │                                               ▲
          │ MCP Protocol (stdio)                          │
          ▼                                               │
┌─────────────────────┐     Playwright CDP       ─────────┘
│  obsidian-mcp-server│ ────────────────────────►
│  (Node.js)          │
└─────────────────────┘
```

## Prerequisites

1. **Obsidian** installed at: `C:\Users\patri\AppData\Local\Programs\Obsidian\Obsidian.exe`
2. **Node.js** (v18+ recommended)
3. Dependencies installed: `npm install`

## Quick Start

### Step 1: Launch Obsidian with Debug Port

Run the PowerShell script to start Obsidian with remote debugging enabled:

```powershell
# From project directory
"C:\Projects\02-Active-Development\obsidian-playwright-mcp\launch-obsidian-debug.ps1"
```

Or manually:

```powershell
# Kill existing Obsidian instances and restart with debug port
Get-Process -Name "Obsidian" -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2
Start-Process "C:\Users\patri\AppData\Local\Programs\Obsidian\Obsidian.exe" -ArgumentList "--remote-debugging-port=8315"
```

### Step 2: Verify Connection (Optional)

Test the connection manually:

```powershell
node test-obsidian.js
```

Expected output:
```
Make sure Obsidian is running with: --remote-debugging-port=8315
Connecting to Obsidian...
Found 1 context(s)
Window title: Home - ObsidianDev - Obsidian v1.x.x
Screenshot saved!
Vault name: ObsidianDev
Connected! Press Ctrl+C to exit.
```

### Step 3: Configure MCP in Your AI Agent

Add to your MCP config (e.g., `.gemini/antigravity/mcp_config.json` or `.claude/mcp_config.json`):

```json
{
  "mcpServers": {
    "obsidian-automation": {
      "command": "node",
      "args": ["C:/Projects/02-Active-Development/obsidian-playwright-mcp/obsidian-mcp-server.js"]
    }
  }
}
```

## Available MCP Tools

| Tool | Description | Arguments |
|------|-------------|-----------|
| `connect_to_obsidian` | Connect to Obsidian (must run first) | None |
| `take_screenshot` | Capture Obsidian window | `filename` (optional) |
| `execute_in_renderer` | Run JavaScript in Obsidian | `code` (required) |
| `get_console_logs` | Get captured console output | `filter`, `limit` |
| `get_page_info` | Get vault/file info | None |
| `disconnect` | Close the connection | None |

## Usage Examples

### Connect and Take Screenshot

```javascript
// First, connect
mcp_obsidian-automation_connect_to_obsidian()
// Returns: { success: true, title: "Home - ObsidianDev", vaultName: "ObsidianDev" }

// Take a screenshot
mcp_obsidian-automation_take_screenshot({ filename: "debug-state.png" })
// Returns: { success: true, path: "C:/Projects/.../screenshots/debug-state.png" }
```

### Execute Code in Obsidian

```javascript
// Get active file path
mcp_obsidian-automation_execute_in_renderer({
  code: `app.workspace.getActiveFile()?.path`
})
// Returns: { success: true, result: "Notes/My Note.md" }

// Open a specific file
mcp_obsidian-automation_execute_in_renderer({
  code: `app.workspace.openLinkText('Home.md', '/', false)`
})

// Check plugin state
mcp_obsidian-automation_execute_in_renderer({
  code: `Object.keys(app.plugins.plugins)`
})
// Returns: { success: true, result: ["obsidian-spaced-reading", "dataview", ...] }
```

### Capture Console Logs

```javascript
// Get recent errors
mcp_obsidian-automation_get_console_logs({ filter: "error", limit: 10 })

// Search for specific text
mcp_obsidian-automation_get_console_logs({ filter: "plugin", limit: 50 })
```

## Debugging Obsidian Plugins

### Workflow: Debug a Plugin Issue

1. **Connect to Obsidian**
   ```
   mcp_obsidian-automation_connect_to_obsidian()
   ```

2. **Take initial screenshot**
   ```
   mcp_obsidian-automation_take_screenshot({ filename: "before-action.png" })
   ```

3. **Trigger the plugin action** via `execute_in_renderer`:
   ```javascript
   mcp_obsidian-automation_execute_in_renderer({
     code: `app.commands.executeCommandById('spaced-reading:next-item')`
   })
   ```

4. **Check for errors**
   ```
   mcp_obsidian-automation_get_console_logs({ filter: "error" })
   ```

5. **Take after screenshot**
   ```
   mcp_obsidian-automation_take_screenshot({ filename: "after-action.png" })
   ```

6. **Disconnect when done**
   ```
   mcp_obsidian-automation_disconnect()
   ```

### Common Execute Commands

```javascript
// Get all commands
`Object.keys(app.commands.commands)`

// Run a command
`app.commands.executeCommandById('command-id')`

// Get plugin instance
`app.plugins.plugins['plugin-id']`

// Get settings
`app.plugins.plugins['plugin-id']?.settings`

// Get current view
`app.workspace.getActiveViewOfType(MarkdownView)`

// Read file content
`await app.vault.read(app.workspace.getActiveFile())`
```

## File Structure

```
obsidian-playwright-mcp/
├── obsidian-mcp-server.js    # Main MCP server (run by AI agents)
├── launch-obsidian-debug.ps1 # PowerShell script to start Obsidian
├── test-obsidian.js          # Manual test script
├── package.json              # Dependencies
├── screenshots/              # Captured screenshots
│   ├── initial-state.png
│   └── ...
└── SKILL.md                  # This file
```

## Troubleshooting

### Connection Refused (ECONNREFUSED)

**Problem**: `connect ECONNREFUSED ::1:8315`

**Solution**: Obsidian is not running with debug port. Run:
```powershell
.\launch-obsidian-debug.ps1
```

### Port Already in Use

**Problem**: Another process is using port 8315

**Solution**:
```powershell
# Find what's using the port
netstat -ano | findstr :8315

# Kill Obsidian and restart
Get-Process -Name "Obsidian" | Stop-Process -Force
Start-Sleep -Seconds 2
.\launch-obsidian-debug.ps1
```

### "No pages found in Obsidian"

**Problem**: Obsidian started but window not ready

**Solution**: Wait a few seconds after launching, or check:
```powershell
# Verify Obsidian is running
Get-Process -Name "Obsidian"

# Check debug port is listening
netstat -ano | findstr :8315
```

### Console logs not appearing

**Problem**: Logs array is empty

**Reason**: Logs are only captured *after* `connect_to_obsidian()` is called. Logs from before connection are not captured.

**Solution**: Connect early, then trigger the actions you want to debug.

## Integration with Plugin Development

This MCP server is especially useful for:

1. **Automated Testing**: Take screenshots and verify UI state
2. **Debugging**: Capture console errors when testing plugin features
3. **Rapid Iteration**: Execute plugin commands without clicking through UI
4. **State Inspection**: Query plugin settings and internal state

### Example: Test the Spaced Reading Plugin

```javascript
// Connect
await mcp_obsidian-automation_connect_to_obsidian()

// Check if plugin is loaded
await mcp_obsidian-automation_execute_in_renderer({
  code: `!!app.plugins.plugins['obsidian-spaced-reading']`
})

// Get queue count
await mcp_obsidian-automation_execute_in_renderer({
  code: `app.plugins.plugins['obsidian-spaced-reading']?.queueService?.getQueueLength()`
})

// Open queue modal
await mcp_obsidian-automation_execute_in_renderer({
  code: `app.commands.executeCommandById('spaced-reading:show-queue')`
})

// Screenshot the result
await mcp_obsidian-automation_take_screenshot({ filename: "queue-modal.png" })
```

---

**Created**: 2026-01-09  
**Version**: 2.0.0  
**Port**: 8315 (Chrome DevTools Protocol)
