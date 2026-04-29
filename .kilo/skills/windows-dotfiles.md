---
name: win-dotfiles
description: Specialized for Windows dotfiles
compatibility: opencode
---

# Windows Dotfiles Skill

Load this skill for any task involving PowerShell scripts, Windows optimization, dotfile deployment, or repo guidance in the Ven0m0/Win project.

## Repository Identity

**Ven0m0/Win** — Windows dotfiles and optimization suite. Centers on PowerShell automation, tracked application config, registry tweaks, and game-specific tuning.

**Primary stack:** PowerShell 5.1+/7+, CMD/Batch, AutoHotkey v2, registry files, Windows Terminal, winget, dotbot.

**Three-layer bootstrap:**
1. Internet bootstrap (`.github/scripts/bootstrap.ps1`) — one-command entry; self-elevates, installs prereqs, clones repo
2. Repo bootstrap (`install.conf.yaml` → `Scripts/Setup-Dotfiles.ps1`) — installs packages, deploys configs by hash, configures PATH
3. Unattended USB install (`Scripts/auto/autounattend.xml`) — self-contained XML; `ExtractScript` embeds all scripts

## Hotspots

- `Scripts/` — PowerShell automation surface
- `Scripts/Common.ps1` — shared helper library (reuse first)
- `Scripts/auto/autounattend.xml` — unattended Windows 11 USB installer
- `user/.dotfiles/config/` — tracked dotfile content (deployed by SHA256 hash)
- `install.conf.yaml` — dotbot entry point (delegates to `Scripts/Setup-Dotfiles.ps1`)
- `.github/` — Copilot guidance (`copilot-instructions.md`), instructions, skills
- `AGENTS.md` — canonical repo-wide AI assistant guide

## PowerShell Script Conventions

- Use `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'` in standalone scripts
- Follow existing admin elevation pattern: `Request-AdminElevation` from `Common.ps1`
- OTBS braces, 2-space indentation, full cmdlet names
- Prefer environment-based paths: `$PSScriptRoot`, `$HOME`, `$env:*`, `$env:LOCALAPPDATA`, `A_ScriptDir`
- Comment-based help for public functions and entry-point scripts
- Use `SupportsShouldProcess` for system-changing operations
- Avoid global `$ErrorActionPreference = 'SilentlyContinue'`, avoid `Invoke-Expression`
- CI runs `Invoke-ScriptAnalyzer` enforcing `PSAvoidGlobalAliases` and `PSAvoidUsingConvertToSecureStringWithPlainText`

## Shared Helpers (Scripts/Common.ps1)

Prefer these over new utilities:
- Registry: `Set-RegistryValue`, `Remove-RegistryValue`, `Get-NvidiaGpuRegistryPaths`
- System: `New-RestorePoint`
- Downloads/temp: safe directory cleanup, VDF parsing
- GPU: device-path discovery (no hardcoded instances)

## Config Deployment

- Keep tracked config under `user/.dotfiles/config/`
- Preserve native file format and existing directory layout
- Deployment uses SHA256 hash comparison; copies only when content differs
- Machine-local overrides belong in untracked local profile loaded from user's home dotfiles directory

## autounattend.xml Rules

- **Fully self-contained**: All setup scripts embedded via `ExtractScript` inside `<Extensions>` block
- **USB deploy**: copy only `autounattend.xml` to USB root — Windows Setup auto-detects
- **DO NOT** add flat `.ps1` or `.cmd` files alongside the XML; they become stale duplicates
- XML entity encoding: `&amp;` for `&`, `&gt;` for `>`, etc.; `ExtractScript` uses `.InnerText` so extracted `.ps1` has correct syntax
- Execution flow: specialize → FirstLogon → `install.ps1` (winget, Windows Update, reboot) → `stage2.ps1` (WSL) → WinUtil RunOnce
- Validate after any edit: `$xml = [xml]::new(); $xml.Load('Scripts/auto/autounattend.xml')`

## Validation Checklist

- Changed PowerShell file: `Invoke-ScriptAnalyzer -Path <script> -Settings ./PSScriptAnalyzerSettings.psd1`
- Bootstrap changes: review `install.conf.yaml`, `Scripts/Setup-Dotfiles.ps1`, `README.md`, `AGENTS.md` together
- autounattend.xml edit: validate XML loads
- Guidance/workflow changes under `.github/`: verify all referenced paths/commands exist, run `npx -y @yawlabs/ctxlint --depth 3 --mcp --strict --yes`

## Git & Commits

- Commit messages: `<type>: <subject>` (types: feat, fix, docs, refactor, style, chore, perf)
- Use git for repo changes, dotbot for dotfile deployment
- Never commit credentials, tokens, private keys, or machine-specific local overrides
- Avoid hardcoded local paths; don't silently swallow system-command failures

## Reference Files

- `README.md` — user-facing setup and usage
- `.github/copilot-instructions.md` — short startup guide
- `.github/skills/win-patterns/SKILL.md` — recurring repo workflows
- `.github/instructions/powershell.instructions.md` — PowerShell-specific rules
- `.github/instructions/windows-11-setup.instructions.md` — Win11 setup rules
