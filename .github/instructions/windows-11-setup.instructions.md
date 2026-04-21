---
applyTo: "**/Setup-Win11.ps1,**/bootstrap.ps1,**/Setup-Dotfiles.ps1"
---

# Windows 11 Setup Instructions

These instructions apply to Windows 11-specific setup and bootstrap scripts.

## Fresh Windows 11 Install Path

A clean Windows 11 installation can be fully automated with a single command:

```powershell
iwr https://raw.githubusercontent.com/Ven0m0/Win/main/.github/scripts/bootstrap.ps1 -UseBasicParsing | iex
```

This script performs a complete hands-free setup:

1. **Elevates to administrator** automatically
2. **Installs winget** (Windows Package Manager) if not present
3. **Installs core tools**: Git, PowerShell 7+, yadm (via winget)
4. **Clones the repository** using yadm
5. **Runs the repository bootstrap** (deploys configs, sets up PATH, etc.)
6. **Offers WSL2 installation** (can be skipped with `-SkipWSL`)

### Unattended Mode

For fully automated deployments (CI, imaging, etc.):

```powershell
# Download and run with no prompts
iwr https://raw.githubusercontent.com/Ven0m0/Win/main/.github/scripts/bootstrap.ps1 -UseBasicParsing | iex -Unattended
```

The `-Unattended` flag:
- Skips all user prompts
- Accepts all default options
- Suppresses optional features (uses safe defaults)

### Advanced Flags

| Flag | Description |
|------|-------------|
| `-Unattended` | Non-interactive mode; no prompts |
| `-SkipWSL` | Skip WSL2 installation offer |
| `-SkipWingetTools` | Skip winget-based tool installation |
| `-Force` | Re-run setup even if already configured |

## Local Setup (Already Cloned)

If you've already cloned the repository manually:

```powershell
# Run the local bootstrap script
pwsh $HOME\.yadm\bootstrap [-Unattended] [-SkipWingetTools]
```

Arguments are forwarded to `Scripts/Setup-Dotfiles.ps1`:

| Parameter | Effect |
|-----------|--------|
| `-Unattended` | Non-interactive mode |
| `-SkipWingetTools` | Skip tool installation phase |
| `-SkipWSL` | Ignored locally (reserved for future) |

## Setup Flow

```
bootstrap.ps1 (download & run)
    ↓
Check winget → Install winget (if needed)
    ↓
Install Git, PowerShell 7, yadm via winget
    ↓
yadm clone https://github.com/Ven0m0/Win.git
    ↓
.yadm/bootstrap → Scripts/Setup-Dotfiles.ps1
    ↓
Phase 1: Set execution policy (RemoteSigned)
Phase 2: Install tools via winget (Git, PS7, WT, VSCode, yadm)
Phase 3: Deploy config files (PowerShell profile, Win Terminal, Firefox, etc.)
Phase 4: Configure PATH, create directories
Phase 5: Verification summary
```

## Repository Conventions

- **Bootstrap entry points**: `.yadm/bootstrap` (yadm-managed) and `bootstrap.ps1` (standalone)
- **Main setup logic**: `Scripts/Setup-Dotfiles.ps1`
- **Shared utilities**: `Scripts/Common.ps1`
- **Config deployment**: Manifest-driven in `Setup-Dotfiles.ps1` with hash-based change detection
- **Tool installation**: Uses `winget` with `--silent --accept-*` flags for non-interactive installs

## Validation Checklist

After running setup:

- [ ] PowerShell profile exists at `$PROFILE`
- [ ] Windows Terminal settings applied
- [ ] Scripts directory (`~/Scripts`) is in PATH
- [ ] Execution policy set to `RemoteSigned` (CurrentUser scope)
- [ ] Core tools available: `git`, `pwsh`, `code`, `wt`
- [ ] yadm status shows clean repo

If any check fails, review the console output for errors and re-run with `-WhatIf` first to preview changes.
