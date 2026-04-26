# AGENTS.md — AI Assistant Guide

> `CLAUDE.md` must remain a symlink to this file. Update `AGENTS.md`, not `CLAUDE.md`.

## Repository Identity

Ven0m0/Win is a Windows dotfiles and optimization suite managed with [yadm](https://yadm.io/). It centers on PowerShell automation, tracked application config, registry tweaks, and game-specific tuning assets.

**Primary stack:** yadm, PowerShell 5.1+/7+, CMD/Batch, AutoHotkey v2, registry files, Windows Terminal, winget.

## High-signal rules

- Reuse `Scripts/Common.ps1` for shared PowerShell behavior.
- Keep tracked configuration under `user/.dotfiles/config/`.
- Preserve Windows compatibility and existing PowerShell 5.1+/7+ support.
- Use environment-based paths such as `$PSScriptRoot`, `$HOME`, `$env:*`, and `A_ScriptDir`.
- Prefer reversible registry and system changes.
- Keep startup guidance short in `.github/copilot-instructions.md`, repo-wide guidance here, and narrow task flows in `.github/skills/`.

## Main repo areas

- `Scripts/` contains the main PowerShell automation surface.
- `Scripts/Common.ps1` is the shared helper library.
- `Scripts/auto/autounattend.xml` is the self-contained unattended Windows 11 USB installer. All setup scripts are embedded inside the XML via `ExtractScript`; no companion flat files belong alongside it.
- `user/.dotfiles/config/` contains tracked dotfile content.
- `.yadm/bootstrap` is the bootstrap entry point and delegates to `Scripts/Setup-Dotfiles.ps1`.
- `.github/instructions/` and `.github/skills/` hold Copilot-facing guidance.

## Change guidance

### PowerShell

- Follow the existing admin elevation and console setup patterns already used in `Scripts/`.
- Prefer helpers in `Scripts/Common.ps1` before adding new utilities.
- Use comment-based help for public functions.
- Avoid global `$ErrorActionPreference = 'SilentlyContinue'` and avoid `Invoke-Expression` with untrusted input.

### Registry and system tweaks

- Use shared helpers such as `Set-RegistryValue`, `Remove-RegistryValue`, `Get-NvidiaGpuRegistryPaths`, and `New-RestorePoint` when they fit.
- Support both apply and restore behavior when changing user-visible settings.
- Keep GPU-specific registry work scoped to discovered device paths rather than hardcoded instances.

### Config updates

- Preserve each application's native file format and existing directory layout under `user/.dotfiles/config/`.
- Machine-local PowerShell overrides belong in the untracked local profile that `user/.dotfiles/config/powershell/profile.ps1` loads from the user's home dotfiles directory.

### Bootstrap changes

Review these files together whenever one changes:

- `.yadm/bootstrap`
- `Scripts/Setup-Dotfiles.ps1`
- `README.md`
- guidance files that describe bootstrap behavior

### AI guidance changes

- Keep `.github/copilot-instructions.md` short and startup-focused.
- Put reusable repo workflows in `.github/skills/`.
- Put language or topic rules in `.github/instructions/`.
- For deeper repo conventions, load `.github/skills/win-patterns/SKILL.md`.

## Validation

Use the smallest relevant checks:

- Changed PowerShell files: `Invoke-ScriptAnalyzer -Path <changed-script>`
- Guidance and workflow changes under `.github/`: verify every referenced path and command exists, then run the repository context lint check
- Use Pester only when the affected area already has tests or when you add new testable PowerShell logic.

Current CI:

- `.github/workflows/powershell.yml` runs PSScriptAnalyzer.
- CI currently enforces `PSAvoidGlobalAliases` and `PSAvoidUsingConvertToSecureStringWithPlainText`.

## Git

- Use git for repo changes and yadm for synced home-directory behavior.
- Commit messages follow `<type>: <subject>`.
- Common types: `feat`, `fix`, `docs`, `refactor`, `style`, `chore`, and `perf`.

## Sensitive content

Never commit credentials, tokens, private keys, or machine-specific local overrides.
Avoid hardcoded local machine paths and avoid silently swallowing system-command failures that should be surfaced.

## Reference

- `README.md` covers user-facing setup and usage.
- `.github/copilot-instructions.md` is the short startup guide.
- `.github/skills/win-patterns/SKILL.md` captures recurring repo workflows.
- `.github/instructions/` contains path- and language-specific rules.
