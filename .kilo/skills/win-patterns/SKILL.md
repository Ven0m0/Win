---
name: win-patterns
description: Coding patterns and conventions extracted from the Win dotfiles repository. Covers commit style, PowerShell script structure, file organization, CI behavior, and issue tracking. Load when writing scripts, commits, or docs for this repo.
version: 1.1.0
source: local-git-analysis
analyzed_commits: 200+
user-invocable: false
---

# Win Repository Patterns

Extracted from 200+ commits. Use these patterns for all work in this repository.

## Commit Conventions

Two styles are used — prefer conventional commits for code changes:

```
feat: add new-script.ps1 for GPU monitoring
fix: harden bootstrap path handling (#52)
chore: remove non-deployable clutter from Scripts/
docs: update AGENTS.md with dotbot workflow
perf: consolidate redundant WMI queries in Network-Tweaker.ps1
refactor: extract registry helpers to Common.ps1
```

Emoji prefixes appear on automated/PR commits — do not use them manually:
- `🧪` tests · `⚡` performance · `🧹` cleanup · `🔒` security

PR merges append `(#N)`: `fix: harden bootstrap (#52)`

**Never** use bare GitHub-style messages (`Update README.md`, `Create config.json`) for code changes.

## Repository Structure

```
Win/
├── Scripts/                    # PowerShell scripts (hot — 60% of all changes)
│   ├── Common.ps1              # Shared module — always import, never duplicate
│   ├── *.ps1                   # Scripts: lowercase-with-dashes
│   ├── reg/                    # Registry .reg files
│   ├── arc-raiders/            # Game-specific optimization scripts
│   └── auto/                   # Unattended Windows setup XML
├── user/.dotfiles/config/      # Active config files (NOT .config/ — deprecated)
│   ├── powershell/profile.ps1  # Main PS profile (frequently changed)
│   ├── nvidia/                 # NVIDIA inspector/performance scripts
│   └── games/                  # Per-game configs
├── tests/                      # Pester tests
├── setup.ps1                   # Main entry point (most-changed file in repo)
├── AGENTS.md                   # Authoritative AI guide (CLAUDE.md symlinks here)
└── .github/workflows/          # CI: PSScriptAnalyzer + Pester
```

## PowerShell Script Pattern

Every new script in `Scripts/` must follow this structure:

```powershell
#Requires -RunAsAdministrator
. "$PSScriptRoot\Common.ps1"

Request-AdminElevation
Initialize-ConsoleUI -Title "Script Name (Administrator)"

function Enable-Feature {
  <#
  .SYNOPSIS
      Brief description
  .PARAMETER Name
      Parameter description
  .EXAMPLE
      Enable-Feature -Name "test"
  #>
  param(
    [Parameter(Mandatory)]
    [string]$Name
  )
  # implementation using Common.ps1 functions
}

while ($true) {
  Show-Menu -Title "Script Menu" -Options @("Enable", "Disable", "Status", "Exit")
  $choice = Get-MenuChoice -Min 1 -Max 4
  switch ($choice) {
    1 { Enable-Feature }
    2 { Disable-Feature }
    3 { Show-Status }
    4 { exit }
  }
  Read-Host "`nPress Enter to continue"
}
```

Key rules:
- OTBS braces, 2-space indent
- `$PSScriptRoot` for all relative paths — never hardcode drive letters
- `$env:SystemRoot`, `$env:TEMP`, `$env:LOCALAPPDATA` — never `C:\Windows\...`
- Use `Common.ps1` functions: `Set-RegistryValue`, `Get-FileFromWeb`, `Clear-DirectorySafe`
- Check `$LASTEXITCODE` after `reg.exe`, `netsh`, `powercfg`, `sc.exe` calls
- No global `$ErrorActionPreference = 'SilentlyContinue'` — use `-ErrorAction SilentlyContinue` per call

## Common.ps1 — Always Use These

```powershell
Request-AdminElevation                          # elevation check
Initialize-ConsoleUI -Title "..."               # console setup
Show-Menu / Get-MenuChoice                      # menus
Set-RegistryValue / Remove-RegistryValue        # registry ops
Get-NvidiaGpuRegistryPaths                      # NVIDIA paths
Get-FileFromWeb -URL "..." -File "..."          # downloads
Clear-DirectorySafe -Path "..."                 # safe directory clear
ConvertFrom-VDF / ConvertTo-VDF                 # Steam VDF parsing
```

## CI Behavior

- **PSScriptAnalyzer** runs on every push/PR — fix all warnings before committing
- **Pester** tests run on Windows latest
- Run locally before committing: `Invoke-ScriptAnalyzer -Path Scripts/your-script.ps1`

## Testing

Test files are named `*.Tests.ps1` and located in `tests/`:

```powershell
# Proper Pester format
Describe "Function-Name" {
  BeforeAll { . "$PSScriptRoot\script.ps1" }
  It "describes behavior" {
    { Function-Name -Param "value" } | Should -Throw "expected message"
  }
}
```

Run: `Invoke-Pester -Path tests/ -Output Minimal`

## Config File Location

- Active configs: `user/.dotfiles/config/` — **not** `.config/` (deprecated)
- Machine-specific PS overrides: `user/.dotfiles/config/powershell/local.ps1` (gitignored)
- Edit `AGENTS.md` for structural/AI changes; `README.md` for user-facing changes

## Performance Patterns

```powershell
# BAD: O(N^2) array concatenation
$results = @()
foreach ($item in $collection) { $results += $item }

# GOOD: List[T] accumulation
$results = [System.Collections.Generic.List[string]]::new()
foreach ($item in $collection) { $results.Add($item) }

# BAD: nested Where-Object pipelines
$data | Where-Object { $_.Prop -eq $val } | Where-Object { $_.Other -gt 0 }

# GOOD: combine conditions
$data | Where-Object { $_.Prop -eq $val -and $_.Other -gt 0 }
```

## Workflow: Bootstrap / Setup Changes

When changing setup/bootstrap, these three files **always change together**:

```
install.conf.yaml
AGENTS.md
Scripts/Setup-Dotfiles.ps1
```

## Workflow: Arc Raiders Game Config

Arc Raiders scripts and configs **always change together** — update all when any changes:

```
Scripts/arc-raiders/ARCRaidersUtility.ps1
Scripts/arc-raiders/cleanup-arc-raiders.ps1
Scripts/arc-raiders/game-boost.ps1
Scripts/arc-raiders/start-arc-raiders.ps1
Scripts/arc-raiders/SkipVideosMod.ps1
user/.dotfiles/config/games/arc-raiders/Engine.ini
user/.dotfiles/config/games/arc-raiders/GameUserSettings.ini
user/.dotfiles/config/games/arc-raiders/Input.ini
AGENTS.md  (when adding new game support)
```

## What Never to Commit

`.gitconfig` with real email · `.ssh/` keys · `powershell/local.ps1` · anything in `.gitignore`