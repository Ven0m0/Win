# Set-ExecutionPolicySafe

**Category:** Security / PowerShell
**Scope:** Execution policy management with repo-aware defaults

## Synopsis

Manage PowerShell execution policy safely for the repository context. Supports get, set, and reset with scope awareness (CurrentUser vs LocalMachine).

## Description

PowerShell's execution policy controls script execution. This wrapper:

- Sets `RemoteSigned` (recommended for dotfiles) at `CurrentUser` scope (no admin needed)
- Supports `AllSigned`, `Restricted`, `Unrestricted`, `Undefined`
- Shows current policies across all scopes
- Resets to defaults (`Undefined` at CurrentUser)

No admin required for `CurrentUser` scope; `LocalMachine` requires elevation.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Policy` | String | `'RemoteSigned'` | Policy to set: RemoteSigned, AllSigned, Restricted, Unrestricted, Undefined |
| `-Scope` | String | `'CurrentUser'` | Scope: CurrentUser (no admin) or LocalMachine (admin required) |
| `-Get` | Switch | False | Display current execution policies for all scopes |
| `-Reset` | Switch | False | Reset to default (Undefined at CurrentUser) |

## Usage

```powershell
# Set RemoteSigned at CurrentUser (recommended)
.\Set-ExecutionPolicySafe.ps1

# Set AllSigned at machine level (admin)
.\Set-ExecutionPolicySafe.ps1 -Policy AllSigned -Scope LocalMachine

# View current policies
.\Set-ExecutionPolicySafe.ps1 -Get

# Reset to system defaults
.\Set-ExecutionPolicySafe.ps1 -Reset
```

## Policy Meanings

| Policy | Effect |
|--------|--------|
| `RemoteSigned` | Local scripts run; downloaded scripts require signature (recommended) |
| `AllSigned` | All scripts require digital signature |
| `Restricted` | No scripts allowed (only interactive) |
| `Unrestricted` | All scripts run with warning prompt |
| `Undefined` | Inherits from parent scope (default) |

## Notes

- Actual script: `Scripts/Set-ExecutionPolicySafe.ps1`
- This `.md` is Kilo command reference.
- Repository scripts require at least `RemoteSigned` at `CurrentUser` or `LocalMachine`.
- After setting policy, verify: `Get-ExecutionPolicy -List`

## Related

- `Scripts/allow-scripts.ps1` — repository-specific script enablement
- `Setup-Win11.ps1` — auto-sets policy during bootstrap
- `AGENTS.md` — PowerShell security rules
