# Deploy-Configs

**Category:** Deployment / Dotbot
**Scope:** Apply tracked configuration files

## Synopsis

Deploy dotfiles using dotbot with hash-based change detection. Runs the canonical bootstrap or targeted config groups.

## Description

This command wraps `dotbot` and `Scripts/Setup-Dotfiles.ps1` to apply configuration changes. It supports:

- **Full deployment** — runs `dotbot -c install.conf.yaml` (default)
- **Targeted deployment** — deploys specific config groups (`-Target 'PowerShell profile'`)
- **Dry-run** — shows what would change without modifying files (`-WhatIf`)
- **Verbose** — detailed dotbot output (`-VerboseOutput`)

Deployment uses SHA256 hash comparison; files are copied only when source differs from destination.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-WhatIf` | Switch | False | Show what would change (dry-run) |
| `-VerboseOutput` | Switch | False | Enable verbose dotbot output |
| `-Target` | String[] | Empty | Deploy only specific config groups |
| `-SkipWingetTools` | Switch | False | Skip winget package installation |
| `-SkipWSL` | Switch | False | Skip WSL2 configuration |

## Usage

```powershell
# Deploy all dotfiles
.\Deploy-Configs.ps1

# Dry-run: see what would change
.\Deploy-Configs.ps1 -WhatIf

# Deploy only PowerShell profile
.\Deploy-Configs.ps1 -Target 'PowerShell profile'

# Deploy with verbose output
.\Deploy-Configs.ps1 -VerboseOutput

# Deploy without installing winget packages
.\Deploy-Configs.ps1 -SkipWingetTools
```

## How It Works

1. Resolves repository root from script location
2. Validates `install.conf.yaml` exists
3. With `-Target`: calls `Scripts/Setup-Dotfiles.ps1 -Target <...>`
4. Without `-Target`: runs `dotbot -c install.conf.yaml`
5. Reports success/failure with colored status

## Related Files

- `install.conf.yaml` — dotbot manifest
- `Scripts/Setup-Dotfiles.ps1` — deployment driver
- `user/.dotfiles/config/` — tracked configuration source

## Notes

- The actual script is `Scripts/Deploy-Configs.ps1` for local use.
- This `.md` reference describes the workflow for Kilo agents.
