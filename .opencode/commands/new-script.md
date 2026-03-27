---
description: Scaffold a new PowerShell script in Scripts/ following the standard pattern
agent: code
subtask: true
---

Create a new PowerShell script at `Scripts/$1.ps1` for the following purpose: $ARGUMENTS

Requirements:
1. File name: `$1.ps1` (lowercase-with-dashes, no spaces)
2. Encoding: UTF-8 with BOM, CRLF line endings
3. Mandatory header:
   ```powershell
   #Requires -RunAsAdministrator
   . "$PSScriptRoot\Common.ps1"
   ```
4. Call `Request-AdminElevation` and `Initialize-ConsoleUI -Title "$1 (Administrator)"` at top-level
5. Implement domain functions with comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`)
6. Wire up the interactive menu loop using `Show-Menu` + `Get-MenuChoice` from Common.ps1
7. Use `Set-RegistryValue`/`Remove-RegistryValue` for any registry operations — never raw `Set-ItemProperty`
8. Set `Set-StrictMode -Version Latest` and `$ErrorActionPreference = "Stop"` inside each function
9. Include a "Restore defaults" menu option for any registry or system changes
10. No hardcoded paths — use `$PSScriptRoot` and `$HOME`

After scaffolding, output:
- The file contents
- The git command to stage it: `git add Scripts/$1.ps1`
- The suggested commit message following repo conventions
