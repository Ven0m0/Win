---
name: bootstrap-deployment
description: |
  Three-layer bootstrap flow, dotbot patterns, and deployment order for Win dotfiles.
  Use when editing bootstrap.ps1, install.conf.yaml, or Setup-Dotfiles.ps1.
compatibility: opencode
---

# Bootstrap & Deployment Skill

Use this skill when working on the Ven0m0/Win bootstrap flow: `bootstrap.ps1`, `Setup-Dotfiles.ps1`, `install.conf.yaml`, or any deployment-related automation.

## Bootstrap Overview (Three Layers)

1. **Internet bootstrap** — `.github/scripts/bootstrap.ps1`
   - One-command entry point (fresh Windows 11)
   - Self-elevates to admin
   - Installs prerequisites: winget, Git, PowerShell 7+, Python, dotbot
   - Clones repo, then delegates to repo bootstrap
   - Supports `-Unattended` (no prompts) and `-SkipWSL`

2. **Repo bootstrap** — `install.conf.yaml` → `Scripts/Setup-Dotfiles.ps1`
   - Phase 1: Set execution policy `RemoteSigned` (CurrentUser)
   - Phase 2: Install tools via winget (Git, PS7, Windows Terminal, VSCode)
   - Phase 3: Deploy config files (PowerShell profile, Win Terminal, Firefox, Brave, CMD, games, NVIDIA)
   - Phase 4: Configure PATH, create directories (`~/Scripts`, `~/bin`, etc.)
   - Phase 5: Verification summary
   - Uses SHA256 hash comparison; copies only when content differs

3. **Unattended USB install** — `Scripts/auto/autounattend.xml`
   - Fully self-contained; no companion scripts alongside
   - Embedded scripts via `ExtractScript`
   - Runs: specialize → FirstLogon → `install.ps1` → `stage2.ps1` → WinUtil

## Key Files to Review Together

When any bootstrap file changes, review these together:

| Changed File | Must Also Check |
|---|---|
| `install.conf.yaml` | `Scripts/Setup-Dotfiles.ps1`, `README.md`, `AGENTS.md` |
| `Scripts/Setup-Dotfiles.ps1` | `install.conf.yaml`, affected configs under `user/.dotfiles/config/` |
| `.github/scripts/bootstrap.ps1` | `install.conf.yaml`, repo README instructions |
| `README.md` (setup sections) | `install.conf.yaml`, `Scripts/Setup-Dotfiles.ps1`, bootstrap.ps1 |

## dotbot Configuration Patterns

- `install.conf.yaml` uses dotbot's YAML manifest format
- Each config group specifies `- ~/.dotfiles/config/<source>` → `<dest>` mapping with conditional `if` (platform, test)
- Deployment is **hash-based** (`Get-FileHash -Algorithm SHA256`) — never symlinks (Windows compatibility)
- Template files use `##template` suffix; user copies to destination and customizes
- Example: `.gitconfig##template` → `$HOME\.gitconfig`

## Setup-Dotfiles.ps1 Responsibilities

- `Invoke-Expression` and global `SilentlyContinue` — avoid
- Use helpers from `Scripts/Common.ps1` when available
- PATH updates go to `$env:USERPROFILE\AppData\Local\Microsoft\WindowsApps` (or user Scripts dir)
- Directory creation: `~/Scripts`, `~/bin`, game-specific folders
- Package installation via `winget` with `--silent --accept-source-agreements --accept-package-agreements`
- Single config groups can be deployed: `pwsh -File Scripts/Setup-Dotfiles.ps1 -Target 'PowerShell profile' -SkipWingetTools`

## winget Package Management

- Use `winget install --id <PackageId> --silent --accept-source-agreements --accept-package-agreements`
- Idempotent checks: `if (-not (Get-Command <tool> -ErrorAction SilentlyContinue)) { install }`
- Do not hardcode versions unless explicitly pinned
- Failures should be surfaced (no global ` SilentlyContinue`)

## Post-Deploy Verification

After bootstrap completes:
1. PowerShell profile exists at `$PROFILE` and loads
2. Windows Terminal settings applied at `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`
3. `~/Scripts` directory exists and is in PATH (if configured)
4. Execution policy: `Get-ExecutionPolicy -Scope CurrentUser` returns `RemoteSigned`
5. Core tools available: `git`, `pwsh`, `code`, `wt`
6. `git status` in repo shows clean working tree
7. For WSL: `wsl --status` reports WSL2 installed and default version set

## Unattended & Flags

- `-Unattended`: skip all prompts, accept defaults
- `-Force`: re-run setup even if already configured (re-clones if repo exists)
- `-SkipWingetTools`: skip package installation phase
- `-SkipWSL`: skip WSL2 offer

## Common Pitfalls

- **Scripts won't run**: execute `Scripts/allow-scripts.ps1` as admin first
- **dotbot missing**: `pip install dotbot` or `mise install dotbot`
- **Config not applied**: verify destination folder exists before copying; dotbot only copies when hash differs
- **autounattend duplication**: never keep flat `.ps1` beside `autounattend.xml`; embed all scripts inside XML
- **Path errors**: use `$PSScriptRoot`, `$HOME`, `$env:LOCALAPPDATA`, never hardcoded `C:\Users\...`

## Command Reference

```powershell
# Full bootstrap (installs dotbot then deploys)
mise run bootstrap
# or
pip install dotbot && dotbot -c install.conf.yaml

# Deploy all dotfiles only (dotbot must be installed)
mise run deploy

# Deploy single config group
pwsh -File Scripts/Setup-Dotfiles.ps1 -Target 'PowerShell profile' -SkipWingetTools

# Validate autounattend.xml
$xml = [xml]::new(); $xml.Load("$PWD\Scripts\auto\autounstand.xml")

# Lint changed PowerShell script
Invoke-ScriptAnalyzer -Path Scripts/<changed>.ps1 -Settings PSScriptAnalyzerSettings.psd1
```

## Related Skills

- `windows-dotfiles.md` — general PowerShell coding conventions, Common.ps1 helpers
- `validation.md` — detailed per-change-type validation matrix
