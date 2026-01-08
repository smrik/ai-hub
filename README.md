# AI Hub

A unified CLI wrapper for managing AI coding agents (Claude Code, Gemini CLI, Codex CLI) with seamless switching, session handoffs, and config sync.

## Features

- 🔄 **Quick agent switching** - Launch any agent from a single menu
- 📋 **Session handoffs** - Pass context between agents when switching
- 🔗 **Config sync** - Keep AGENTS.md and MCP servers in sync across all CLIs
- 📝 **Session logging** - Track which agents you've used and when
- 🎨 **Claude Code-style UI** - Beautiful terminal interface with box drawing

## Installation

```powershell
# Clone the repo
git clone https://github.com/YOUR_USERNAME/ai-hub.git ~/.agent-sync

# Add to your PowerShell profile
Add-Content $PROFILE "`n. `$env:USERPROFILE\.agent-sync\cli-aliases.ps1"

# Reload profile
. $PROFILE
```

## Usage

### Interactive Menu
```powershell
ai-hub
```

### Direct Agent Launch
```powershell
ai-hub claude    # Launch Claude Code
ai-hub gemini    # Launch Gemini CLI
ai-hub codex     # Launch Codex CLI
```

### Sync & Status
```powershell
ai-hub sync      # Sync configs to all CLIs
ai-hub status    # View sync status
```

## Post-Session Actions

After you exit an agent, AI Hub offers:
1. **Handoff** - Save context for the next agent
2. **Sync** - Sync configs across all CLIs
3. **Save notes** - Quick session notes
4. **Switch** - Jump to another agent

## Configuration

All config files are stored in `~/.agent-sync/`:

| File | Purpose |
|------|---------|
| `AGENTS.md` | Master instructions for all agents |
| `mcp-servers.json` | Master MCP server configuration |
| `sync-agents.ps1` | Sync script |
| `ai-hub.ps1` | This CLI wrapper |
| `ai-hub.log` | Session log |

## MCP Servers

AI Hub syncs these MCP servers across all CLIs:
- Perplexity (research)
- BrightData (web scraping)
- Context7 (context management)
- Excel MCP (spreadsheet operations)
- Obsidian Automation (plugin testing)
- MCP Gateway (multi-model routing)

## Requirements

- PowerShell 7+
- Windows 10/11
- Claude Code, Gemini CLI, and/or Codex CLI installed

## License

MIT
