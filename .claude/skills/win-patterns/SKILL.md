---
name: win-patterns
description: Coding patterns and conventions extracted from the Win dotfiles repository. Covers commit style, PowerShell script structure, file organization, and CI behavior. Load when writing scripts, commits, or docs for this repo.
version: 1.0.0
source: local-git-analysis
analyzed_commits: 200
user-invocable: false
---

# Win Repository Patterns

Extracted from 200 commits. Use these patterns for all work in this repository.

## Commit Conventions

Two styles are used — prefer conventional commits for code changes:

```
feat: add new-script.ps1 for GPU monitoring
fix: harden bootstrap path handling (#52)
chore: remove non-deployable clutter from Scripts/
docs: update AGENTS.md with yadm workflow
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
│   ├── *.Tests.ps1             # Pester tests — co-located with scripts
│   ├── reg/                    # Registry .reg files
│   ├── Hostbuilder/            # Hosts file management tool
│   ├── minify-ps1/             # PSMinifier module (CI uses this)
│   └── win-iso/                # Windows ISO creation
├── user/.dotfiles/config/      # Active config files (NOT .config/ — deprecated)
│   ├── powershell/profile.ps1  # Main PS profile (frequently changed)
│   ├── nvidia/                 # NVIDIA inspector/performance scripts
│   └── games/                  # Per-game configs
├── setup.ps1                   # Main entry point (most-changed file in repo)
├── AGENTS.md                   # Authoritative AI guide (CLAUDE.md symlinks here)
└── .github/workflows/          # CI: PSScriptAnalyzer + PSMinifier
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
New-QueryString -Parameters @{...}              # URL query strings
New-RestorePoint                                # before registry changes
ConvertFrom-VDF / ConvertTo-VDF                 # Steam VDF parsing
```

## CI Behavior

- **PSScriptAnalyzer** runs on every push/PR — fix all warnings before committing
- **PSMinifier** auto-runs on push and commits minified output — do not manually minify
- Run locally before committing: `Invoke-ScriptAnalyzer -Path Scripts/your-script.ps1`

## Testing

Test files are named `*.Tests.ps1` and co-located in `Scripts/`:

```powershell
# Proper Pester format (see system-maintenance.Tests.ps1)
Describe "Function-Name" {
  BeforeAll { . "$PSScriptRoot\script.ps1" }
  It "describes behavior" {
    { Function-Name -Param "value" } | Should -Throw "expected message"
  }
}
```

Run: `Invoke-Pester -Path Scripts/ -Output Minimal`

## Config File Location

- Active configs: `user/.dotfiles/config/` — **not** `.config/` (deprecated)
- Machine-specific PS overrides: `user/.dotfiles/config/powershell/local.ps1` (gitignored)
- Edit `AGENTS.md` for structural/AI changes; `README.md` for user-facing changes

## What Never to Commit

`.gitconfig` with real email · `.ssh/` keys · `powershell/local.ps1` · anything in `.gitignore`
