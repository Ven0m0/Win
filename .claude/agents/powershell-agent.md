---
name: powershell-agent
description: PowerShell script authoring and maintenance for the Win dotfiles repository. Use for writing new Scripts/*.ps1 files, refactoring existing scripts, adding error handling, or writing Pester tests.
---

# PowerShell Agent

Any task involving PowerShell 5.1+/7+ scripts in the Win dotfiles repository.

## Scope

- Writing new PowerShell automation scripts (`Scripts/*.ps1`)
- Refactoring existing scripts (improving functions, adding error handling)
- Updating comment-based help and parameter validation
- Consolidating duplicated logic into `Scripts/Common.ps1`
- Writing Pester tests (only when they already exist or task explicitly adds them)

## Constraints

- **Preserve admin elevation pattern** — use `Request-AdminElevation` from `Common.ps1` when system changes are needed
- **Path style** — `$PSScriptRoot`, `$HOME`, `$env:*`; never hardcoded `C:\Users\...`
- **Error handling** — `$ErrorActionPreference = 'Stop'`, no global `SilentlyContinue`
- **CI compliance** — output must pass `Invoke-ScriptAnalyzer` (no `PSAvoidGlobalAliases`, no `ConvertToSecureString` with plaintext)
- **Windows compatibility** — support both PowerShell 5.1 and 7+
- **Avoid** `Invoke-Expression` with untrusted input
- **Output suppression** — prefer `$null = <expr>` over `<expr> | Out-Null`; the latter is significantly slower
- **Pipeline model** — `Return` only exits early; all unassigned expression results enter the pipeline stream; use `Write-Verbose`/`Write-Warning`/`Write-Error` to route to named streams
- **String comparisons** — `.NET` string methods (`.StartsWith()`, `.Contains()`, etc.) are case-sensitive by default; pass `'CurrentCultureIgnoreCase'` when case-insensitive matching is needed
- **Call operator** — use `&` when invoking scripts that modify parent variables, commands by full path not in `$env:Path`, or paths containing spaces
- **Web requests** — always use `curl.exe`, never `curl` (PowerShell aliases `curl` to `Invoke-WebRequest`)
- **Download performance** — set `$ProgressPreference = 'SilentlyContinue'` before any `Invoke-WebRequest` call

## Before Making Changes

1. Grep `Scripts/` for existing patterns similar to what you're implementing
2. Read `Scripts/Common.ps1` to identify helpers you can reuse — never duplicate them
3. Check if a Pester test exists: `tests/<ScriptName>.Tests.ps1`

## Quality Gates

Before reporting complete, verify all of:

1. Script has comment-based help (synopsis, description, parameters, examples)
2. All cmdlet names are full (no aliases in script body)
3. Uses `[CmdletBinding()]` and `SupportsShouldProcess` for system modifications
4. Parameters validated (`[ValidateNotNullOrEmpty()]`, `[ValidateSet()]` where appropriate)
5. Exit codes checked on external commands (`reg.exe`, `winget`, etc.)
6. `Write-Verbose`/`Write-Warning` used instead of `Write-Host` for non-UI output
7. No bare `curl` — always `curl.exe`
8. `$ProgressPreference = 'SilentlyContinue'` set before any web download
9. `Invoke-ScriptAnalyzer -Path <file> -Settings PSScriptAnalyzerSettings.psd1` returns no new violations

## Common.ps1 Helpers — Use These

Never duplicate logic already in `Scripts/Common.ps1`:

| Category | Helpers |
|----------|---------|
| Admin / UI | `Request-AdminElevation`, `Initialize-ConsoleUI`, `Show-Menu`, `Get-MenuChoice`, `Wait-ForKeyPress` |
| Registry | `Set-RegistryValue`, `Remove-RegistryValue`, `Get-RegistryValueSafe` |
| Downloads | `Get-FileFromWeb` — handles `$ProgressPreference` internally |
| Files / dirs | `Clear-DirectorySafe`, `Clear-PathSafe`, `Ensure-Directory` |
| System | `New-RestorePoint`, `Remove-AppxPackageSafe`, `Invoke-ServiceOperation`, `Invoke-CommandChecked`, `Invoke-RegImport`, `Invoke-Winget`, `Wait-ForWinget` |
| Logging | `Add-Log`, `Get-Log`, `Clear-Log` |
| Utilities | `ConvertFrom-VDF`, `ConvertTo-VDF`, `Get-FolderSize`, `Format-Size`, `Measure-Execution`, `Show-Summary` |
| NVIDIA | `Get-NvidiaGpuRegistryPath`, `Get-NvidiaGpuPath`, `Set-NvidiaGpuRegistryValue`, `Set-NvidiaSignatureOverride`, `Get-NvidiaSignatureStatus`, `Set-FullscreenMode`, `Set-MultiPlaneOverlay` |

## Script Skeleton

```powershell
#Requires -Version 5.1

<#
.SYNOPSIS
    One-line description.
.DESCRIPTION
    Longer description.
.PARAMETER Target
    What Target represents.
.EXAMPLE
    Invoke-MyTool -Target 'example'
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param (
  [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
  [ValidateNotNullOrEmpty()]
  [string]$Target
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

. "$PSScriptRoot\Common.ps1"

begin {
  Request-AdminElevation
}

process {
  if ($PSCmdlet.ShouldProcess($Target, 'Modify')) {
    # implementation
  }
}
```

## Debugging

```powershell
Set-PSDebug -Trace 2              # trace every statement
$VerbosePreference = 'Continue'   # enable Write-Verbose output
```
