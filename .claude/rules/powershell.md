# PowerShell Rules for Ven0m0/Win

Applies to all PowerShell files: `Scripts/**/*.ps1`, `*.psm1`, `*.psd1`, and setup scripts.

---

## 1. Naming Conventions

### Commands and Parameters

- Use `Verb-Noun` convention for all functions; run `Get-Verb` for the approved verb list
- PascalCase for **all** public identifiers: module names, function names, class names, parameters, global variables
- Nouns must be **singular** and may be compound-word PascalCase (`Get-DiskInfo`, not `Get-DiskInfos`)
- Two-letter acronyms keep both letters uppercase in PascalCase: `Get-PSDrive`, `$PSBoundParameters`
- Use full cmdlet names — no aliases (`Get-ChildItem`, not `gci`/`ls`/`dir`)
- Use full parameter names — no positional shorthand (`Get-Process -Name Explorer`, not `Get-Process Explorer`)
- Match standard PowerShell parameter names: `$ComputerName`, `$Path`, `$Credential`

### Variables

- Script-level private variables may use camelCase to distinguish from PascalCase parameters
- Scope shared variables explicitly: `$Script:State`, `$Global:DebugPreference`
- PowerShell language keywords are **lowercase**: `foreach`, `if`, `switch`, `-eq`, `-match`
- Comment-based help keywords are **UPPERCASE**: `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`

### Paths

- Always use `$PSScriptRoot` for script-relative paths; never unanchored `.\` or `..\`
- Use `$HOME` or `$env:USERPROFILE` for user home — never hardcode `C:\Users\...`
- Never use `~`: its meaning depends on the current provider

```powershell
# Wrong
Get-Content .\README.md

# Right
Get-Content -Path "$PSScriptRoot\README.md"
```

---

## 2. Code Layout and Formatting

### Braces — One True Brace Style (OTBS)

Opening brace at the **end** of the line; closing brace at the **beginning** of a line.

```powershell
if ($condition) {
  Do-Something
} else {
  Do-Other
}
```

### Indentation

**2-space** indentation (matches existing codebase style).

### Line Length

Keep lines to **115 characters** maximum. Use **splatting** instead of backtick continuation:

```powershell
# Wrong — backtick is fragile
Get-WmiObject -Class Win32_LogicalDisk `
              -Filter "DriveType=3"

# Right — splatting
$params = @{
  Class  = 'Win32_LogicalDisk'
  Filter = 'DriveType=3'
}
Get-WmiObject @params
```

### Whitespace

- Single space around operators and parameter names
- No trailing whitespace on any line
- No semicolons as line terminators
- Two blank lines between top-level function definitions
- One blank line at the end of each file

---

## 3. Function Structure

### Always Start With CmdletBinding

```powershell
[CmdletBinding()]
param ()
process {
}
end {
}
```

### No `return` in Advanced Functions

Do not use `return` to emit objects — place the object on its own line inside `process {}`.

### OutputType

Declare `[OutputType()]` on every advanced function that returns objects.

### SupportsShouldProcess

Add `SupportsShouldProcess` to any function that modifies system state:

```powershell
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param (...)
process {
  if ($PSCmdlet.ShouldProcess($Target, 'Delete')) {
    Remove-Item -Path $Target
  }
}
```

`ConfirmImpact` levels: `Low` (create/set), `Medium` (restart/reconfigure), `High` (delete/irreversible).

---

## 4. Error Handling

- `$ErrorActionPreference = 'Stop'` at the top of every script
- Use `try/catch` with `-ErrorAction Stop` on cmdlets you want to trap
- Never use global `$ErrorActionPreference = 'SilentlyContinue'`
- Copy `$_` immediately inside `catch` before any subsequent command overwrites it

```powershell
catch {
  $err = $_
  Write-Warning "Failed: $($err.Exception.Message)"
}
```

---

## 5. Security — Prohibited Patterns

- `$ErrorActionPreference = 'SilentlyContinue'` globally — hides failures
- `Invoke-Expression` with variable or user-derived input — code injection risk
- `ConvertTo-SecureString -AsPlainText` with literal key material
- Global aliases in script/module scope
- `-Password` / `-Username` plain-string parameters — use `[PSCredential]`
- Hardcoded user paths `C:\Users\...` — use `$HOME`, `$env:USERPROFILE`, `$PSScriptRoot`
- Bare `curl` in PowerShell — use `curl.exe`
- Touching `HKLM\SECURITY`, `HKLM\SAM`, `HKLM\SYSTEM\...\Lsa`

---

## 6. Output and Streams

| Stream  | Cmdlet              | When to use                             |
| ------- | ------------------- | --------------------------------------- |
| Success | pipeline (implicit) | Results consumed by callers             |
| Verbose | `Write-Verbose`     | Execution status; enabled by `-Verbose` |
| Warning | `Write-Warning`     | Non-fatal conditions                    |
| Error   | `Write-Error`       | Recoverable errors                      |
| Host    | `Write-Host`        | Interactive UI only                     |

Do not use `Write-Host` for general output. Use `Write-Verbose`/`Write-Warning`/`Write-Error`.

---

## 7. Performance

- `$null = <expr>` preferred over `<expr> | Out-Null` (pipeline form is significantly slower)
- `$ProgressPreference = 'SilentlyContinue'` before any `Invoke-WebRequest`
- `foreach` language construct is faster than `ForEach-Object` for in-memory collections

---

## 8. Version Compatibility

Every standalone script must declare the minimum PowerShell version:

```powershell
#Requires -Version 5.1
```

This repo targets both Windows PowerShell 5.1 and PowerShell 7+. Guard 7+-only features:

```powershell
if ($PSVersionTable.PSVersion.Major -ge 7) {
  # PS7+ path
} else {
  # PS5.1 fallback
}
```

---

## 9. CI Reminders

- Lint before committing: `Invoke-ScriptAnalyzer -Path <file> -Settings PSScriptAnalyzerSettings.psd1`
- Run tests when the changed area has coverage: `Invoke-Pester -Path tests/ -Output Minimal`
- CI-enforced (pipeline fails): `PSAvoidGlobalAliases`, `PSAvoidUsingConvertToSecureStringWithPlainText`
