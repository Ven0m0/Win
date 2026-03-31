# PowerShell Script Validator

Automated validation for PowerShell scripts against this repo's conventions (AGENTS.md).

---

## Purpose

Ensures new/modified `.ps1` scripts adhere to:
- **Common.ps1** reuse (no code duplication)
- **Admin elevation** checks
- **Registry path** patterns (NVIDIA discovery, HKLM vs HKCU)
- **Error handling** (Set-StrictMode, $ErrorActionPreference)
- **Comment-based help** on all functions
- **OTBS style** (2-space indent, spaces around operators)

**Invocation**: Claude-only (not user-invocable)

---

## Validation Checklist

When a `.ps1` script is created or modified, this skill validates:

### 1. Header Requirements
```
✓ #Requires -RunAsAdministrator present
✓ . "$PSScriptRoot\Common.ps1" imported
✓ Request-AdminElevation called early
✓ Initialize-ConsoleUI -Title set
```

### 2. Error Handling
```
✓ Set-StrictMode -Version Latest in functions
✓ $ErrorActionPreference = "Stop" in functions
✓ try/catch blocks around risky operations (registry, network)
✓ No $ErrorActionPreference = "SilentlyContinue" globally
```

### 3. Code Reuse (Common.ps1)
```
✓ Registry ops use Set-RegistryValue / Remove-RegistryValue
✓ File downloads use Get-FileFromWeb
✓ Directory cleanup uses Clear-DirectorySafe
✓ Steam VDF ops use ConvertFrom-VDF / ConvertTo-VDF
✓ GPU registry discovery uses Get-NvidiaGpuRegistryPaths
✓ UI operations use Show-Menu / Get-MenuChoice
```

### 4. Registry Patterns
```
✓ NVIDIA GPU paths use Get-NvidiaGpuRegistryPaths (not hardcoded)
✓ HKLM paths (system-wide settings)
✓ HKCU paths (user preferences)
✓ No mixed HKLM/HKCU without clear intent
✓ Registry changes include "restore defaults" options
```

### 5. Paths
```
✓ No hardcoded "C:\Users\", "D:\", etc.
✓ Uses $PSScriptRoot, $HOME, $env:* only
✓ Quoted paths with spaces: "$path"
```

### 6. Documentation
```
✓ All functions have comment-based help:
  - .SYNOPSIS
  - .DESCRIPTION (if non-obvious)
  - .PARAMETER (for each param)
  - .EXAMPLE
✓ Inline comments for complex logic
```

### 7. Style (enforced by PSScriptAnalyzer CI)
```
✓ OTBS braces (opening brace on same line)
✓ 2-space indent (not tabs)
✓ Spaces around operators: $a + $b
✓ Spaces around pipes: Get-Item | Where-Object
✓ Function names: Verb-Noun (approved verbs)
✓ File names: lowercase-with-dashes.ps1
```

### 8. Testing
```
✓ If function is complex (>20 lines), corresponding .Tests.ps1 should exist
✓ Tests use Pester (Arrange-Act-Assert)
✓ Mock registry operations (don't touch HKLM in tests)
```

---

## Common Issues & Fixes

| Issue | Fix |
|-------|-----|
| `Common.ps1 not found` | Ensure script is in `Scripts/` directory |
| Hardcoded `C:\Users\...` | Use `$HOME` or `$env:USERPROFILE` |
| Registry path hardcoded | Use `Get-NvidiaGpuRegistryPaths` for GPU paths |
| No comment-based help | Add `<# .SYNOPSIS ... .EXAMPLE ... #>` block |
| Function missing error checks | Add `Set-StrictMode -Version Latest` + `$ErrorActionPreference = "Stop"` |
| Duplicated menu logic | Use `Show-Menu` + `Get-MenuChoice` from Common.ps1 |

---

## Related Files

- **AGENTS.md** — Authoritative style & convention guide
- **Scripts/Common.ps1** — Shared utility functions (use these!)
- **.github/workflows/powershell.yml** — PSScriptAnalyzer CI
- **.github/instructions/powershell.instructions.md** — Detailed standards
