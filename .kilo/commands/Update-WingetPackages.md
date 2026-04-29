# Update-WingetPackages

**Category:** Package Management
**Scope:** Bulk update winget-installed software

## Synopsis

Update all winget-installed packages to latest versions with selective exclusion and dry-run capability.

## Description

This command queries `winget upgrade` for upgradable packages, filters out excluded items and Microsoft Store (unless opted in), and performs bulk upgrades with silent mode. Provides a summary of successes and failures.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-WhatIf` | Switch | False | Show which packages would be upgraded without changing anything |
| `-IncludeMicrosoftStore` | Switch | False | Also update Microsoft Store apps (requires Store sign-in) |
| `-Exclude` | String[] | Empty | Package IDs to skip (e.g., `'Git.Git','Microsoft.PowerShell'`) |
| `-DryRunOnly` | Switch | False | List upgradable packages but do not install |

## Usage

```powershell
# Check and upgrade all upgradable packages
.\Update-WingetPackages.ps1

# Preview only (no changes)
.\Update-WingetPackages.ps1 -WhatIf

# Exclude specific packages from update
.\Update-WingetPackages.ps1 -Exclude 'Git.Git','Microsoft.WindowsTerminal'

# Include Microsoft Store apps
.\Update-WingetPackages.ps1 -IncludeMicrosoftStore

# Just list what's upgradable
.\Update-WingetPackages.ps1 -DryRunOnly
```

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | All upgrades succeeded |
| `1` | One or more package upgrades failed |

## Notes

- Actual script: `Scripts/Update-WingetPackages.ps1`
- This markdown is Kilo command reference only.
- Requires `winget` to be installed and configured.

## Related

- `Scripts/Install-Packages.ps1` — initial package installation
- `Setup-Dotfiles.ps1` — also installs tools via winget during bootstrap
