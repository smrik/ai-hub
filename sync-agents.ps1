<#
.SYNOPSIS
    Sync AI agent configurations across Claude Code, Gemini CLI, and Codex CLI.

.DESCRIPTION
    This script synchronizes AGENTS.md and MCP server configurations from the
    master location (~/.agent-sync/) to each CLI's config directory.

.PARAMETER Handoff
    Optional summary of current work state to write to project's session-state.md

.PARAMETER Status
    Show current sync status and last agent session info

.PARAMETER Project
    Project path for session state operations (defaults to current directory)

.EXAMPLE
    sync-agents
    # Syncs all configs

.EXAMPLE
    sync-agents --handoff "Working on Anki integration, next: connect modal"
    # Updates session state with handoff context

.EXAMPLE
    sync-agents --status
    # Shows current state
#>

param(
    [string]$Handoff,
    [switch]$Status,
    [string]$Project = (Get-Location).Path
)

$SyncRoot = "$env:USERPROFILE\.agent-sync"
$AgentsMd = "$SyncRoot\AGENTS.md"
$McpConfig = "$SyncRoot\mcp-servers.json"
$SessionTemplate = "$SyncRoot\templates\session-state.md"

$ClaudeDir = "$env:USERPROFILE\.claude"
$GeminiDir = "$env:USERPROFILE\.gemini"
$CodexDir = "$env:USERPROFILE\.codex"
$AntigravityDir = "$env:USERPROFILE\.gemini\antigravity"

function Write-Info { param($msg) Write-Host "  [INFO] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Err { param($msg) Write-Host "  [ERR] $msg" -ForegroundColor Red }

# Convert MCP JSON to TOML for Codex
function ConvertTo-CodexToml {
    param([hashtable]$McpServers)
    
    $toml = @"
[features]
unified_exec = true

[mcp_servers]

"@
    
    foreach ($serverName in $McpServers.Keys) {
        $server = $McpServers[$serverName]
        $toml += "`n[mcp_servers.$serverName]`n"
        
        foreach ($key in $server.Keys) {
            $value = $server[$key]
            if ($key -eq "env") {
                $toml += "[mcp_servers.$serverName.env]`n"
                foreach ($envKey in $value.Keys) {
                    $envVal = $value[$envKey] -replace '\\', '\\\\'
                    $toml += "$envKey = `"$envVal`"`n"
                }
            }
            elseif ($value -is [array]) {
                $arrayStr = ($value | ForEach-Object { "`"$_`"" }) -join ", "
                $toml += "$key = [$arrayStr]`n"
            }
            elseif ($value -is [int]) {
                $toml += "$key = $value`n"
            }
            elseif ($value -is [string]) {
                $toml += "$key = `"$value`"`n"
            }
        }
    }
    
    return $toml
}

# Sync AGENTS.md to all CLIs
function Sync-AgentsMd {
    Write-Info "Syncing AGENTS.md..."

    if (-not (Test-Path $AgentsMd)) {
        Write-Err "Master AGENTS.md not found at $AgentsMd"
        return $false
    }

    $allSuccess = $true

    # Copy to Claude
    try {
        if (-not (Test-Path $ClaudeDir)) { New-Item -ItemType Directory -Path $ClaudeDir -Force | Out-Null }
        Copy-Item $AgentsMd "$ClaudeDir\AGENTS.md" -Force -ErrorAction Stop
        Write-Success "Copied to .claude/AGENTS.md"
    }
    catch {
        Write-Err "Failed to copy to .claude/: $_"
        $allSuccess = $false
    }

    # Copy to Gemini
    try {
        if (-not (Test-Path $GeminiDir)) { New-Item -ItemType Directory -Path $GeminiDir -Force | Out-Null }
        Copy-Item $AgentsMd "$GeminiDir\AGENTS.md" -Force -ErrorAction Stop
        Write-Success "Copied to .gemini/AGENTS.md"
    }
    catch {
        Write-Err "Failed to copy to .gemini/: $_"
        $allSuccess = $false
    }

    # Copy to Codex
    try {
        if (-not (Test-Path $CodexDir)) { New-Item -ItemType Directory -Path $CodexDir -Force | Out-Null }
        Copy-Item $AgentsMd "$CodexDir\AGENTS.md" -Force -ErrorAction Stop
        Write-Success "Copied to .codex/AGENTS.md"
    }
    catch {
        Write-Err "Failed to copy to .codex/: $_"
        $allSuccess = $false
    }

    # Also update user home for backward compat
    try {
        Copy-Item $AgentsMd "$env:USERPROFILE\AGENTS.md" -Force -ErrorAction Stop
        Write-Success "Copied to ~/AGENTS.md"
    }
    catch {
        Write-Err "Failed to copy to ~/: $_"
        $allSuccess = $false
    }

    return $allSuccess
}

# Sync MCP servers to all CLIs
function Sync-McpServers {
    Write-Info "Syncing MCP servers..."

    if (-not (Test-Path $McpConfig)) {
        Write-Err "Master MCP config not found at $McpConfig"
        return $false
    }

    $allSuccess = $true

    try {
        $mcpJson = Get-Content $McpConfig -Raw | ConvertFrom-Json -AsHashtable
        $mcpServers = $mcpJson.mcpServers
    }
    catch {
        Write-Err "Failed to parse MCP config: $_"
        return $false
    }

    # Update Gemini settings.json
    try {
        $geminiSettings = "$GeminiDir\settings.json"
        if (Test-Path $geminiSettings) {
            $gemini = Get-Content $geminiSettings -Raw | ConvertFrom-Json -AsHashtable
        }
        else {
            $gemini = @{}
        }

        # Gemini has stricter validation - filter out unsupported keys
        $geminiMcpServers = @{}
        $unsupportedKeys = @("name", "type", "startup_timeout_ms")

        foreach ($serverName in $mcpServers.Keys) {
            $server = $mcpServers[$serverName]
            $filteredServer = @{}

            foreach ($key in $server.Keys) {
                if ($key -notin $unsupportedKeys) {
                    $filteredServer[$key] = $server[$key]
                }
            }

            # Skip SSE-type servers (mcp-gateway) for Gemini as they require 'url' which isn't standard
            if ($server.ContainsKey("url")) {
                Write-Warn "Skipping SSE server '$serverName' for Gemini (not supported)"
                continue
            }

            $geminiMcpServers[$serverName] = $filteredServer
        }

        $gemini.mcpServers = $geminiMcpServers
        # Ensure contextFileName is set at root (not nested under context)
        if (-not $gemini.ContainsKey("contextFileName")) {
            $gemini["contextFileName"] = "AGENTS.md"
        }
        # Remove nested context if it exists
        if ($gemini.ContainsKey("context")) {
            $gemini.Remove("context")
        }
        $gemini | ConvertTo-Json -Depth 10 | Set-Content $geminiSettings -Encoding UTF8
        Write-Success "Updated .gemini/settings.json"
    }
    catch {
        Write-Err "Failed to update Gemini settings: $_"
        $allSuccess = $false
    }

    # Update Codex config.toml
    try {
        if (-not (Test-Path $CodexDir)) { New-Item -ItemType Directory -Path $CodexDir -Force | Out-Null }
        $codexConfig = "$CodexDir\config.toml"
        $toml = ConvertTo-CodexToml -McpServers $mcpServers
        $toml | Set-Content $codexConfig -Encoding UTF8
        Write-Success "Updated .codex/config.toml"
    }
    catch {
        Write-Err "Failed to update Codex config: $_"
        $allSuccess = $false
    }

    # Update Claude .claude.json (global)
    try {
        $claudeGlobal = "$env:USERPROFILE\.claude.json"
        if (Test-Path $claudeGlobal) {
            $claude = Get-Content $claudeGlobal -Raw | ConvertFrom-Json -AsHashtable
            $claude.mcpServers = $mcpServers
        }
        else {
            $claude = @{ mcpServers = $mcpServers }
        }
        $claude | ConvertTo-Json -Depth 10 | Set-Content $claudeGlobal -Encoding UTF8
        Write-Success "Updated ~/.claude.json"
    }
    catch {
        Write-Err "Failed to update Claude config: $_"
        $allSuccess = $false
    }

    return $allSuccess
}

# Sync MCP servers to Antigravity
function Sync-Antigravity {
    Write-Info "Syncing to Antigravity..."

    if (-not (Test-Path $AntigravityDir)) {
        Write-Warn "Antigravity directory not found at $AntigravityDir"
        return $true  # Not an error, just not installed
    }

    if (-not (Test-Path $McpConfig)) {
        Write-Err "Master MCP config not found at $McpConfig"
        return $false
    }

    try {
        $mcpJson = Get-Content $McpConfig -Raw | ConvertFrom-Json -AsHashtable
        $mcpServers = $mcpJson.mcpServers

        # Antigravity uses a simpler format - filter and adapt servers
        $antigravityMcp = @{ mcpServers = @{} }
        $unsupportedKeys = @("name", "type", "startup_timeout_ms", "url")

        foreach ($serverName in $mcpServers.Keys) {
            $server = $mcpServers[$serverName]

            # Skip SSE-type servers (url-based like mcp-gateway)
            if ($server.ContainsKey("url")) {
                Write-Warn "Skipping SSE server '$serverName' for Antigravity"
                continue
            }

            $filteredServer = @{}
            foreach ($key in $server.Keys) {
                if ($key -notin $unsupportedKeys) {
                    $filteredServer[$key] = $server[$key]
                }
            }

            $antigravityMcp.mcpServers[$serverName] = $filteredServer
        }

        $antigravityConfig = "$AntigravityDir\mcp_config.json"
        $antigravityMcp | ConvertTo-Json -Depth 10 | Set-Content $antigravityConfig -Encoding UTF8
        Write-Success "Updated .gemini/antigravity/mcp_config.json"

        return $true
    }
    catch {
        Write-Err "Failed to sync Antigravity: $_"
        return $false
    }
}

# Update session state for handoff
function Update-SessionState {
    param([string]$Summary, [string]$ProjectPath)
    
    $agentDir = Join-Path $ProjectPath ".agent"
    $sessionFile = Join-Path $agentDir "session-state.md"
    
    if (-not (Test-Path $agentDir)) {
        New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
        Write-Info "Created .agent/ directory"
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
    $agent = if ($env:CLAUDE_CODE) { "Claude Code" } 
    elseif ($env:GEMINI_CLI) { "Gemini CLI" }
    elseif ($env:CODEX_CLI) { "Codex CLI" }
    else { "Unknown" }
    
    $content = @"
# Session State

**Updated:** $timestamp
**Agent:** $agent
**Project:** $ProjectPath

## Handoff Summary
$Summary

---
*Generated by sync-agents.ps1*
"@
    
    $content | Set-Content $sessionFile -Encoding UTF8
    Write-Success "Updated $sessionFile"
}

# Show status
function Show-Status {
    Write-Host "`n  === Agent Sync Status ===" -ForegroundColor Magenta
    
    Write-Host "`n  Master Files:" -ForegroundColor Yellow
    if (Test-Path $AgentsMd) { Write-Success "AGENTS.md exists" } else { Write-Err "AGENTS.md missing" }
    if (Test-Path $McpConfig) { Write-Success "mcp-servers.json exists" } else { Write-Err "mcp-servers.json missing" }
    
    Write-Host "`n  CLI Configs:" -ForegroundColor Yellow
    if (Test-Path "$ClaudeDir\AGENTS.md") { Write-Success "Claude: AGENTS.md synced" } else { Write-Warn "Claude: AGENTS.md not synced" }
    if (Test-Path "$GeminiDir\AGENTS.md") { Write-Success "Gemini: AGENTS.md synced" } else { Write-Warn "Gemini: AGENTS.md not synced" }
    if (Test-Path "$CodexDir\AGENTS.md") { Write-Success "Codex: AGENTS.md synced" } else { Write-Warn "Codex: AGENTS.md not synced" }
    if (Test-Path "$AntigravityDir\mcp_config.json") { Write-Success "Antigravity: MCP config synced" } else { Write-Warn "Antigravity: MCP config not synced" }
    
    Write-Host "`n  Project Session:" -ForegroundColor Yellow
    $sessionFile = Join-Path $Project ".agent\session-state.md"
    if (Test-Path $sessionFile) {
        Write-Success "Session state exists"
        $content = Get-Content $sessionFile -Raw
        if ($content -match '\*\*Updated:\*\* (.+)') { Write-Info "Last updated: $($Matches[1])" }
        if ($content -match '\*\*Agent:\*\* (.+)') { Write-Info "Last agent: $($Matches[1])" }
    }
    else {
        Write-Warn "No session state for this project"
    }
    
    Write-Host ""
}

# Main execution
Write-Host "`n  === Sync Agents ===" -ForegroundColor Magenta

if ($Status) {
    Show-Status
    exit 0
}

if ($Handoff) {
    Update-SessionState -Summary $Handoff -ProjectPath $Project
    exit 0
}

# Default: sync everything
$success = $true
$success = $success -and (Sync-AgentsMd)
$success = $success -and (Sync-McpServers)
$success = $success -and (Sync-Antigravity)

if ($success) {
    Write-Host "`n  All configs synced successfully!" -ForegroundColor Green
}
else {
    Write-Host "`n  Some syncs failed. Check errors above." -ForegroundColor Red
}

Write-Host ""
