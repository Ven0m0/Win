---
paths:
  - '**/*.ps1'
  - '**/*.psm1'
  - '**/*.psd1'
---

# PowerShell Rules

Base: [PoshCode Practice and Style](https://github.com/PoshCode/PowerShellPracticeAndStyle). Repo convention wins on conflict (2-space indent).

## 1. Naming and paths

- `Verb-Noun` with an approved verb (`Get-Verb`), singular noun, PascalCase for public identifiers.
- No aliases and no positional shorthand in scripts: `Get-ChildItem`, `Get-Process -Name Explorer`.
- Private script variables may be camelCase; scope shared state explicitly (`$Script:State`).
- Language keywords and operators lowercase (`foreach`, `-eq`); help keywords UPPERCASE (`.SYNOPSIS`).
- Script-relative paths: `$PSScriptRoot` with `Join-Path -Path ... -ChildPath ...`, never `.\` or `..\`.
- User home: `$HOME` or `$env:USERPROFILE`. Never `C:\Users\...` and never `~` (provider-dependent).
- .NET methods and native apps ignore `$PWD`: pass fully resolved paths.

## 2. Layout

- 2-space indent. OTBS: opening brace ends the line, `} else {` on one line.
- Max 115 columns. Use splatting, not backtick continuation. Split long strings with `+` inside parens.
- Single space around operators, commas, and inside `{ }` and `$( )`. No trailing whitespace, no `;` line terminators.
- Two blank lines between top-level functions. One blank line at end of file.

## 3. Functions

- Advanced functions start with `[CmdletBinding()]`; order is `param`, `begin`, `process`, `end`.
- Declare `[OutputType()]` (one per parameter set) and `DefaultParameterSetName` when several sets exist.
- State-changing functions add `SupportsShouldProcess` and wrap the change in `$PSCmdlet.ShouldProcess($Target, 'Action')`. `ConfirmImpact`: `Low` create/set, `Medium` restart/reconfigure, `High` delete.
- Validate in `param` (`ValidateNotNullOrEmpty`, `ValidateSet`, `ValidateRange`, `ValidatePattern`, `ValidateScript`). Type every parameter. Avoid `[string]`/`[object]` on `ValueFromPipeline` or set-disambiguating parameters. Switches take no default.
- No `return` to emit objects: put the object alone on a line in `process {}`.
- Simple functions: space before the parameter list, `function Test-Code ($A, $B) {`.

## 4. Documentation

- Comment-based help inside the function, above `param()`: `.SYNOPSIS` required, plus `.DESCRIPTION`, `.EXAMPLE` (code first), `.OUTPUTS`.
- Document a parameter with a one-line comment directly above it, not a `.PARAMETER` block.
- Comments explain why, not what. Inline `#` has two spaces before it.

## 5. Errors

- `$ErrorActionPreference = 'Stop'` at the top of every script. Never set it to `SilentlyContinue` globally.
- `try/catch` with `-ErrorAction Stop` on trapped cmdlets. For native commands check `$LASTEXITCODE`. Avoid `$?`.
- Put the whole transaction in `try {}`, not a flag set in `catch`.
- Copy `$_` first in `catch` (`$err = $_`): later commands overwrite it.

## 6. Prohibited

- Global `$ErrorActionPreference = 'SilentlyContinue'`.
- `Invoke-Expression` on variable or user input.
- Plain-string `-Password`/`-Username` parameters: take `[PSCredential]` with `[System.Management.Automation.Credential()]`, and never call `Get-Credential` inside the function.
- `ConvertTo-SecureString -AsPlainText`, or hand-rolled `-Key` material. Persist secrets with `Export-Clixml`/`Import-Clixml` (DPAPI: readable only by the same user on the same machine).
- Global aliases in script or module scope.
- Bare `curl` (aliased to `Invoke-WebRequest`): use `curl.exe`.
- Touching `HKLM\SECURITY`, `HKLM\SAM`, `HKLM\SYSTEM\...\Lsa`.

## 7. Output

- Results go to the pipeline, one object type per function (internal helpers may mix).
- Diagnostics use `Write-Verbose`/`Write-Debug`/`Write-Warning`/`Write-Error`. `Write-Host` only for interactive UI. `Write-Progress` is never the only place a needed result appears.

## 8. Performance

- `$null = <expr>`, not `| Out-Null` (much slower).
- `$ProgressPreference = 'SilentlyContinue'` before `Invoke-WebRequest`.
- `foreach` statement over `ForEach-Object` for in-memory collections.
- Build collections with `[System.Collections.Generic.List[T]]` or by assigning the loop output, not `+=` in loops.
- `Measure-Command` before optimizing; do not trade readability for gains that do not matter at this repo's data sizes.

## 9. Compatibility

- Every standalone script declares `#Requires -Version 5.1`. The repo targets 5.1 and 7+.
- Guard 7+ features (ternary, `&&`/`||`, `??`) with `if ($PSVersionTable.PSVersion.Major -ge 7) { ... } else { ... }`.

## 10. Pitfalls

- Parenthesize each cmdlet call around `-and`/`-or`: `if ((Test-Path $a) -or (Test-Path $b))`. Unparenthesized, `-or` binds as a parameter.
- ASCII only in script files (`[OK]`, `[!]`, not emoji or check marks): 5.1 reads BOM-less UTF-8 as ANSI and mangles the file.
- Counts: `$null.Count` throws under strict mode. Wrap commands, `@(Get-Thing).Count` (0 when nothing is emitted); for a variable that may be `$null`, test `if ($x)` first, because `@($null).Count` is 1.
- `ConvertTo-Json -Depth N` for nested objects: the default depth 2 silently truncates.

## 11. CI

- Lint: `Invoke-ScriptAnalyzer -Path <file> -Settings PSScriptAnalyzerSettings.psd1`.
- Test when the area has coverage: `Invoke-Pester -Path tests/ -Output Minimal`.
- CI fails on `PSAvoidGlobalAliases` and `PSAvoidUsingConvertToSecureStringWithPlainText`.
