---
applyTo: "**/Setup-Win11.ps1,**/bootstrap.ps1,**/Setup-Dotfiles.ps1"
---

# Windows 11 Setup Instructions

These instructions apply to Windows 11-specific setup and bootstrap scripts.

## Unattended USB Install (Scripts/auto/)

`Scripts/auto/autounattend.xml` provides a fully unattended Windows 11 install from USB:

1. Copy `autounattend.xml` to the **root of the USB drive** — that is the only file required.
2. Boot from the USB. Windows Setup detects the file and runs fully unattended.
3. All setup scripts are **embedded inside the XML** via the `ExtractScript` mechanism and extracted to `C:\Windows\Setup\Scripts\` during the specialize pass.

**Do not** add flat `.ps1` or `.cmd` files alongside the XML in `Scripts/auto/`; they become stale duplicates.

**Install sequence after first boot:**
- `FirstLogon.ps1` → calls `install.ps1` (winget packages, Windows Update, reboot)
- `stage2.ps1` (scheduled task on next logon) → WSL/Ubuntu, then sets WinUtil RunOnce
- Next logon → WinUtil opens for final tweaks (Win11 Creator compatible)

**Validate the XML** after any edit:
```powershell
$xml = [xml]::new(); $xml.Load('Scripts/auto/autounattend.xml')
```

**WinUtil Win11 Creator**: use any USB creation tool (WinUtil, Rufus, Ventoy), then copy `autounattend.xml` to the USB root to replace the generated answer file.

## Fresh Windows 11 Install Path

A clean Windows 11 installation can be fully automated with a single command:

```powershell
iwr https://raw.githubusercontent.com/Ven0m0/Win/main/.github/scripts/bootstrap.ps1 -UseBasicParsing | iex
```

This script performs a complete hands-free setup:

1. **Elevates to administrator** automatically
2. **Installs winget** (Windows Package Manager) if not present
3. **Installs core tools**: Git, PowerShell 7+ (via winget)
4. **Clones the repository** using git
5. **Runs the repository bootstrap** (deploys configs via dotbot, sets up PATH, etc.)
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
pwsh $HOME\Scripts\Setup-Dotfiles.ps1 [-Unattended] [-SkipWingetTools]
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
Install Git, PowerShell 7 via winget
    ↓
git clone https://github.com/Ven0m0/Win.git
    ↓
install.conf.yaml (dotbot) → Scripts/Setup-Dotfiles.ps1
    ↓
Phase 1: Set execution policy (RemoteSigned)
Phase 2: Install tools via winget (Git, PS7, WT, VSCode)
Phase 3: Deploy config files (PowerShell profile, Win Terminal, Firefox, etc.)
Phase 4: Configure PATH, create directories
Phase 5: Verification summary
```

## Repository Conventions

- **Bootstrap entry points**: `install.conf.yaml` (dotbot config) and `bootstrap.ps1` (standalone)
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
- [ ] Git status shows clean repo

If any check fails, review the console output for errors and re-run with `-WhatIf` first to preview changes.
