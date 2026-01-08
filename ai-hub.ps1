<#
.SYNOPSIS
    AI Hub - Unified CLI wrapper for Claude Code, Gemini CLI, and Codex CLI.

.DESCRIPTION
    A menu-driven interface for managing AI coding agents with:
    - Quick agent switching
    - Session handoffs with context
    - Config sync across all CLIs
    - Session logging

.EXAMPLE
    ai-hub
    # Launches the main menu

.EXAMPLE
    ai-hub claude
    # Directly launches Claude Code
#>

param(
    [Parameter(Position = 0)]
    [ValidateSet("claude", "gemini", "codex", "sync", "status", "")]
    [string]$Action = ""
)

#region Configuration
$script:Config = @{
    SyncRoot = "$env:USERPROFILE\.agent-sync"
    LogFile  = "$env:USERPROFILE\.agent-sync\ai-hub.log"
    Agents   = @{
        claude = @{ Name = "Claude Code"; Command = "claude"; Color = "Cyan"; Icon = "🤖" }
        gemini = @{ Name = "Gemini CLI"; Command = "gemini"; Color = "Magenta"; Icon = "✨" }
        codex  = @{ Name = "Codex CLI"; Command = "codex"; Color = "Green"; Icon = "🚀" }
    }
}
#endregion

#region ANSI Colors and Styling (Claude Code style)
$script:Colors = @{
    Reset         = "`e[0m"
    Bold          = "`e[1m"
    Dim           = "`e[2m"
    
    # Foreground
    Black         = "`e[30m"
    Red           = "`e[31m"
    Green         = "`e[32m"
    Yellow        = "`e[33m"
    Blue          = "`e[34m"
    Magenta       = "`e[35m"
    Cyan          = "`e[36m"
    White         = "`e[37m"
    
    # Bright foreground
    BrightBlack   = "`e[90m"
    BrightRed     = "`e[91m"
    BrightGreen   = "`e[92m"
    BrightYellow  = "`e[93m"
    BrightBlue    = "`e[94m"
    BrightMagenta = "`e[95m"
    BrightCyan    = "`e[96m"
    BrightWhite   = "`e[97m"
    
    # Background
    BgBlue        = "`e[44m"
    BgCyan        = "`e[46m"
}

# Box drawing characters (Claude Code style)
$script:Box = @{
    TopLeft     = "╭"
    TopRight    = "╮"
    BottomLeft  = "╰"
    BottomRight = "╯"
    Horizontal  = "─"
    Vertical    = "│"
    LeftT       = "├"
    RightT      = "┤"
}
#endregion

#region Helper Functions

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $script:Config.LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Write-Styled {
    param(
        [string]$Text,
        [string]$Color = "White",
        [switch]$Bold,
        [switch]$NoNewLine
    )
    
    $colorCode = $script:Colors[$Color]
    $boldCode = if ($Bold) { $script:Colors.Bold } else { "" }
    $output = "$boldCode$colorCode$Text$($script:Colors.Reset)"
    
    if ($NoNewLine) {
        Write-Host $output -NoNewline
    }
    else {
        Write-Host $output
    }
}

function Write-Box {
    param(
        [string]$Title,
        [string[]]$Content,
        [int]$Width = 50,
        [string]$TitleColor = "Cyan"
    )
    
    $b = $script:Box
    $innerWidth = $Width - 2
    
    # Top border with title
    $titlePadded = " $Title "
    $leftPad = [math]::Floor(($innerWidth - $titlePadded.Length) / 2)
    $rightPad = $innerWidth - $leftPad - $titlePadded.Length
    
    Write-Styled -Text $b.TopLeft -Color "BrightBlack" -NoNewLine
    Write-Styled -Text ($b.Horizontal * $leftPad) -Color "BrightBlack" -NoNewLine
    Write-Styled -Text $titlePadded -Color $TitleColor -Bold -NoNewLine
    Write-Styled -Text ($b.Horizontal * $rightPad) -Color "BrightBlack" -NoNewLine
    Write-Styled -Text $b.TopRight -Color "BrightBlack"
    
    # Content
    foreach ($line in $Content) {
        $paddedLine = $line.PadRight($innerWidth).Substring(0, [Math]::Min($line.Length, $innerWidth)).PadRight($innerWidth)
        Write-Styled -Text $b.Vertical -Color "BrightBlack" -NoNewLine
        Write-Host $paddedLine -NoNewline
        Write-Styled -Text $b.Vertical -Color "BrightBlack"
    }
    
    # Bottom border
    Write-Styled -Text $b.BottomLeft -Color "BrightBlack" -NoNewLine
    Write-Styled -Text ($b.Horizontal * $innerWidth) -Color "BrightBlack" -NoNewLine
    Write-Styled -Text $b.BottomRight -Color "BrightBlack"
}

function Write-Divider {
    param([int]$Width = 50)
    $b = $script:Box
    Write-Styled -Text $b.LeftT -Color "BrightBlack" -NoNewLine
    Write-Styled -Text ($b.Horizontal * ($Width - 2)) -Color "BrightBlack" -NoNewLine
    Write-Styled -Text $b.RightT -Color "BrightBlack"
}
# Arrow key menu selection with proper in-place updates
function Select-MenuOption {
    param(
        [array]$MenuItems,
        [string]$Prompt = "Select option"
    )
    
    # Filter to only selectable items (those with a Key)
    $selectableItems = $MenuItems | Where-Object { $_.Key -ne "" }
    $selectedIndex = 0
    $maxIndex = $selectableItems.Count - 1
    
    # ANSI escape codes
    $esc = [char]27
    $saveCursor = "$esc[s"
    $restoreCursor = "$esc[u"
    $clearLine = "$esc[2K"
    $reset = "$esc[0m"
    
    # Save cursor position before first draw
    Write-Host -NoNewline $saveCursor
    
    # Initial draw
    $firstDraw = $true
    
    while ($true) {
        if (-not $firstDraw) {
            # Restore cursor to saved position and redraw
            Write-Host -NoNewline $restoreCursor
        }
        $firstDraw = $false
        
        Write-Host ""
        $selectableIndex = 0
        foreach ($item in $MenuItems) {
            # Clear the line first
            Write-Host -NoNewline $clearLine
            
            if ($item.Key -eq "") {
                # Divider
                Write-Styled -Text "  $($item.Label)" -Color $item.Color
            }
            else {
                $isSelected = ($selectableIndex -eq $selectedIndex)
                $prefix = if ($isSelected) { "▶ " } else { "  " }
                $bg = if ($isSelected) { "$esc[48;5;236m" } else { "" }
                
                Write-Host -NoNewline "$bg"
                Write-Styled -Text $prefix -Color $(if ($isSelected) { "BrightCyan" } else { "BrightBlack" }) -NoNewLine
                Write-Styled -Text "[" -Color "BrightBlack" -NoNewLine
                Write-Styled -Text $item.Key -Color $(if ($isSelected) { "BrightCyan" } else { "BrightBlack" }) -Bold -NoNewLine
                Write-Styled -Text "] " -Color "BrightBlack" -NoNewLine
                Write-Styled -Text "$($item.Icon) " -NoNewLine
                Write-Styled -Text $item.Label -Color $(if ($isSelected) { "BrightWhite" } else { $item.Color })
                Write-Host -NoNewline $reset
                $selectableIndex++
            }
        }
        Write-Host ""
        Write-Host -NoNewline $clearLine
        Write-Styled -Text "  ↑↓ Navigate  Enter Select  # Direct" -Color "Dim"
        
        # Read key
        $key = [Console]::ReadKey($true)
        
        switch ($key.Key) {
            "UpArrow" {
                $selectedIndex--
                if ($selectedIndex -lt 0) { $selectedIndex = $maxIndex }
            }
            "DownArrow" {
                $selectedIndex++
                if ($selectedIndex -gt $maxIndex) { $selectedIndex = 0 }
            }
            "Enter" {
                Write-Host ""
                return $selectableItems[$selectedIndex].Key
            }
            "Escape" {
                Write-Host ""
                return "0"  # Exit on Escape
            }
            default {
                # Check if it's a number key for direct selection
                $char = $key.KeyChar
                $directItem = $selectableItems | Where-Object { $_.Key -eq $char }
                if ($directItem) {
                    Write-Host ""
                    return $char
                }
            }
        }
    }
}

function Write-Banner {
    Clear-Host
    $banner = @"

    $($script:Colors.Cyan)$($script:Colors.Bold)╭─────────────────────────────────────╮$($script:Colors.Reset)
    $($script:Colors.Cyan)$($script:Colors.Bold)│$($script:Colors.Reset)  $($script:Colors.BrightCyan)🤖 AI Hub$($script:Colors.Reset) $($script:Colors.Dim)- Agent Manager$($script:Colors.Reset)      $($script:Colors.Cyan)$($script:Colors.Bold)│$($script:Colors.Reset)
    $($script:Colors.Cyan)$($script:Colors.Bold)╰─────────────────────────────────────╯$($script:Colors.Reset)

"@
    Write-Host $banner
    
    # Show current context
    $project = (Get-Location).Path
    Write-Styled -Text "  📂 " -Color "Yellow" -NoNewLine
    Write-Styled -Text $project -Color "White"
    
    # Show session state if exists
    $sessionFile = Join-Path $project ".agent\session-state.md"
    if (Test-Path $sessionFile) {
        $content = Get-Content $sessionFile -Raw
        if ($content -match '\*\*Agent:\*\* (.+)') {
            $lastAgent = $Matches[1]
            Write-Styled -Text "  📋 " -Color "Blue" -NoNewLine
            Write-Styled -Text "Last session: " -Color "Dim" -NoNewLine
            Write-Styled -Text $lastAgent -Color "White"
        }
    }
    Write-Host ""
}

function Show-MainMenu {
    $menuItems = @(
        @{ Key = "1"; Label = "Launch Claude Code"; Icon = "🤖"; Color = "Cyan" }
        @{ Key = "2"; Label = "Launch Gemini CLI"; Icon = "✨"; Color = "Magenta" }
        @{ Key = "3"; Label = "Launch Codex CLI"; Icon = "🚀"; Color = "Green" }
        @{ Key = ""; Label = "─────────────────────────────────"; Icon = ""; Color = "BrightBlack" }
        @{ Key = "4"; Label = "Sync all configs"; Icon = "🔄"; Color = "Yellow" }
        @{ Key = "5"; Label = "Edit AGENTS.md"; Icon = "📝"; Color = "Blue" }
        @{ Key = "6"; Label = "View session state"; Icon = "📋"; Color = "Cyan" }
        @{ Key = "7"; Label = "View sync status"; Icon = "📊"; Color = "Green" }
        @{ Key = ""; Label = "─────────────────────────────────"; Icon = ""; Color = "BrightBlack" }
        @{ Key = "0"; Label = "Exit"; Icon = "👋"; Color = "Red" }
    )
    
    return Select-MenuOption -MenuItems $menuItems -Prompt "Select option"
}

function Show-PostSessionMenu {
    param([string]$AgentName)
    
    Write-Host ""
    Write-Styled -Text "  Session ended: " -Color "Dim" -NoNewLine
    Write-Styled -Text $AgentName -Color "Cyan" -Bold
    Write-Host ""
    
    $menuItems = @(
        @{ Key = "1"; Label = "Handoff to another agent"; Icon = "🔄"; Color = "Yellow" }
        @{ Key = "2"; Label = "Sync configs"; Icon = "🔗"; Color = "Green" }
        @{ Key = "3"; Label = "Save session notes"; Icon = "📝"; Color = "Blue" }
        @{ Key = ""; Label = "─────────────────────────────────"; Icon = ""; Color = "BrightBlack" }
        @{ Key = "4"; Label = "Return to main menu"; Icon = "🏠"; Color = "Cyan" }
        @{ Key = "0"; Label = "Exit"; Icon = "👋"; Color = "Red" }
    )
    
    return Select-MenuOption -MenuItems $menuItems -Prompt "Select action"
}

function Invoke-AgentSession {
    param([string]$AgentKey)
    
    $agent = $script:Config.Agents[$AgentKey]
    if (-not $agent) {
        Write-Styled -Text "  Unknown agent: $AgentKey" -Color "Red"
        return
    }
    
    # Check if command exists
    $cmd = Get-Command $agent.Command -ErrorAction SilentlyContinue
    if (-not $cmd) {
        Write-Styled -Text "  ❌ $($agent.Name) not found. Is it installed?" -Color "Red"
        Start-Sleep -Seconds 2
        return
    }
    
    # Pre-session: Show context
    Write-Host ""
    Write-Styled -Text "  $($agent.Icon) Launching " -Color "Dim" -NoNewLine
    Write-Styled -Text $agent.Name -Color $agent.Color -Bold -NoNewLine
    Write-Styled -Text "..." -Color "Dim"
    Write-Host ""
    
    # Log session start
    Write-Log -Message "Starting $($agent.Name) session" -Level "INFO"
    $env:AI_HUB_AGENT = $AgentKey
    
    # Launch the agent
    Start-Sleep -Milliseconds 500
    & $agent.Command
    
    # Post-session
    Write-Log -Message "Ended $($agent.Name) session" -Level "INFO"
    
    # Show post-session menu
    $continue = $true
    while ($continue) {
        $choice = Show-PostSessionMenu -AgentName $agent.Name
        
        switch ($choice) {
            "1" { Invoke-Handoff -FromAgent $agent.Name; $continue = $false }
            "2" { Invoke-Sync; Write-Host ""; Write-Styled -Text "  Press Enter to continue..." -Color "Dim" -NoNewLine; Read-Host }
            "3" { Invoke-SaveNotes }
            "4" { $continue = $false }
            "0" { $continue = $false; $script:ExitApp = $true }
            default { Write-Styled -Text "  Invalid option" -Color "Red" }
        }
    }
}

function Invoke-Handoff {
    param([string]$FromAgent = "Unknown")
    
    Write-Host ""
    Write-Styled -Text "  📝 Enter handoff summary (what you worked on, next steps):" -Color "Yellow"
    Write-Styled -Text "  > " -Color "Dim" -NoNewLine
    $summary = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($summary)) {
        Write-Styled -Text "  ⚠️  No summary provided, skipping handoff" -Color "Yellow"
        return
    }
    
    # Write session state
    $project = (Get-Location).Path
    $agentDir = Join-Path $project ".agent"
    $sessionFile = Join-Path $agentDir "session-state.md"
    
    if (-not (Test-Path $agentDir)) {
        New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
    $content = @"
# Session State

**Updated:** $timestamp
**Agent:** $FromAgent
**Project:** $project

## Handoff Summary
$summary

---
*Generated by ai-hub*
"@
    
    $content | Set-Content $sessionFile -Encoding UTF8
    Write-Styled -Text "  ✅ Session state saved" -Color "Green"
    Write-Log -Message "Handoff saved: $summary" -Level "INFO"
    
    # Offer to launch another agent
    Write-Host ""
    Write-Styled -Text "  Launch another agent? " -Color "Dim"
    Write-Styled -Text "  [1] Claude  [2] Gemini  [3] Codex  [0] Skip" -Color "BrightBlack"
    Write-Styled -Text "  > " -Color "Dim" -NoNewLine
    $next = Read-Host
    
    switch ($next) {
        "1" { Invoke-AgentSession -AgentKey "claude" }
        "2" { Invoke-AgentSession -AgentKey "gemini" }
        "3" { Invoke-AgentSession -AgentKey "codex" }
    }
}

function Invoke-Sync {
    Write-Host ""
    Write-Styled -Text "  🔄 Syncing configs..." -Color "Yellow"
    
    $syncScript = Join-Path $script:Config.SyncRoot "sync-agents.ps1"
    if (Test-Path $syncScript) {
        & $syncScript
    }
    else {
        Write-Styled -Text "  ❌ Sync script not found" -Color "Red"
    }
    
    Write-Log -Message "Sync executed" -Level "INFO"
}

function Invoke-SaveNotes {
    Write-Host ""
    Write-Styled -Text "  📝 Enter session notes:" -Color "Yellow"
    Write-Styled -Text "  > " -Color "Dim" -NoNewLine
    $notes = Read-Host
    
    if (-not [string]::IsNullOrWhiteSpace($notes)) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
        $project = (Get-Location).Path
        $notesFile = Join-Path $script:Config.SyncRoot "session-notes.log"
        
        $entry = "[$timestamp] [$project] $notes"
        Add-Content -Path $notesFile -Value $entry
        Write-Styled -Text "  ✅ Notes saved" -Color "Green"
        Write-Log -Message "Notes: $notes" -Level "INFO"
    }
}

function Invoke-EditAgentsMd {
    $agentsMd = Join-Path $script:Config.SyncRoot "AGENTS.md"
    
    if (-not (Test-Path $agentsMd)) {
        Write-Styled -Text "  ❌ AGENTS.md not found" -Color "Red"
        return
    }
    
    # Try VS Code first, then notepad
    $editor = Get-Command "code" -ErrorAction SilentlyContinue
    if ($editor) {
        & code $agentsMd --wait
    }
    else {
        & notepad $agentsMd
    }
    
    # Prompt to sync after editing
    Write-Host ""
    Write-Styled -Text "  Sync changes to all CLIs? [Y/n] " -Color "Yellow" -NoNewLine
    $sync = Read-Host
    if ($sync -ne "n" -and $sync -ne "N") {
        Invoke-Sync
    }
}

function Show-SessionState {
    $project = (Get-Location).Path
    $sessionFile = Join-Path $project ".agent\session-state.md"
    
    Write-Host ""
    if (Test-Path $sessionFile) {
        Write-Styled -Text "  📋 Current Session State:" -Color "Cyan" -Bold
        Write-Host ""
        Get-Content $sessionFile | ForEach-Object {
            Write-Styled -Text "  $_" -Color "White"
        }
    }
    else {
        Write-Styled -Text "  ⚠️  No session state for this project" -Color "Yellow"
    }
    Write-Host ""
    Write-Styled -Text "  Press Enter to continue..." -Color "Dim" -NoNewLine
    Read-Host
}

function Show-SyncStatus {
    Write-Host ""
    $syncScript = Join-Path $script:Config.SyncRoot "sync-agents.ps1"
    if (Test-Path $syncScript) {
        & $syncScript -Status
    }
    else {
        Write-Styled -Text "  ❌ Sync script not found" -Color "Red"
    }
    Write-Host ""
    Write-Styled -Text "  Press Enter to continue..." -Color "Dim" -NoNewLine
    Read-Host
}

#endregion

#region Main Loop

function Start-AiHub {
    # Handle direct action
    if ($Action) {
        switch ($Action) {
            "claude" { Invoke-AgentSession -AgentKey "claude"; return }
            "gemini" { Invoke-AgentSession -AgentKey "gemini"; return }
            "codex" { Invoke-AgentSession -AgentKey "codex"; return }
            "sync" { Invoke-Sync; return }
            "status" { Show-SyncStatus; return }
        }
    }
    
    # Main menu loop
    $script:ExitApp = $false
    
    while (-not $script:ExitApp) {
        Write-Banner
        $choice = Show-MainMenu
        
        switch ($choice) {
            "1" { Invoke-AgentSession -AgentKey "claude" }
            "2" { Invoke-AgentSession -AgentKey "gemini" }
            "3" { Invoke-AgentSession -AgentKey "codex" }
            "4" { Invoke-Sync; Start-Sleep -Seconds 1 }
            "5" { Invoke-EditAgentsMd }
            "6" { Show-SessionState }
            "7" { Show-SyncStatus }
            "0" { $script:ExitApp = $true }
            default { 
                Write-Styled -Text "  Invalid option" -Color "Red"
                Start-Sleep -Milliseconds 500
            }
        }
    }
    
    Write-Host ""
    Write-Styled -Text "  👋 Goodbye!" -Color "Cyan"
    Write-Host ""
}

#endregion

# Entry point
Write-Log -Message "AI Hub started" -Level "INFO"
Start-AiHub
Write-Log -Message "AI Hub exited" -Level "INFO"
