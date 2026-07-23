#Requires -Version 5.1
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Generic game boost: kills non-essential background processes, sets a performance
    power plan, monitors the game, and restores everything on exit.

.DESCRIPTION
    Generalizes the Arc Raiders game-boost engine for any game via a per-game
    manifest (see Scripts/games/*.psd1):
      1. Self-elevates to Administrator if needed
      2. Captures current power plan GUID
      3. Switches to Ultimate/High Performance power plan
      4. Kills non-essential background apps and records them for restore
      5. Trims working sets of all remaining processes
      6. Launches the game (Steam or a direct exe) if not already running
      7. Waits for the game to exit
      8. Restores power plan and restarts killed processes

.PARAMETER GameManifest
    Path to a game manifest .psd1 (see Scripts/arc-raiders/arc-raiders.psd1 for the schema).

.PARAMETER NoLaunch
    Apply boost only — do not launch the game (use if game is already running).

.PARAMETER NoRestore
    Do not restore killed processes or power plan on exit.

.PARAMETER DryRun
    Show what would be killed/changed without actually doing it.

.EXAMPLE
    .\start-optimized-game.ps1 -GameManifest Scripts\arc-raiders\arc-raiders.psd1
.EXAMPLE
    .\start-optimized-game.ps1 -GameManifest Scripts\arc-raiders\arc-raiders.psd1 -DryRun
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ })]
    [string]$GameManifest,
    [switch]$NoLaunch,
    [switch]$NoRestore,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
. "$PSScriptRoot\Common.ps1"
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ─────────────────────────────────────────────────────────────────────────────
#  Manifest
# ─────────────────────────────────────────────────────────────────────────────
$manifest = Import-PowerShellDataFile -Path $GameManifest
$DISPLAY_NAME = $manifest.DisplayName
$GAME_NAMES = $manifest.ProcessNames
$LAUNCH_TYPE = $manifest.LaunchType
$STEAM_GAME_ID = $manifest.SteamAppId
$EXE_PATH = $manifest.ExePath
$GAME_PRIORITY = if ($manifest.Priority) { $manifest.Priority } else { 'High' }
$manifestKey = [System.IO.Path]::GetFileNameWithoutExtension($GameManifest)
$STATE_FILE = "$env:TEMP\game-boost-state-$manifestKey.json"

# ─────────────────────────────────────────────────────────────────────────────
#  Constants shared across all games (OS/app hygiene, not game-specific)
# ─────────────────────────────────────────────────────────────────────────────

# Non-essential processes safe to kill for FPS
# Format: process name (without .exe) -> friendly display name
# These are confirmed non-system, user-space apps that consume CPU/RAM
$KILL_LIST = [ordered]@{
    # Browsers
    'chrome'             = 'Google Chrome'
    'msedge'             = 'Microsoft Edge'
    'firefox'            = 'Firefox'
    'opera'              = 'Opera'
    'brave'              = 'Brave Browser'
    'vivaldi'            = 'Vivaldi'

    # Communication
    'discord'            = 'Discord'
    'slack'              = 'Slack'
    'teams'              = 'Microsoft Teams'
    'ms-teams'           = 'MS Teams (new)'
    'skype'              = 'Skype'
    'zoom'               = 'Zoom'

    # Media
    'spotify'            = 'Spotify'
    'vlc'                = 'VLC'
    'aimp'               = 'AIMP'
    'musicbee'           = 'MusicBee'
    'foobar2000'         = 'foobar2000'

    # Cloud Sync
    'onedrive'           = 'OneDrive'
    'dropbox'            = 'Dropbox'
    'googledrivesync'    = 'Google Drive'
    'googledrive'        = 'Google Drive'
    'box'                = 'Box Sync'

    # Other game launchers / overlays
    'epicgameslauncher'  = 'Epic Games Launcher'
    'origin'             = 'EA Origin'
    'EADesktop'          = 'EA Desktop'
    'upc'                = 'Ubisoft Connect'
    'GalaxyClient'       = 'GOG Galaxy'
    'battlenet'          = 'Battle.net'

    # Office / Productivity
    'outlook'            = 'Outlook'
    'thunderbird'        = 'Thunderbird'
    'notion'             = 'Notion'
    'obsidian'           = 'Obsidian'

    # Adobe background daemons
    'AdobeUpdateService' = 'Adobe Updater'
    'AGSService'         = 'Adobe Genuine Service'
    'AdobeIPCBroker'     = 'Adobe IPC Broker'
    'node'               = 'Node.js (background)' # Careful - only if non-essential
}

# NEVER kill these — system-critical processes, plus this game's own processes
$PROTECTED = @(
    'System', 'Idle', 'csrss', 'smss', 'wininit', 'winlogon', 'services',
    'lsass', 'lsm', 'dwm', 'explorer', 'svchost', 'spoolsv', 'audiodg',
    'taskmgr', 'powershell', 'pwsh', 'cmd', 'conhost', 'steam', 'steamwebhelper'
) + $GAME_NAMES

# ─────────────────────────────────────────────────────────────────────────────
#  Helpers
# ─────────────────────────────────────────────────────────────────────────────
function Invoke-SelfElevation {
    if (-not (Test-IsAdmin)) {
        Write-Host "  Requesting administrator privileges..." -ForegroundColor Yellow
        $args_ = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-GameManifest', $GameManifest)
        if ($NoLaunch) { $args_ += '-NoLaunch' }
        if ($NoRestore) { $args_ += '-NoRestore' }
        if ($DryRun) { $args_ += '-DryRun' }
        if ($WhatIfPreference) { $args_ += '-WhatIf' }
        Start-Process pwsh -ArgumentList $args_ -Verb RunAs
        exit 0
    }
}

function Write-H([string]$title) {
    Write-Host ""
    Write-Host "  +==============================================================+" -ForegroundColor DarkCyan
    Write-Host "  |   $DISPLAY_NAME — GAME BOOST   " -NoNewline -ForegroundColor White
    Write-Host $title.PadRight(30) -NoNewline -ForegroundColor Gray
    Write-Host "|" -ForegroundColor DarkCyan
    Write-Host "  +==============================================================+" -ForegroundColor DarkCyan
    Write-Host ""
}

function Write-Ok([string]$msg) { Write-Host "  [+] $msg" -ForegroundColor Green }
function Write-Warn([string]$msg) { Write-Host "  [!] $msg" -ForegroundColor Yellow }
function Write-Err([string]$msg) { Write-Host "  [X] $msg" -ForegroundColor Red }
function Write-Info([string]$msg) { Write-Host "  ... $msg" -ForegroundColor Gray }
function Write-Dry([string]$msg) { Write-Host "  [DRY] $msg" -ForegroundColor Cyan }

function Get-PowerPlan {
    $line = (powercfg /getactivescheme 2>&1) -match 'GUID' | Select-Object -First 1
    if ($line -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
        return $matches[1]
    }
    return $null
}

function Format-MB([long]$bytes) {
    # Invariant culture: '-f' would render '1,0' on comma-decimal locales
    return "$(($bytes / 1MB).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)) MB"
}

function Get-GameProcess {
    foreach ($name in $GAME_NAMES) {
        $p = Get-Process -Name $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($p) { return $p }
    }
    return $null
}

function Start-Game {
    if ($LAUNCH_TYPE -eq 'Direct' -and $EXE_PATH) {
        Start-Process -FilePath $EXE_PATH
    }
    else {
        Start-Process "steam://rungameid/$STEAM_GAME_ID"
    }
}

# ─────────────────────────────────────────────────────────────────────────────
#  State save/load (for crash recovery)
# ─────────────────────────────────────────────────────────────────────────────
function Save-State([string]$powerPlan, [string[]]$killedProcesses) {
    # SECURITY: exe paths are NOT persisted — they live in-memory only.
    # Persisting paths to a world-writable TEMP file would allow path injection
    # executed with Administrator privileges on restore.
    $state = @{
        timestamp = (Get-Date -Format 'o')
        powerPlan = $powerPlan
        killed    = $killedProcesses   # names only, for display
    }
    $state | ConvertTo-Json -Depth 5 | Set-Content -Path $STATE_FILE -Encoding UTF8 -ErrorAction SilentlyContinue
    # Restrict file to current user only
    try {
        $acl = Get-Acl $STATE_FILE
        $acl.SetAccessRuleProtection($true, $false)
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            [System.Security.Principal.WindowsIdentity]::GetCurrent().Name,
            'FullControl', 'Allow')
        $acl.AddAccessRule($rule)
        Set-Acl $STATE_FILE $acl
    }
    catch { Write-Verbose "ACL hardening best-effort, skipped: $_" }
}

function Import-State {
    if (Test-Path $STATE_FILE) {
        return (Get-Content $STATE_FILE -Raw | ConvertFrom-Json)
    }
    return $null
}

function Clear-State {
    if (Test-Path $STATE_FILE) { Remove-Item $STATE_FILE -Force }
}

# ─────────────────────────────────────────────────────────────────────────────
#  Restore function (called on exit)
# ─────────────────────────────────────────────────────────────────────────────
function Restore-All([string]$originalPlan, [hashtable]$killedPaths, [switch]$dry) {
    Write-H "RESTORING"

    if ($originalPlan -and -not $dry) {
        Write-Info "Restoring power plan: $originalPlan"
        cmd.exe /c "powercfg /setactive $originalPlan" 2>&1 | Out-Null
        Write-Ok "Power plan restored to: $originalPlan"
    }
    elseif ($dry) {
        Write-Dry "Would restore power plan: $originalPlan"
    }

    # SECURITY: only restart processes using paths captured live in-memory this session.
    # Paths from the state file are NEVER used for execution to prevent injection attacks.
    if ($killedPaths -and $killedPaths.Count -gt 0) {
        Write-Info "Restarting $($killedPaths.Count) stopped process(es)..."
        foreach ($name in $killedPaths.Keys) {
            $path = $killedPaths[$name]
            if ($path -and (Test-Path $path)) {
                if ($dry) {
                    Write-Dry "Would restart: $name ($path)"
                }
                else {
                    try {
                        Start-Process -FilePath $path -ErrorAction SilentlyContinue
                        Write-Ok "Restarted: $name"
                    }
                    catch {
                        Write-Warn "Could not restart $name — launch it manually if needed"
                    }
                }
            }
            else {
                Write-Warn "Path not found for $name — skipping restart"
            }
        }
    }

    Clear-State
    Write-Ok "Restore complete."
}

# ─────────────────────────────────────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────────────────────────────────────
# Skip main when dot-sourced (e.g. by Pester tests) — the boost flow kills
# processes, switches power plans, launches the game, and blocks on Read-Host.
if ($MyInvocation.InvocationName -eq '.') { return }

Invoke-SelfElevation

Write-H "STARTING"
if ($DryRun) { Write-Warn "DRY RUN MODE — no changes will be made" }

# ── Check for existing state (previous run didn't clean up)
$existingState = Import-State
if ($existingState) {
    Write-Warn "Found state from a previous boost session ($(($existingState.timestamp)))."
    Write-Host "  [R] Restore previous session    [C] Continue new boost    [Q] Quit" -ForegroundColor White
    $choice = (Read-Host "  Choice").Trim().ToUpper()
    if ($choice -eq 'R') {
        $prevPlan = $existingState.powerPlan
        # SECURITY: exe paths from state file are never used for execution.
        # Crash recovery only restores the power plan; processes must be relaunched manually.
        Write-Warn "Note: process restart is not available after a crash (paths are not persisted for security)."
        Restore-All -originalPlan $prevPlan -killedPaths @{}
        exit 0
    }
    elseif ($choice -eq 'Q') { exit 0 }
    Clear-State
}

# ── 1. Capture current power plan
$originalPowerPlan = Get-PowerPlan
if ($originalPowerPlan) {
    Write-Ok "Current power plan saved: $originalPowerPlan"
}
else {
    Write-Warn "Could not read current power plan — won't be able to restore it"
}

# ── 2. Memory before
$memBefore = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory
Write-Info "Free RAM before: $(Format-MB ($memBefore * 1KB))"

# ── 3. Kill non-essential processes
Write-H "KILLING BACKGROUND PROCESSES"
$killedPaths = @{}
$killedCount = 0
$killedRamKB = 0L

foreach ($procName in $KILL_LIST.Keys) {
    if ($PROTECTED -contains $procName) { continue }

    $procs = Get-Process -Name $procName -ErrorAction SilentlyContinue
    if (-not $procs) { continue }

    $friendly = $KILL_LIST[$procName]
    foreach ($proc in $procs) {
        $ws = $proc.WorkingSet64
        $ramKB = if ($null -ne $ws) { [long]($ws / 1KB) } else { 0 }
        $killedRamKB += [long]$ramKB

        if ($DryRun) {
            Write-Dry "Would kill: $($proc.Name) (PID $($proc.Id)) — $(Format-MB ($ramKB * 1KB))"
        }
        else {
            # Capture executable path before killing
            $exePath = try { $proc.MainModule.FileName } catch { '' }
            if ($exePath -and -not $killedPaths.ContainsKey($procName)) {
                $killedPaths[$procName] = $exePath
            }

            try {
                $proc | Stop-Process -Force
                Write-Ok "Killed: $friendly ($(Format-MB ($ramKB * 1KB)))"
                $killedCount++
            }
            catch {
                Write-Warn "Could not kill $($proc.Name): $_"
            }
        }
    }
}

if ($killedCount -eq 0 -and -not $DryRun) {
    Write-Info "No non-essential processes found running."
}
if ($DryRun -and $killedCount -eq 0) {
    Write-Info "No processes from the kill list are running."
}

# ── 4. Set performance power plan
Write-H "POWER PLAN"
if ($DryRun) {
    Write-Dry "Would switch to Ultimate/High Performance power plan"
}
else {
    $planList = powercfg /list 2>&1
    $hasUltimate = $planList -match 'e9a42b02-d5df-448d-aa00-03f14749eb61'
    if ($hasUltimate) {
        cmd.exe /c 'powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61' | Out-Null
        Write-Ok "Ultimate Performance power plan activated"
    }
    else {
        cmd.exe /c 'powercfg /setactive scheme_min' | Out-Null
        Write-Ok "High Performance power plan activated"
    }
}

rundll32.exe advapi32.dll, ProcessIdleTasks

# ── 5. Set game process priority (if game already running)
$gameProc = Get-GameProcess
if ($gameProc) {
    Write-H "GAME PRIORITY"
    if ($DryRun) {
        Write-Dry "Would set $($gameProc.Name) priority to $GAME_PRIORITY"
    }
    else {
        try {
            $gameProc.PriorityClass = $GAME_PRIORITY
            Write-Ok "Game process '$($gameProc.Name)' priority -> $GAME_PRIORITY"
        }
        catch {
            Write-Warn "Could not set game priority: $_"
        }
    }
}

# ── 6. Trim all working sets
Write-H "MEMORY TRIM"
if ($DryRun) {
    Write-Dry "Would trim working sets of all processes and purge standby list"
}
else {
    Invoke-MemoryTrim -TypeName 'GameBoostMem'
    Start-Sleep -Milliseconds 500

    $memAfter = (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory
    $memFreed = ($memAfter - $memBefore) * 1KB
    Write-Ok "Free RAM after:  $(Format-MB ($memAfter * 1KB))  (+$(Format-MB $memFreed) freed)"
}

# ── 7. Save state for crash recovery
if (-not $DryRun) {
    Save-State -powerPlan $originalPowerPlan -killedProcesses @($killedPaths.Keys)
}

# ── Summary
Write-H "BOOST COMPLETE"
if (-not $DryRun) {
    Write-Ok "Killed $killedCount background process(es), freed ~$(Format-MB ($killedRamKB * 1KB)) RAM"
}
Write-Ok "Performance mode: ACTIVE"
Write-Ok "State saved to: $STATE_FILE"
Write-Host ""

# ── 8. Launch game (unless -NoLaunch or already running)
if (-not $NoLaunch -and -not $DryRun) {
    if ($gameProc) {
        Write-Info "Game already running (PID $($gameProc.Id)) — skipping launch"
    }
    else {
        Write-Info "Launching $DISPLAY_NAME..."
        Start-Game
        Write-Ok "Launch command sent"

        # Wait for game process to appear (up to 90 seconds)
        Write-Info "Waiting for game process..."
        $waited = 0
        while ($waited -lt 90) {
            Start-Sleep -Seconds 3
            $waited += 3
            $gameProc = Get-GameProcess
            if ($gameProc) {
                Write-Ok "Game detected: $($gameProc.Name) (PID $($gameProc.Id))"
                try { $gameProc.PriorityClass = $GAME_PRIORITY } catch { Write-Verbose "Game priority set failed: $_" }
                break
            }
        }
        if (-not $gameProc) {
            Write-Warn "Game did not start within 90 seconds. Is Steam running?"
        }
    }
}

# ── 9. Monitor + wait for game exit
if (-not $DryRun -and $gameProc) {
    Write-H "MONITORING"
    Write-Ok "Monitoring game... close this window to abort restore."
    Write-Host "  (Settings will be automatically restored when the game exits)" -ForegroundColor DarkGray
    Write-Host ""

    # Poll every 5 seconds; require 2 consecutive misses to guard against Steam respawn races
    $missCount = 0
    while ($true) {
        Start-Sleep -Seconds 5
        $still = Get-GameProcess
        if (-not $still) {
            $missCount++
            if ($missCount -ge 2) {
                Write-Ok "Game has exited."
                break
            }
            Write-Info "Game process not found (miss $missCount/2) — waiting to confirm..."
        }
        else {
            $missCount = 0  # reset on rediscovery (e.g. Steam respawn)
        }
    }

    # ── 10. Restore on exit
    if (-not $NoRestore) {
        Restore-All -originalPlan $originalPowerPlan -killedPaths $killedPaths
    }
    else {
        Write-Warn "-NoRestore flag set — skipping restore. Run start-optimized-game.ps1 again to undo manually."
        Clear-State
    }
}
elseif ($DryRun) {
    Write-Dry "Would monitor for game exit and restore on close"
    Write-Dry "Restore: power plan -> $originalPowerPlan, restart $($KILL_LIST.Count) candidate processes"
}
else {
    # Game not running and -NoLaunch, or launch failed
    if (-not $NoRestore) {
        Write-Warn "Game not detected — restoring settings now."
        Restore-All -originalPlan $originalPowerPlan -killedPaths $killedPaths
    }
}

Write-Host ""
Write-Host "  Done. Press Enter to close." -ForegroundColor DarkGray
$null = Read-Host
