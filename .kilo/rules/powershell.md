# PowerShell Rules for Ven0m0/Win

These rules apply to all PowerShell files in this repository: `Scripts/**/*.ps1`, `*.psm1`, `*.psd1`, and setup scripts.

## Required Practices

- Use `Set-StrictMode -Version Latest` and `$ErrorActionPreference = 'Stop'` in standalone scripts
- Use `[CmdletBinding()]` and `SupportsShouldProcess` for functions that modify system state
- Provide comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`)
- Use full cmdlet names (no aliases like `select`, `%`, `?`, `cd`)
- Validate parameters with `[ValidateNotNullOrEmpty()]`, `[ValidateSet()]`, or custom validation
- Check exit codes/bool results on external commands (`reg.exe`, `winget`, `git`, `wsl`)
- Prefer `Write-Verbose`, `Write-Warning`, `Write-Error` over `Write-Host` for non-UI output

## Prohibited Patterns

- ❌ Global `$ErrorActionPreference = 'SilentlyContinue'` (hides failures)
- ❌ `Invoke-Expression` with untrusted or variable-derived input (security risk)
- ❌ `ConvertTo-SecureString` with plaintext key material (CI violation: `PSAvoidUsingConvertToSecureStringWithPlainText`)
- ❌ Global aliases in script/module scope (CI violation: `PSAvoidGlobalAliases`)
- ❌ Hardcoded user paths like `C:\Users\Ven0m0\...` — use `$HOME`, `$env:USERPROFILE`, `$PSScriptRoot`

## Path and Environment

- Use `$PSScriptRoot` for script-relative paths
- Use `$HOME` or `$env:USERPROFILE` for user home
- Use `$env:LOCALAPPDATA`, `$env:APPDATA`, `$env:PROGRAMDATA` for app data locations
- Use `[Environment]::GetFolderPath()` for special folders when needed
- For Windows Terminal settings: `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`

## Elevation

- Scripts that modify system/registry must request admin via `Request-AdminElevation` from `Scripts/Common.ps1` or manual check pattern
- Elevation should happen **before** making changes — fail early
- Return clean exit codes: `0` success, non-zero failure

## Common.ps1 Usage

Prefer existing helpers from `Scripts/Common.ps1`:

| Helper | Purpose |
|--------|---------|
| `Set-RegistryValue` | Safe registry writes (auto-converts types, optional `-WhatIf`) |
| `Remove-RegistryValue` | Safe registry deletion |
| `Get-NvidiaGpuRegistryPaths` | Discover NVIDIA GPU registry paths dynamically |
| `New-RestorePoint` | Create system restore point before risky operations |
| `Show-Menu` / `Get-MenuChoice` | Interactive menu UI |
| `Initialize-ConsoleUI` | Consistent console styling |

Do not duplicate logic — extend `Common.ps1` if new shared functionality is needed.

## Script Structure Example

```powershell
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Target
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Request admin if needed
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run as administrator"
}

begin {
    # Initialization
}

process {
    if ($PSCmdlet.ShouldProcess("$Target", "Modify")) {
        # Do work
    }
}
```

## CI Reminders

- CI runs `Invoke-ScriptAnalyzer -Settings PSScriptAnalyzerSettings.psd1`
- Current enforced rules: `PSAvoidGlobalAliases`, `PSAvoidUsingConvertToSecureStringWithPlainText`
- Run locally before committing: `Invoke-ScriptAnalyzer -Path Scripts/<changed>.ps1 -Settings ./PSScriptAnalyzerSettings.psd1`

## Windows Compatibility

- Support both PowerShell 5.1 (Windows PowerShell) and PowerShell 7+ (`pwsh`)
- Avoid 7+-only features unless wrapped in `if ($PSVersionTable.PSVersion.Major -ge 7)`
- Prefer cmdlets over .NET methods when a native cmdlet exists for readability
