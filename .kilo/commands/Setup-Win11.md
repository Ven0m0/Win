# Setup-Win11

**Category:** Bootstrap / Fresh Install
**Scope:** One-command Windows 11 setup workflow

## Synopsis

Complete fresh Windows 11 setup: installs prerequisites (winget, Git, PowerShell 7), clones the dotfiles repository, runs dotbot bootstrap, and optionally installs WSL2.

## Description

This is the canonical one-command entry point for a fresh Windows 11 installation. It performs a three-layer bootstrap:

1. **Prerequisites** — Detects and installs winget (if missing), Git, PowerShell 7+
2. **Repository** — Clones `https://github.com/Ven0m0/Win.git` to `$HOME\Win` (or pulls if already exists)
3. **Bootstrap** — Runs `dotbot -c install.conf.yaml` to deploy all configs
4. **Optional WSL2** — Installs WSL2 with no distribution (user installs distro later)

The script self-elevates to administrator and supports unattended mode (`-Unattended`) for zero-prompt deployments.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Unattended` | Switch | False | Skip all prompts, accept all defaults |
| `-Force` | Switch | False | Re-run setup even if already configured (re-clones repo) |
| `-SkipWingetTools` | Switch | False | Skip tool installation via winget (use existing) |
| `-SkipWSL` | Switch | False | Skip WSL2 installation/configuration |

## Usage

```powershell
# Interactive (prompts where needed)
.\Setup-Win11.ps1

# Fully automated (no prompts)
.\Setup-Win11.ps1 -Unattended -Force

# Skip WSL but otherwise complete setup
.\Setup-Win11.ps1 -SkipWSL
```

**Local machine manual run** (already cloned):
```powershell
cd $HOME\Win
pwsh -File Scripts\Setup-Win11.ps1
```

**One-liner from internet** (downloads and runs bootstrap):
```powershell
iwr https://raw.githubusercontent.com/Ven0m0/Win/main/.github/scripts/bootstrap.ps1 -UseBasicParsing | iex
```

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Prerequisite installation failed |
| `2` | Git clone/pull failed |
| `3` | Dotbot bootstrap failed |

## Notes

- Actual `.kilo/commands/Setup-Win11.ps1` exists in `Scripts/` for local execution; this markdown file serves as Kilo command reference only.
- See `AGENTS.md` and `.github/skills/win-patterns/SKILL.md` for repo conventions.
- Validation: run `.\Validate-Changes.ps1` after modifying this script.

## Related

- `Scripts/Setup-Win11.ps1` — executable implementation
- `Scripts/shell-setup.ps1` — prerequisite installer
- `install.conf.yaml` — dotbot configuration
- `.github/scripts/bootstrap.ps1` — internet bootstrap variant
