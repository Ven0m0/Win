---
name: test-relocation
description: |
  Relocate Pester test files to centralized tests/ and update path references.
  Use when moving *.Tests.ps1 files or reorganizing test directory structure.
compatibility: opencode
---

# Test Relocation Skill

Load this skill when relocating test files, updating Pester test paths, or reorganizing the test directory structure.

## When to Load

- Moving `*.Tests.ps1` files between directories
- Updating `$PSScriptRoot` references in test files
- Creating a centralized `tests/` directory
- Updating test runner scripts (`.github/scripts/Test-PowerShell.ps1`)
- Adding new test files that need path resolution

## Directory Structure

```
Scripts/           # Source scripts (*.ps1)
tests/             # Centralized test files (*.Tests.ps1)
.kilo/skills/      # Agent skills (this file)
.github/scripts/   # CI and utility scripts
```

## Test Path Resolution

When tests live in `tests/` but reference scripts in `Scripts/`, all `$PSScriptRoot` references must use the relative path:

```powershell
# Before (tests were in Scripts/)
. "$PSScriptRoot/Common.ps1"
. "$PSScriptRoot/steam.ps1"

# After (tests moved to tests/)
. "$PSScriptRoot/../Scripts/Common.ps1"
. "$PSScriptRoot/../Scripts/steam.ps1"
```

## Path Update Rules

1. **Common.ps1 imports**: Update to `"$PSScriptRoot/../Scripts/Common.ps1"`
2. **Script imports**: Update to `"$PSScriptRoot/../Scripts/<script-name>.ps1"`
3. **Test runner**: Verify `.github/scripts/Test-PowerShell.ps1` finds tests in the new location
4. **No hardcoded paths**: Use `$PSScriptRoot/../Scripts/` — never hardcode absolute paths

## Affected Test Patterns

| Pattern | Replace With |
|---------|--------------|
| `"$PSScriptRoot/Common.ps1"` | `"$PSScriptRoot/../Scripts/Common.ps1"` |
| `"$PSScriptRoot/*.ps1"` | `"$PSScriptRoot/../Scripts/*.ps1"` |
| `"$PSScriptRoot/system-*.ps1"` | `"$PSScriptRoot/../Scripts/system-*.ps1"` |
| `"$PSScriptRoot/Deploy-*.ps1"` | `"$PSScriptRoot/../Scripts/Deploy-*.ps1"` |

## Test Runner Configuration

The Pester test runner (`.github/scripts/Test-PowerShell.ps1`) auto-discovers `*.Tests.ps1` files. After relocation, run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .github/scripts/Test-PowerShell.ps1 -Path tests/
```

## Migration Checklist

1. Create `tests/` directory at repo root
2. Move all `Scripts/*.Tests.ps1` to `tests/`
3. Update all `$PSScriptRoot` references in moved test files
4. Verify test runner discovers tests in new location
5. Run `mise run lint` to ensure no regressions
6. Run `pwsh -File .github/scripts/Test-PowerShell.ps1 -Path tests/` to validate

## Validation

After relocation, verify:
- All test files in `tests/` reference `../Scripts/` correctly
- `pwsh -File .github/scripts/Test-PowerShell.ps1 -Path tests/` runs without path errors
- `mise run lint` passes
- No stale `*.Tests.ps1` files remain in `Scripts/`
