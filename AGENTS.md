# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# AGENTS.md — AI Assistant Guide

> **Note for agents**: This file is authoritative. `CLAUDE.md` is a symlink to this file. When updating documentation, edit `AGENTS.md` only.

## Repository Overview

A **Windows dotfiles and optimization suite** managed with [yadm](https://yadm.io/). Contains PowerShell scripts, system configuration, and gaming/performance tweaks designed to be synced across Windows machines.

**Stack:** yadm · PowerShell 5.1+/7+ · Windows Terminal · Registry tweaks · winget

**Primary use cases:**
1. Windows system optimization and gaming performance
2. Dotfile synchronization across Windows machines
3. Automated Windows environment setup (NVIDIA GPU, display, network)

---

## Repository Structure

```
Win/
├── .github/
│   ├── copilot-instructions.md    # GitHub Copilot global instructions
│   ├── instructions/              # Per-language Copilot instruction files
│   │   ├── powershell.instructions.md
│   │   ├── cmd.instructions.md
│   │   ├── autohotkey.instructions.md
│   │   └── context-engineering.instructions.md
│   ├── workflows/                 # CI: PSScriptAnalyzer, PSMinifier
│   └── dependabot.yml
├── .yadm/
│   └── bootstrap                  # Post-clone setup script (PowerShell)
├── Scripts/                       # Main PowerShell scripts
│   ├── Common.ps1                 # ← Shared utility module (import always)
│   ├── gaming-display.ps1         # FSO, MPO, display tweaks
│   ├── edid-manager.ps1           # EDID override management
│   ├── gpu-display-manager.ps1    # GPU/display settings
│   ├── steam.ps1                  # Steam optimization
│   ├── shader-cache.ps1           # Shader cache management
│   ├── DLSS-force-latest.ps1      # DLSS version forcing
│   ├── Network-Tweaker.ps1        # Network optimizations
│   ├── debloat-windows.ps1
│   ├── system-settings-manager.ps1
│   ├── system-maintenance.ps1
│   ├── UltimateDiskCleanup.ps1
│   ├── Clean-SpotifyCache.ps1        # Spotify cache cleaner
│   ├── shell-setup.ps1
│   ├── arc-raiders/               # Arc Raiders utilities
│   ├── Hostbuilder/               # Hosts file management
│   ├── minify-ps1/                # PSMinifier module
│   ├── win-iso/                   # Windows ISO creation
│   └── reg/                       # Registry .reg files
├── user/.dotfiles/config/         # Active configuration files (NOT .config/)
│   ├── powershell/profile.ps1     # Main PowerShell profile
│   ├── windows-terminal/          # Terminal settings
│   ├── games/                     # Per-game configs (bf2, bo6, bo7, arc-raiders)
│   ├── nvidia/                    # NVIDIA inspector/performance scripts
│   ├── bleachbit/cleaners/        # BleachBit custom cleaners
│   └── ...
├── .claude/skills/                # Claude Code skill definitions
├── AGENTS.md                      # This file
├── CLAUDE.md                      # Symlink → AGENTS.md
├── README.md                      # User-facing documentation
├── setup.ps1                      # Main system setup script
└── renovate.json                  # Renovate bot config
```

**Deprecated:** `.config/` — use `user/.dotfiles/config/` instead.

---

## PowerShell Conventions

### Style (enforced by `.editorconfig` and PSScriptAnalyzer CI)

```powershell
# OTBS braces, 2-space indent, spaces around operators/pipes
function Enable-Feature {
  param(
    [Parameter(Mandatory)]
    [string]$Name
  )

  Set-StrictMode -Version Latest
  $ErrorActionPreference = "Stop"

  if ($condition) {
    $result = $value1 + $value2
    Get-Process | Where-Object { $_.Name -eq 'pwsh' }
  }
}

# Comment-based help on all functions
<#
.SYNOPSIS
    Brief description
.DESCRIPTION
    Detailed description
.PARAMETER Name
    Parameter description
.EXAMPLE
    Enable-Feature -Name "test"
#>
```

### File naming

| Type | Convention |
|------|-----------|
| PowerShell scripts | `lowercase-with-dashes.ps1` |
| Batch files | `lowercase-with-dashes.cmd` |
| Docs (important) | `UPPERCASE.md` |
| Config files | Follow application convention |

### Line endings and encoding

- Default: `CRLF` (Windows)
- Charset: `UTF-8` (PowerShell: UTF-8 with BOM)
- Trailing whitespace trimmed (except Markdown)

---

## Common.ps1 — Shared Module

**Always import and use these instead of duplicating logic:**

```powershell
#Requires -RunAsAdministrator
. "$PSScriptRoot\Common.ps1"

# Admin elevation
Request-AdminElevation

# UI
Initialize-ConsoleUI -Title "Script Name"
Show-Menu -Title "Menu Title" -Options @("Option 1", "Option 2")
$choice = Get-MenuChoice -Min 1 -Max 2

# Registry
Set-RegistryValue -Path "HKLM\..." -Name "Value" -Type "REG_DWORD" -Data "1"
Remove-RegistryValue -Path "HKLM\..." -Name "Value"
$gpuPaths = Get-NvidiaGpuRegistryPaths

# File operations
Get-FileFromWeb -URL "https://..." -File "C:\path\to\file"
Clear-DirectorySafe -Path "C:\path\to\clear"   # Uses robocopy internally

# VDF parsing (Steam)
$data = ConvertFrom-VDF -Content (Get-Content "file.vdf")
ConvertTo-VDF -Data $hashtable | Out-File "file.vdf"
```

### Standard script pattern

```powershell
#Requires -RunAsAdministrator
. "$PSScriptRoot\Common.ps1"

Request-AdminElevation
Initialize-ConsoleUI -Title "Script Title (Administrator)"

function Enable-Feature { <# ... #> }
function Disable-Feature { <# ... #> }
function Show-Status { <# ... #> }

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

---

## CMD/Batch Conventions

```batch
@echo off
setlocal enabledelayedexpansion
setlocal enableextensions
```

- Variables: `set "name=value"` — use `!var!` (not `%var%`) inside code blocks
- Subroutines: `call :label` / `exit /b 0`
- Error checks: `if errorlevel 1` or `command && echo OK || echo FAIL`
- Always `setlocal` to avoid polluting the environment

---

## AutoHotkey v2 Conventions

Target AHK **v2.x only** (no v1 syntax). Every script must begin:

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
SetWorkingDir A_ScriptDir
```

- Naming: functions `PascalCase()`, locals `camelCase`, constants `UPPER_SNAKE_CASE`, globals `g_` prefix
- Use `WinWait*` over `Sleep`; `SetTimer()` over tight loops
- No hardcoded drive letters; use `A_ScriptDir` for relative paths
- Admin elevation via `RequireAdmin()` from `AHK_Common.ahk`

---

## yadm Workflow

yadm is a **git wrapper** operating on `$HOME`. Commands are identical to git:

```powershell
yadm status          # Check tracked dotfiles
yadm diff            # View changes
yadm add <file>      # Stage file
yadm commit -m "..."
yadm push / pull

yadm ls-files        # List all tracked files
```

**For this repo (git, not yadm):**

```powershell
git status
git add Scripts/new-script.ps1
git commit -m "feat: Add new-script.ps1"
git push -u origin <branch>
```

---

## Common Tasks

### Adding a new PowerShell script

```powershell
# 1. Create in Scripts/
# 2. Add header:
#Requires -RunAsAdministrator
. "$PSScriptRoot\Common.ps1"
Request-AdminElevation
Initialize-ConsoleUI -Title "My Script (Administrator)"

# 3. Implement using Common.ps1 functions
# 4. Commit
git add Scripts/new-script.ps1
git commit -m "feat: Add new-script.ps1 for [purpose]"
```

### Modifying the PowerShell profile

Active profile: `user/.dotfiles/config/powershell/profile.ps1`

Machine-specific overrides: `user/.dotfiles/config/powershell/local.ps1` (gitignored)

### Registry tweaks

```powershell
Set-RegistryValue -Path "HKLM\SOFTWARE\..." -Name "Feature" -Type "REG_DWORD" -Data "1"
Remove-RegistryValue -Path "HKLM\SOFTWARE\..." -Name "Feature"
```

---

## DO's and DON'Ts

### ✅ DO

- Use `Common.ps1` functions — never duplicate code
- Follow OTBS style, 2-space indent, comment-based help
- Check admin: `Request-AdminElevation`
- Use `$PSScriptRoot`, `$HOME` — never hardcode paths
- Run `Invoke-ScriptAnalyzer` before committing
- Store configs in `user/.dotfiles/config/`
- Write descriptive commit messages (`feat:`, `fix:`, `docs:`, etc.)
- Update `README.md` for user-facing changes, `AGENTS.md` for structural changes

### ❌ DON'T

- Use `.config/` directory (deprecated)
- Commit sensitive data — check `.gitignore`
- Use tabs (use 2 spaces)
- Hardcode paths
- Duplicate code — extract to `Common.ps1` if used twice
- Skip error handling for unexpected failures
- Set `$ErrorActionPreference = "SilentlyContinue"` globally
- Use `Invoke-Expression` with untrusted input

---

## Testing

```powershell
# Syntax/lint
Invoke-ScriptAnalyzer -Path Scripts/your-script.ps1

# Unit tests (Pester — files named *.Tests.ps1)
Invoke-Pester -Path Scripts/

# Run as admin
PowerShell.exe -ExecutionPolicy Bypass -File Scripts/your-script.ps1

# Verify registry change
Get-ItemProperty -Path "HKLM\..."   # before and after
```

CI runs PSScriptAnalyzer on every push/PR via `.github/workflows/powershell.yml`.
PSMinifier also runs on push and auto-commits minified output — do not manually minify scripts.

---

## Git Commit Format

```
<type>: <subject>

<body (optional)>
```

Types: `feat` · `fix` · `docs` · `refactor` · `style` · `chore`

---

## Bootstrap Process (new machine)

```powershell
winget install yadm
yadm clone https://github.com/Ven0m0/Win.git
yadm bootstrap             # full setup — no manual steps
yadm bootstrap -- -WhatIf  # preview all planned actions without applying
```

Bootstrap runs `Scripts/Setup-Dotfiles.ps1` which: sets execution policy, installs dev tools via winget, deploys config files (PS profile, Windows Terminal, BleachBit cleaners), adds Scripts to PATH, and creates standard directories. Re-running is safe — configs are skipped if already up to date (SHA256 comparison).

`setup.ps1` (repo root) is a separate comprehensive Windows setup script — software installation, system optimization, bloatware removal, and privacy tweaks. Run directly as admin, not via bootstrap.

---

## Security

**Never commit:**
- `.gitconfig.local`, `.gitconfig` with real email
- `.ssh/` (except `config`)
- `powershell/local.ps1`
- Anything matching `.gitignore`

**Script safety:** All scripts are open-source, require explicit user confirmation, and include "restore defaults" options for registry changes.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Running scripts is disabled" | Run `Scripts\allow-scripts.cmd` or `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| `Common.ps1` not found | Ensure `Common.ps1` is in the same directory as the script |
| Registry changes not applying | Check: running as admin? Correct HKLM vs HKCU? Restart needed? |
| yadm not found | `winget install yadm`, restart terminal |

---

## Key Paths

```powershell
$PROFILE                              # PowerShell profile
$HOME\Scripts                         # Scripts directory
user\.dotfiles\config\powershell\     # PowerShell config
user\.dotfiles\config\windows-terminal\  # Terminal config
user\.dotfiles\config\nvidia\         # NVIDIA inspector/performance config
Scripts\Common.ps1                    # Shared utilities module
```

---

**Repository:** https://github.com/Ven0m0/Win
**Maintainer:** Ven0m0
**Last Updated:** 2026-03-25

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:ca08a54f -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

## Session Completion

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd dolt push
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds
<!-- END BEADS INTEGRATION -->
