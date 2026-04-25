# Bootstrap Redesign: Remove yadm, Integrate install.ps1

**Date:** 2026-04-24
**Status:** Approved

## Summary

Replace yadm with a plain `git clone` to `$HOME\.win`, restructure `install.ps1` as a
proper PowerShell script, and wire the full pipeline into `bootstrap.ps1` so a single
internet one-liner performs a complete clean Windows install end-to-end.

## Goals

- Remove yadm dependency (poor Windows support)
- Clone repo to `$HOME\.win` via plain git
- Single one-liner triggers: clone → config deploy → full app install → reboot → WSL
- `stage2.ps1` self-cleans its scheduled task on completion
- `-Unattended` and `-SkipWSL` thread through the entire chain

## Non-Goals

- Resume/state-file tracking (winget handles already-installed packages gracefully)
- Restructuring `user/.dotfiles/config/` layout
- Changing `Setup-Dotfiles.ps1` deploy logic

## Pipeline Flow

```
iwr .../bootstrap.ps1 | iex
  │
  ├─ 1. Self-elevate to admin
  ├─ 2. Install Git via winget (if missing)
  ├─ 3. git clone Win.git → $HOME\.win
  ├─ 4. Scripts\Setup-Dotfiles.ps1   (deploy configs, PATH, core tools — unchanged)
  ├─ 5. Scripts\auto\install.ps1     (packages, DISM features, Windows Update)
  │       └─ registers scheduled task → Scripts\auto\stage2.ps1
  │       └─ reboots
  │
  └─ [after reboot] stage2.ps1
          ├─ WSL install + set default version 2
          ├─ winget: WSL, Ubuntu, WSLManager
          └─ schtasks /delete /tn "post-reboot" /f  (self-cleanup)
```

## File Changes

### `.github/scripts/bootstrap.ps1` — major rewrite

- Remove: winget install of yadm, `yadm clone`, `yadm pull` fallback
- Add: `git clone https://github.com/Ven0m0/Win.git "$HOME\.win"` (with pull fallback if `.win` already exists)
- Add: call `Scripts\Setup-Dotfiles.ps1` from `$HOME\.win`
- Add: call `Scripts\auto\install.ps1` from `$HOME\.win`
- Keep: `-Unattended`, `-SkipWSL` params; thread both to install.ps1
- Keep: self-elevation pattern, Write-Info/Ok/Fail/Warn helpers

### `Scripts\auto\install.ps1` — restructure

- Add: `.SYNOPSIS` comment-based help
- Add: `param([switch]$Unattended, [switch]$SkipWSL)`
- Add: `Set-StrictMode -Version Latest`, `$ErrorActionPreference = 'Continue'`
- Add: admin self-elevation check
- Add: phase banners (`Write-Host '[1/N] ...'`)
- Fix: scheduled task path `C:\setup\stage2.ps1` → `"$HOME\.win\Scripts\auto\stage2.ps1"`
- Fix: scheduled task command `powershell` → `pwsh` (PS7), fallback to `powershell` if pwsh not found
- Fix: pass `-SkipWSL` arg through scheduled task if set
- Keep: all winget, DISM, WU, topgrade, sfc/dism commands

### `Scripts\auto\stage2.ps1` — expand

- Add: `.SYNOPSIS` comment-based help
- Add: `param([switch]$SkipWSL)`
- Add: self-elevation check
- Add: `Write-Host` phase output per command
- Add: per-command error handling (warn on failure, don't abort)
- Add: self-cleanup at end: `schtasks /delete /tn "post-reboot" /f`
- Keep: WSL install, set-default-version 2, winget WSL/Ubuntu/WSLManager

### `.yadm\bootstrap` — de-yadm

- Replace yadm-specific bootstrap logic with direct call:
  `pwsh "$HOME\.win\Scripts\Setup-Dotfiles.ps1" @args`
- Keeps file functional as a fallback entry point without requiring yadm

## Params Threading

| Flag | bootstrap.ps1 | install.ps1 | stage2.ps1 |
|---|---|---|---|
| `-Unattended` | accepts | forwarded | — |
| `-SkipWSL` | accepts | forwarded → scheduled task args | accepts |

## Git Workflow

Before committing: `git pull --rebase origin main` to merge remote updates.

## Validation Checklist

- [ ] `pwsh -Command "[System.Management.Automation.ScriptBlock]::Create((gc bootstrap.ps1 -Raw))"` — no syntax errors
- [ ] Same check for `install.ps1` and `stage2.ps1`
- [ ] `bootstrap.ps1` contains no references to `yadm`
- [ ] Scheduled task path resolves correctly on a fresh machine (`$HOME` expands at registration time)
- [ ] `-Unattended` suppresses all `Read-Host` prompts end-to-end
- [ ] stage2 scheduled task is absent after `stage2.ps1` completes
