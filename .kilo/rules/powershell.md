# PowerShell Rules for Ven0m0/Win

Applies to all PowerShell files: `Scripts/**/*.ps1`, `*.psm1`, `*.psd1`, and setup scripts.

Sources: [PoshCode Style Guide](https://poshcode.gitbook.io/powershell-practice-and-style) · [PoshCode Best Practices](https://github.com/PoshCode/PowerShellPracticeAndStyle)

---

## 1. Naming Conventions

### Commands and Parameters
- Use `Verb-Noun` convention for all functions; run `Get-Verb` for the approved verb list
- PascalCase for **all** public identifiers: module names, function names, class names, parameters, global variables
- Nouns must be **singular** and may be compound-word PascalCase (`Get-DiskInfo`, not `Get-DiskInfos`)
- Two-letter acronyms keep both letters uppercase in PascalCase: `Get-PSDrive`, `$PSBoundParameters`
- Use full cmdlet names — no aliases (`Get-ChildItem`, not `gci`/`ls`/`dir`)
- Use full parameter names — no positional shorthand (`Get-Process -Name Explorer`, not `Get-Process Explorer`)
- Match standard PowerShell parameter names: `$ComputerName`, `$Path`, `$Credential`, not `$Param_Computer`

### Variables
- Script-level private variables may use camelCase to distinguish from PascalCase parameters (optional style)
- Scope shared variables explicitly: `$Script:State`, `$Global:DebugPreference`
- PowerShell language keywords are **lowercase**: `foreach`, `if`, `switch`, `-eq`, `-match`
- Comment-based help keywords are **UPPERCASE**: `.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`

### Paths
- Always use `$PSScriptRoot` for script-relative paths; never unanchored `.\` or `..\`
- Use `$HOME` or `$env:USERPROFILE` for user home — never hardcode `C:\Users\...`
- Never use `~`: its meaning depends on the current provider and breaks outside the `FileSystem` provider

```powershell
# Wrong
Get-Content .\README.md
[System.IO.File]::ReadAllText(".\README.md")

# Right
Get-Content -Path "$PSScriptRoot\README.md"
[System.IO.File]::ReadAllText("$PSScriptRoot\README.md")
```

---

## 2. Code Layout and Formatting

### Braces — One True Brace Style (OTBS)
Opening brace at the **end** of the line; closing brace at the **beginning** of a line. No exceptions for control flow.

```powershell
if ($condition) {
    Do-Something
} else {
    Do-Other
}

# Single-line scriptblock permitted for short inline predicates
Get-ChildItem | Where-Object { $_.Length -gt 10mb }
```

### Indentation
This repo uses **2-space** indentation (deviates from PoshCode's 4-space recommendation to match the existing codebase style). Continuation lines may indent further to align with method calls.

### Line Length
Keep lines to **115 characters** maximum. Use **splatting** instead of backtick continuation:

```powershell
# Wrong — backtick is fragile (trailing space breaks it silently)
Get-WmiObject -Class Win32_LogicalDisk `
              -Filter "DriveType=3" `
              -ComputerName SERVER2

# Right — splatting
$params = @{
    Class        = 'Win32_LogicalDisk'
    Filter       = 'DriveType=3'
    ComputerName = 'SERVER2'
}
Get-WmiObject @params
```

Use PowerShell's implied continuation inside `()`, `[]`, `{}` for long expressions:

```powershell
$count = (Get-ChildItem -Path $PSScriptRoot -Recurse |
    Where-Object { $_.Extension -eq '.ps1' } |
    Measure-Object).Count
```

### Whitespace
- Single space around operators and parameter names: `$x = $y + 2`, `Get-Item -Path $p`
- Single space after commas and semicolons
- Single space **inside** `$( ... )` subexpressions and `{ ... }` scriptblocks
- No trailing whitespace on any line
- No semicolons as line terminators (unnecessary in PowerShell)
- Two blank lines between top-level function definitions
- One blank line at the end of each file

### Hashtables
Each key-value pair on its own line; no trailing semicolons:

```powershell
$options = @{
    Margin   = 2
    Padding  = 2
    FontSize = 24
}
```

### Avoid Backticks for Line Continuation
Backticks are invisible, fragile, and break silently on a trailing space. Use splatting or implied continuation (inside parens/brackets) instead.

---

## 3. Function Structure

### Always Start With CmdletBinding
Every function and script should begin with `[CmdletBinding()]`, even if blocks are later pruned. This enables common parameters (`-Verbose`, `-ErrorAction`, `-WhatIf`, `-?`):

```powershell
[CmdletBinding()]
param ()
process {
}
end {
}
```

### Block Order
Write blocks in execution order: `param`, `begin`, `process`, `end`. Always name blocks explicitly — avoid the anonymous end-block shorthand and the `filter` keyword.

### No `return` in Advanced Functions
Do not use `return` to emit objects — place the object on its own line inside `process {}`. The `return` keyword exits the current iteration, not the function, which is almost never what you want for pipeline output.

```powershell
# Wrong
end { return $result }

# Right
process {
    [PSCustomObject]@{ Name = $Name; Value = $Value }
}
```

### OutputType
Declare `[OutputType()]` on every advanced function that returns objects. When parameter sets return different types, declare one per set:

```powershell
[OutputType([System.IO.FileInfo], ParameterSetName = 'ByPath')]
[OutputType([string],            ParameterSetName = 'ByName')]
```

### Parameter Sets
When any parameter uses `ParameterSetName`, always set `DefaultParameterSetName` in `[CmdletBinding()]`:

```powershell
[CmdletBinding(DefaultParameterSetName = 'ByName')]
```

### Pipeline Parameters
Any function that accepts pipeline input **must** have a `process {}` block. Emit output from `process {}` only — never from `begin {}` or `end {}`, which defeats the streaming advantage of the pipeline.

```powershell
param (
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$Name
)
process {
    # emit objects here
}
```

### Parameter Validation — Attributes Over Body Logic
Use declarative validation attributes instead of manual `if` checks in the function body:

| Attribute | Use case |
|---|---|
| `[ValidateNotNullOrEmpty()]` | Non-null, non-empty string/array |
| `[ValidateSet('Low','Med','High')]` | Enumerated allowed values |
| `[ValidateRange(0, 100)]` | Numeric bounds |
| `[ValidateLength(1, 50)]` | String length bounds |
| `[ValidatePattern('^[A-Z]{3}$')]` | Regex match |
| `[ValidateScript({ $_ -ge (Get-Date) })]` | Arbitrary script logic |
| `[ValidateCount(1, 5)]` | Array element count |
| `[AllowNull()]` / `[AllowEmptyString()]` | Permit null/empty on mandatory params |

### SupportsShouldProcess
Add `SupportsShouldProcess` to any function that modifies system state. Grade severity with `ConfirmImpact`:

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

### Full Script Skeleton

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
.NOTES
    Implementation details here.
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
[OutputType([PSCustomObject])]
param (
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [ValidateNotNullOrEmpty()]
    [string]$Target
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

begin {
    Request-AdminElevation  # from Common.ps1, if admin is required
}

process {
    if ($PSCmdlet.ShouldProcess($Target, 'Modify')) {
        [PSCustomObject]@{ Target = $Target; Result = 'done' }
    }
}
```

---

## 4. Documentation and Comments

### Comment-Based Help (Required on Exported Functions)
Place help **inside** the function body, immediately after the opening brace:

```powershell
function Get-Example {
    <#
    .SYNOPSIS
        Brief one-liner.
    .DESCRIPTION
        Longer explanation. Write simply — avoid jargon.
    .PARAMETER Path
        The file path to process.
    .INPUTS
        System.String. Pipe a path string.
    .OUTPUTS
        System.IO.FileInfo
    .EXAMPLE
        Get-Example -Path 'C:\file.txt'
        Returns the FileInfo for file.txt.
    .NOTES
        Internal implementation details.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path
    )
    ...
}
```

Parameter docs may also live directly above each `param` entry (preferred — they stay in sync with changes):

```powershell
param (
    # The path to the file. Accepts pipeline input.
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [string]$Path
)
```

### Comment Philosophy
- Comments explain **why**, not **what** — the code shows what
- Block comments indent to the same level as the code they describe
- Use `<# ... #>` only for multi-paragraph prose (help text); single `#` for all other comments
- Inline comments: two spaces before the `#`; align them in a block when possible
- Never write "Increment X by 2" next to `$x += 2` — that just repeats the code
- Don't precede every line with a comment — it breaks up the code and makes it harder to scan

---

## 5. Output and Formatting

### Write-* Stream Usage

| Stream | Cmdlet | When to use |
|---|---|---|
| Success | pipeline (implicit) | Results consumed by callers |
| Verbose | `Write-Verbose` | Execution status detail; enabled by `-Verbose` |
| Debug | `Write-Debug` | Maintainer-level diagnostics; enabled by `-Debug` |
| Warning | `Write-Warning` | Non-fatal conditions callers should know about |
| Error | `Write-Error` | Recoverable errors (use `throw` for terminating) |
| Progress | `Write-Progress` | Long-loop progress indicators |
| Host | `Write-Host` | **Interactive UI only** — bypasses all streams, cannot be captured |

### Write-Host Restriction
Do not use `Write-Host` for general output. It bypasses all output streams and cannot be redirected or captured by callers. Use it only for:
- `Show-*` / `Format-*` verb functions explicitly presenting to the screen
- Interactive prompts requiring styled/colored text
- `Initialize-ConsoleUI` / `Show-Menu` helpers in `Common.ps1`

### Output One Type Per Command
Avoid mixing different object types from a single command — the formatter will produce empty rows or switch unexpectedly between table and list layouts. Declare `[OutputType()]` to make the contract explicit.

### Tools Output Raw Data
Reusable tool functions emit the most granular representation (bytes, not gigabytes; raw objects, not formatted strings). Format or convert in a controller script or a `.format.ps1xml` view file attached to a module.

---

## 6. Error Handling

### ERR-01 — Use `-ErrorAction Stop` on cmdlets you want to trap

```powershell
Get-Content -Path $path -ErrorAction Stop
```

### ERR-02 — Set `$ErrorActionPreference` around non-cmdlet code

```powershell
$ErrorActionPreference = 'Stop'
& some-external-tool.exe --flag
$ErrorActionPreference = 'Continue'
```

### ERR-03 — Entire transaction in the `try` block; no boolean flags

```powershell
# Wrong — flag pattern is hard to follow
try { $ok = $true; Do-Something -ErrorAction Stop } catch { $ok = $false }
if ($ok) { Do-More }

# Right — single transaction
try {
    Do-Something -ErrorAction Stop
    Do-More
} catch {
    Handle-Error $_
}
```

### ERR-04 — Avoid `$?`
`$?` only reports whether the last command *considered itself* successful — it carries no detail about what failed. Use `try/catch` with `-ErrorAction Stop` instead.

### ERR-05 — Avoid null-variable as error sentinel
Null checks (`if ($result) { ... } else { ... }`) as error conditions are logically contorted and harder to debug than a proper `try/catch`. Prefer terminating errors.

### ERR-06 — Copy `$_` immediately inside `catch`

```powershell
catch {
    $err = $_    # capture before any subsequent command overwrites $_
    Write-Warning "Failed: $($err.Exception.Message)"
}
```

---

## 7. Performance

- Measure before optimizing: use `Measure-Command` or the Profiler module
- `foreach` language construct is faster than `ForEach-Object` for in-memory collections
- Pipeline streaming (`Get-Content | ForEach-Object`) avoids loading large files fully into memory
- Performance order (fastest → slowest): language constructs → .NET compiled methods → simple script → cmdlet pipeline
- Wrap .NET classes in PowerShell functions to preserve ergonomics and cmdlet-style interfaces
- Do not optimize for tiny datasets — readable code that is 30% slower on 10 items is the right trade-off

---

## 8. Security

### Credentials — Always PSCredential
- Accept `[PSCredential]` parameters — never accept passwords as plain `[string]`
- Apply `[System.Management.Automation.Credential()]` attribute to coerce bare user-name strings:

```powershell
param (
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]
    $Credential
)
```

- Never call `Get-Credential` inside a shared tool; accept it as a parameter so callers can reuse stored credentials
- To pass plaintext to a .NET API, decrypt inline — never store the decrypted value in a variable:

```powershell
$api.SetPassword($Credential.GetNetworkCredential().Password)
```

### Storing Credentials and Secrets
- Persist credentials with `Export-CliXml` (DPAPI-protected, user+machine-locked):

```powershell
Get-Credential | Export-CliXml -Path "$env:APPDATA\cred.xml"
$Credential = Import-CliXml -Path "$env:APPDATA\cred.xml"
```

- For other sensitive strings, use `ConvertFrom-SecureString` / `ConvertTo-SecureString` (DPAPI by default)
- To decrypt a SecureString for a .NET API call, free the BSTR immediately after use:

```powershell
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
```

### Prohibited Patterns

- ❌ `$ErrorActionPreference = 'SilentlyContinue'` globally — hides failures
- ❌ `Invoke-Expression` with variable or user-derived input — code injection risk (CI: `PSAvoidUsingInvokeExpression`)
- ❌ `ConvertTo-SecureString -AsPlainText` with literal key material (CI: `PSAvoidUsingConvertToSecureStringWithPlainText`)
- ❌ Global aliases in script/module scope (CI: `PSAvoidGlobalAliases`)
- ❌ `-Password` / `-Username` plain-string parameters — use `[PSCredential]` (CI: `UsePSCredentialType`)
- ❌ Hardcoded `ComputerName` literals (CI: `AvoidUsingComputerNameHardcoded`)
- ❌ Hardcoded user paths `C:\Users\...` — use `$HOME`, `$env:USERPROFILE`, `$PSScriptRoot`
- ❌ Bare `curl` in PowerShell — use `curl.exe` when targeting the curl binary
- ❌ Touching `HKLM\SECURITY`, `HKLM\SAM`, `HKLM\SYSTEM\...\Lsa`

---

## 9. Building Reusable Tools

### Tool vs Controller Pattern

| Type | Intent | Output |
|---|---|---|
| **Tool** (function/module) | High reuse, single responsibility | Raw objects to pipeline |
| **Controller** (script) | One specific business process | Formatted/logged for humans |

Tools accept input only via parameters and produce output only as objects on the pipeline. Controllers orchestrate tools and may write to the screen or a log file.

### Design Principles
- Modularize working code into functions in script modules — keep logic out of controller scripts
- Emit raw, granular data from tools (bytes, not GB); let controllers or `.format.ps1xml` view files format it
- Use standard PowerShell parameter names: `$ComputerName`, `$Path`, `$Credential`
- Check whether a built-in cmdlet already solves the problem before writing a new function
- When using a non-PowerShell approach (.NET, external binary) due to performance or missing cmdlet, wrap it in an advanced function and document why in a comment
- Single responsibility: each function should do one thing

### Prefer Native PowerShell
Use native cmdlets over COM, WMI (`Get-WmiObject`), or .NET classes when a native equivalent exists. Prefer `Get-CimInstance` over `Get-WmiObject` (CIM works over WinRM on both PS 5.1 and 7+). When a non-native approach is necessary, document why.

---

## 10. Version and Compatibility

### `#Requires` Statement
Every standalone script must declare the minimum PowerShell version:

```powershell
#Requires -Version 5.1
```

### Dual-Version Support (5.1 + 7+)
This repo targets both Windows PowerShell 5.1 and PowerShell 7+. Guard 7+-only features explicitly:

```powershell
if ($PSVersionTable.PSVersion.Major -ge 7) {
    # PS7+ path
} else {
    # PS5.1 fallback
}
```

Prefer cmdlets over .NET methods when a native cmdlet exists — cmdlets abstract version differences. Avoid WMI (`Get-WmiObject`) in favour of CIM (`Get-CimInstance`).

---

## 11. Common.ps1 — Helpers Reference

Never duplicate logic from `Scripts/Common.ps1`. Extend it when new shared functionality is needed.

```powershell
# Admin / UI
Request-AdminElevation                          # elevation check — always first in system scripts
Initialize-ConsoleUI -Title '...'               # console setup
Show-Menu / Get-MenuChoice                      # interactive menus
Wait-ForKeyPress                                # pause for user

# Registry
Set-RegistryValue / Remove-RegistryValue        # safe registry ops with optional -WhatIf
Get-RegistryValueSafe                           # read without throwing

# NVIDIA
Get-NvidiaGpuRegistryPath                       # discover all NVIDIA adapter registry paths (singular)
Get-NvidiaGpuPath / Set-NvidiaGpuRegistryValue  # GPU-specific ops
Set-NvidiaSignatureOverride / Get-NvidiaSignatureStatus
Set-FullscreenMode / Set-MultiPlaneOverlay      # display tweaks

# System
New-RestorePoint                                # before any HKLM changes
Remove-AppxPackageSafe                          # safe appx removal
Invoke-ServiceOperation                         # start/stop/query services
Invoke-CommandChecked                           # run external command, throw on failure
Invoke-RegImport                                # import .reg files safely
Invoke-Winget                                   # winget wrapper
Wait-ForWinget                                  # wait for winget lock

# Files / Paths
Get-FileFromWeb -URL '...' -File '...'          # downloads (sets ProgressPreference automatically)
Clear-DirectorySafe -Path '...'                 # safe directory clear
Clear-PathSafe -Path '...'                      # safe path removal
Ensure-Directory -Path '...'                    # mkdir -p equivalent

# Logging
Add-Log / Get-Log / Clear-Log                   # session logging

# Utilities
ConvertFrom-VDF / ConvertTo-VDF                 # Steam VDF parsing
Get-FolderSize / Format-Size                    # size reporting
Measure-Execution                               # timing
Show-Summary                                    # display results summary
```

---

## 12. Path and Environment Variables

| Variable | Purpose |
|---|---|
| `$PSScriptRoot` | Directory of the running script |
| `$HOME` / `$env:USERPROFILE` | User home directory |
| `$env:LOCALAPPDATA` | `%LocalAppData%` |
| `$env:APPDATA` | `%AppData%` (roaming) |
| `$env:PROGRAMDATA` | `%ProgramData%` |
| `$env:PROGRAMFILES` | `%ProgramFiles%` |
| `[Environment]::GetFolderPath('Desktop')` | Shell special folders |

Windows Terminal settings live at: `$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`

---

## 13. Elevation

- Scripts modifying system or registry must call `Request-AdminElevation` from `Common.ps1` (or the manual pattern) **before** making any changes — fail early
- Return clean exit codes: `0` success, non-zero failure

---

## 14. Downloads

Always suppress the progress bar before `Invoke-WebRequest` — it is extremely slow when output is piped:

```powershell
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
```

Prefer `Get-FileFromWeb` from `Common.ps1`, which handles this automatically.

---

## 15. Pipeline and String Hygiene

- `.NET` string methods are **case-sensitive** by default; pass `'CurrentCultureIgnoreCase'` or use PowerShell's `-eq`/`-like` operators (case-insensitive) for string comparisons
- External commands: use `&` operator with quoted arguments: `& git.exe commit -m "$message"`
- Suppress output with `$null = <expr>`, not `| Out-Null` (the pipeline form is significantly slower)
- `return` in an advanced function exits the current pipeline iteration — it does not emit a value

---

## 16. Registry and System Tweaks

- Always create a restore point before HKLM changes (unless `-NoRestorePoint` is explicitly passed)
- Support both apply and restore paths: `-Action Enable` / `-Restore`
- Never hardcode GPU PCI IDs — use `Get-NvidiaGpuRegistryPath` for device discovery
- Avoid sensitive keys: `HKLM\SECURITY`, `HKLM\SAM`, `HKLM\SYSTEM\...\Lsa`

---

## 17. CI Reminders

- Lint before committing: `Invoke-ScriptAnalyzer -Path <file> -Settings PSScriptAnalyzerSettings.psd1`
- Run tests when the changed area has coverage: `Invoke-Pester -Path tests/ -Output Minimal`
- CI-enforced (pipeline fails): `PSAvoidGlobalAliases`, `PSAvoidUsingConvertToSecureStringWithPlainText`
- CI warnings surfaced: `AvoidUsingCmdletAliases`, `AvoidUsingWriteHost`, `ProvideCommentHelp`, `UseShouldProcessForStateChangingFunctions`, `AvoidUsingPositionalParameters`
