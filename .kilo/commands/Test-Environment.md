# Test-Environment

**Category:** Diagnostics / Readiness
**Scope:** Verify system meets repository requirements

## Synopsis

Check that the local environment satisfies all prerequisites for running the Ven0m0/Win dotfiles: required tools, execution policy, repository structure, OS version, and network connectivity.

## Description

Runs a battery of checks:

- **Core Tools** — PowerShell 5.1+/7+, winget, Git, Python (optional but needed for dotbot), dotbot
- **Security** — execution policy (RemoteSigned recommended)
- **Repository** — `install.conf.yaml`, `Scripts/Setup-Dotfiles.ps1`, `user/.dotfiles/config/` exist
- **System** — Windows 10 1909+ or Windows 11, optional admin rights check
- **Network** — GitHub connectivity, winget source availability (optional)

Outputs PASS/FAIL per check with actionable install hints.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-FixIssues` | Switch | False | Attempt automatic fixes (install dotbot, set policy) |
| `-SkipNetwork` | Switch | False | Skip network-dependent checks |
| `-Detailed` | Switch | False | Show verbose details for all checks |

## Usage

```powershell
# Run all readiness checks
.\Test-Environment.ps1

# Show detailed output
.\Test-Environment.ps1 -Detailed

# Auto-fix common issues (install dotbot, set policy)
.\Test-Environment.ps1 -FixIssues

# Skip network checks (offline)
.\Test-Environment.ps1 -SkipNetwork
```

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | All required checks passed |
| `1` | One or more required checks failed |

## Notes

- Real script: `Scripts/Test-Environment.ps1`
- This `.md` is Kilo command reference.
- Use before initial setup or after cloning to a new machine.
- Failed checks include installation hints (e.g., "winget install Git.Git").

## Related

- `Setup-Win11.ps1` — full automated setup
- `Deploy-Configs.ps1` — apply configs after environment is ready
- `Set-ExecutionPolicySafe.ps1` — fix policy issues
