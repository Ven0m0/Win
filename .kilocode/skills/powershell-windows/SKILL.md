---
name: powershell-windows
description: PowerShell scripting conventions for this Windows dotfiles repo — OTBS style, Common.ps1 usage, admin elevation, error handling, and comment-based help patterns used in Scripts/*.ps1
---

# PowerShell Windows Scripting

## Mandatory header for every script in Scripts/

```powershell
#Requires -RunAsAdministrator
. "$PSScriptRoot\Common.ps1"
```

## Top-level execution block

```powershell
Request-AdminElevation
Initialize-ConsoleUI -Title "Script Name (Administrator)"
```

## Function structure

```powershell
<#
.SYNOPSIS
    One-line description.
.DESCRIPTION
    Extended description.
.PARAMETER Name
    What this parameter controls.
.EXAMPLE
    Enable-Feature -Name "value"
#>
function Enable-Feature {
  param(
    [Parameter(Mandatory)]
    [string]$Name
  )

  Set-StrictMode -Version Latest
  $ErrorActionPreference = "Stop"

  # implementation
}
```

## Style rules (enforced by PSScriptAnalyzer CI)

- OTBS: `{` on same line, never on a new line
- 2-space indent — no tabs
- Spaces around operators: `$x = $a + $b`, `$list | Where-Object { $_ -eq $x }`
- Max 120 chars per line
- File names: `lowercase-with-dashes.ps1`

## Common.ps1 API — use these, do not re-implement

| Task | Function |
|------|----------|
| Admin check | `Request-AdminElevation` |
| Console setup | `Initialize-ConsoleUI -Title "..."` |
| Show menu | `Show-Menu -Title "..." -Options @(...)` |
| Get choice | `Get-MenuChoice -Min 1 -Max N` |
| Write registry | `Set-RegistryValue -Path -Name -Type -Data` |
| Delete registry value | `Remove-RegistryValue -Path -Name` |
| NVIDIA GPU paths | `Get-NvidiaGpuRegistryPaths` |
| Download file | `Get-FileFromWeb -URL -File` |
| Clear directory | `Clear-DirectorySafe -Path` |
| Parse Steam VDF | `ConvertFrom-VDF -Content` |
| Serialize Steam VDF | `ConvertTo-VDF -Data` |

## Interactive menu loop pattern

```powershell
while ($true) {
  Show-Menu -Title "Feature Menu" -Options @("Enable", "Disable", "Status", "Exit")
  $choice = Get-MenuChoice -Min 1 -Max 4

  switch ($choice) {
    1 { Enable-Feature }
    2 { Disable-Feature }
    3 { Show-Status }
    4 { exit }
  }

  Read-Host "`nPress Enter to continue"
}
```

## Banned patterns

- `Invoke-Expression` with variable input → injection risk
- `$ErrorActionPreference = "SilentlyContinue"` at global scope → silently hides failures
- Hardcoded paths like `C:\Users\username\` → use `$HOME` or `$PSScriptRoot`
- Raw `Set-ItemProperty` for registry → use `Set-RegistryValue` from Common.ps1
- Duplicating logic that's already in Common.ps1
