# AGENTS.md — AI Assistant Guide

> `CLAUDE.md` must remain a symlink to this file. Update `AGENTS.md`, not `CLAUDE.md`.

## Repository Identity

This repository is a **Windows dotfiles and optimization suite** managed with [yadm](https://yadm.io/). It contains PowerShell automation, Windows configuration, registry tweaks, and game/performance tuning assets intended to be synchronized across Windows machines.

**Primary stack:** yadm, PowerShell 5.1+/7+, CMD/Batch, AutoHotkey v2, registry files, Windows Terminal, winget.

## Critical Rules

- Reuse `Scripts/Common.ps1` for shared PowerShell behavior. Do not duplicate its helpers.
- Store active configuration under `user/.dotfiles/config/`. Do not add new content under deprecated `.config/` paths.
- Preserve Windows compatibility and existing PowerShell 5.1+/7+ support.
- Use relative and environment-based paths such as `$PSScriptRoot`, `$HOME`, `$env:*`, and `A_ScriptDir`; do not hardcode machine-specific paths.
- Registry and system tweaks should support reverting or restoring defaults where practical.
- Follow the file-type guidance in `.github/instructions/` for PowerShell, CMD/Batch, AutoHotkey, and general context rules.
- Update `README.md` for user-facing behavior changes and `AGENTS.md` for AI workflow or repository-structure changes.

## Key Paths

| Path | Purpose |
| --- | --- |
| `AGENTS.md` | Authoritative AI guide for the repository |
| `CLAUDE.md` | Symlink to `AGENTS.md` |
| `.github/copilot-instructions.md` | Short repository-wide Copilot instructions |
| `.github/instructions/` | Path-specific guidance applied by file type |
| `.github/workflows/` | CI workflows, including PSScriptAnalyzer |
| `.yadm/bootstrap` | yadm bootstrap entry point |
| `setup.ps1` | Main standalone Windows setup script |
| `Scripts/` | Main PowerShell and Windows automation scripts |
| `Scripts/Common.ps1` | Shared PowerShell helpers; reuse instead of reimplementing |
| `Scripts/reg/` | Registry `.reg` assets |
| `user/.dotfiles/config/` | Active yadm-managed config files |
| `user/.dotfiles/config/powershell/profile.ps1` | Main PowerShell profile |
| `user/.dotfiles/config/windows-terminal/` | Windows Terminal configuration |
| `user/.dotfiles/config/nvidia/` | NVIDIA-related config and helper files |
| `user/.dotfiles/config/games/` | Per-game configuration assets |

## Working in This Repository

### PowerShell changes

- Scripts in `Scripts/` should follow the established admin/elevation pattern and import `Scripts/Common.ps1`.
- Prefer existing helpers such as registry, UI, download, cleanup, restore-point, and VDF utilities before adding new functions.
- Use comment-based help on public functions and keep style aligned with `.editorconfig` and `.github/instructions/powershell.instructions.md`.
- Avoid global `$ErrorActionPreference = "SilentlyContinue"` and avoid `Invoke-Expression` with untrusted input.

### Registry and system tweaks

- Prefer helper functions like `Set-RegistryValue`, `Remove-RegistryValue`, and `Get-NvidiaGpuRegistryPaths` from `Scripts/Common.ps1`.
- Support both enable/apply and disable/restore flows when changing user-visible system behavior.
- Keep NVIDIA-related registry work scoped to discovered device paths rather than hardcoded instances.

### Config updates

- Keep tracked config files in `user/.dotfiles/config/` and preserve application-native file formats.
- Use `user/.dotfiles/config/powershell/local.ps1` only for machine-local overrides; do not commit it.

### Bootstrap and setup changes

These areas are tightly related and should be reviewed together when one changes:

- `.yadm/bootstrap`
- `Scripts/Setup-Dotfiles.ps1`
- `AGENTS.md`
- `README.md` when user-facing setup behavior changes

## Language-Specific Notes

### PowerShell

- Use OTBS braces, 2-space indentation, and spaces around operators and pipes.
- Set `Set-StrictMode -Version Latest` and `$ErrorActionPreference = "Stop"` within scripts and functions where appropriate.
- Prefer `Common.ps1` helpers over new one-off utilities.
- File names should follow `lowercase-with-dashes.ps1` when introducing new scripts.

### CMD/Batch

- Use `@echo off`, `setlocal enabledelayedexpansion`, and `setlocal enableextensions`.
- Use `set "name=value"` style assignment and `!var!` inside blocks.

### AutoHotkey v2

- Target AutoHotkey v2 only.
- Start scripts with `#Requires AutoHotkey v2.0`, `#SingleInstance Force`, `SendMode "Input"`, and `SetWorkingDir A_ScriptDir`.
- Use repo-relative paths and existing shared helpers where available.

## Validation and CI

### Local validation

Use the smallest relevant validation for the change:

```powershell
Invoke-ScriptAnalyzer -Path Scripts/your-script.ps1
Invoke-Pester -Path Scripts/ -Output Minimal
```

- Run `Invoke-ScriptAnalyzer` for changed PowerShell files.
- Use Pester when tests already exist for the affected area or when adding new testable PowerShell logic.
- For documentation-only changes, validation is usually limited to reviewing the rendered diff.

### CI behavior

- `.github/workflows/powershell.yml` runs PSScriptAnalyzer on push and pull request events.
- The current workflow is focused on the `PSAvoidGlobalAliases` and `PSAvoidUsingConvertToSecureStringWithPlainText` rules.
- PSMinifier automation exists in the repository; do not manually minify scripts unless a workflow explicitly requires generated output updates.

## Git and yadm

- Use **git** for repository files and pull requests.
- Use **yadm** for synced home-directory dotfiles behavior.
- Commit messages should follow `<type>: <subject>`.
- Common types in this repo include `feat`, `fix`, `docs`, `refactor`, `style`, `chore`, and `perf`.

Examples:

```text
feat: add new-script.ps1 for GPU monitoring
fix: harden bootstrap path handling
chore: remove non-deployable clutter from Scripts/
docs: update AGENTS.md with repo workflow guidance
```

## Security and Sensitive Files

Never commit:

- credentials or tokens
- `.ssh/` private keys
- `.gitconfig` with a real email address if it is machine-specific
- `user/.dotfiles/config/powershell/local.ps1`
- any other file already excluded by `.gitignore`

Also avoid:

- hardcoded local machine paths
- `Invoke-Expression` with untrusted input
- silently swallowing system-command failures that should be surfaced

## Common Commands

```powershell
git status
git diff
Invoke-ScriptAnalyzer -Path Scripts/your-script.ps1
yadm status
yadm diff
yadm bootstrap -- -WhatIf
```

## Task Tracking

This repository uses **bd (beads)** for task tracking.

```bash
bd prime
bd ready
bd show <id>
bd update <id> --claim
bd close <id>
```

Rules:

- Use `bd` for repository task tracking instead of ad-hoc markdown TODO lists.
- Use `bd remember` for durable project knowledge.
- Respect repository hooks and automation under `.beads/` when present.

## Session Completion Expectations

When finishing code changes:

1. Run the relevant validation for the modified area.
2. Update task status for completed and follow-up work.
3. Ensure all intended files are committed and pushed through the approved workflow.
4. Leave the working tree in a clear handoff state.

## Reference

- `README.md` covers user-facing setup and usage.
- `.github/copilot-instructions.md` contains the short repository-wide Copilot guidance.
- `.github/instructions/` contains file-type-specific instruction files.
