# AGENTS.md — AI Assistant Guide

> `CLAUDE.md` must remain a symlink to this file. Update `AGENTS.md`, not `CLAUDE.md`.

## Repository Identity

Ven0m0/Win is a Windows dotfiles and optimization suite. It centers on PowerShell automation, tracked application config, registry tweaks, and game-specific tuning assets.

**Primary stack:** PowerShell 5.1+/7+, CMD/Batch, AutoHotkey v2, registry files, Windows Terminal, winget, dotbot.

## Architecture

Three-layer bootstrap:

1. **Internet bootstrap** (`.github/scripts/bootstrap.ps1`) — one-command entry point; self-elevates, installs prereqs (winget, Git, pwsh, Python, dotbot), clones repo, then delegates to the repo bootstrap.
2. **Repo bootstrap** (`install.conf.yaml` → `Scripts/Setup-Dotfiles.ps1`) — installs winget packages, deploys config files using SHA256 hash comparison (copies only when content differs), configures PATH, creates directories.
3. **Unattended USB install** (`Scripts/auto/autounattend.xml`) — fully self-contained XML; copy to USB root and Windows Setup auto-detects it. Scripts are embedded via `ExtractScript` and extracted to `C:\Windows\Setup\Scripts\` at runtime; no companion flat files belong alongside the XML.

Config files live in `user/.dotfiles/config/` and are deployed by hash (no symlinks), which preserves Windows compatibility without admin rights.

## Commands

```powershell
# Lint a changed PowerShell file
Invoke-ScriptAnalyzer -Path Scripts\<changed>.ps1 -Settings PSScriptAnalyzerSettings.psd1

# Validate autounattend.xml (PowerShell)
$xml = [xml]::new(); $xml.Load("$PWD\Scripts\auto\autounattend.xml")

# Deploy all dotfiles to their real Windows paths (dotbot must be installed)
mise run deploy          # or: dotbot -c install.conf.yaml

# Deploy a single config group (no dotbot needed)
pwsh -File Scripts/Setup-Dotfiles.ps1 -Target 'PowerShell profile' -SkipWingetTools -SkipWSL
# Available targets: 'PowerShell profile', 'Windows Terminal settings', 'BleachBit cleaners',
#   'Firefox user.js', 'Brave policies', 'CMD aliases',
#   'Star Wars Battlefront II (2017) configs', 'Call of Duty Black Ops 6 configs',
#   'Call of Duty Black Ops 7 configs', 'NVIDIA assets'

# Full bootstrap (installs dotbot then deploys all)
mise run bootstrap       # or: pip install dotbot && dotbot -c install.conf.yaml

# One-command fresh Windows 11 install
iwr https://raw.githubusercontent.com/Ven0m0/Win/main/.github/scripts/bootstrap.ps1 -UseBasicParsing | iex
```

CI runs `PSScriptAnalyzer` on all PowerShell changes (`.github/workflows/powershell.yml`), enforcing `PSAvoidGlobalAliases` and `PSAvoidUsingConvertToSecureStringWithPlainText`.

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
- `install.conf.yaml` is the dotbot configuration; it delegates to `Scripts/Setup-Dotfiles.ps1`.
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

- `install.conf.yaml`
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

- Use git for repo changes and dotbot for dotfile deployment.
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
