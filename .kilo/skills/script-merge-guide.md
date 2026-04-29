---
name: script-merge-guide
description: Guide for merging similar PowerShell scripts with parameterized modes in the Win dotfiles repository.
compatibility: opencode
---

# Script Merge Guide

Load this skill when merging duplicate or overlapping PowerShell scripts, creating parameterized script modes, or consolidating Steam/game-specific automation.

## When to Load

- Two scripts have >80% code overlap
- Scripts differ only in configuration/options
- Game-specific scripts should merge into generic equivalents with a `-Mode` parameter
- Eliminating duplicate helper functions across scripts

## Merge Pattern

### Step 1: Identify Differences

Compare scripts to find what changes:
```powershell
# Example: steam.ps1 vs arc-raiders/steam.ps1
# Differences found:
# - $NoGPU: 1 (default) vs 0 (ArcRaiders)
# - SmallMode: '1' (default) vs '0' (ArcRaiders)  
# - Launch args: -quicklogin present vs absent
# - Output formatting: Write-Output vs Write-Host
```

### Step 2: Create Parameterized Entry

Add a `-Mode` parameter to control behavior:
```powershell
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Default', 'ArcRaiders')]
    [string]$Mode = 'Default'
)
```

### Step 3: Parameterize Differences

Use conditional assignment for mode-specific values:
```powershell
$NoGPU     = if ($Mode -eq 'ArcRaiders') { 0 } else { 1 }
$SmallMode = if ($Mode -eq 'ArcRaiders') { '0' } else { '1' }
```

### Step 4: Update Invocation Guard

Preserve the dot-source detection pattern:
```powershell
if ($MyInvocation.InvocationName -ne '.') { Invoke-SteamOptimization -SteamMode $Mode; exit $LASTEXITCODE }
```

### Step 5: Delete Merged Source

After merging, delete the source file:
```bash
rm Scripts/arc-raiders/steam.ps1
```

### Step 6: Update Dependencies

Check if other scripts imported the deleted file:
```powershell
rg "arc-raiders.*steam|steam.*arc-raiders" --type ps1
```

## Merge Checklist

1. Compare both scripts and document all differences
2. Create parameterized mode(s) using `ValidateSet`
3. Replace hardcoded values with conditional expressions
4. Merge helper functions (deduplicate `vdf_mkdir`, `sc-nonew`, etc.)
5. Update function signatures to accept mode parameter
6. Test both modes: `.\script.ps1 -Mode Default` and `.\script.ps1 -Mode ArcRaiders`
7. Delete merged source file
8. Verify no other files import the deleted script
9. Run `mise run lint` to ensure compliance
10. Update relevant test files if they referenced the merged script

## Anti-Patterns to Avoid

- ❌ Don't merge scripts with fundamentally different purposes
- ❌ Don't create more than 3 modes per script (use separate scripts instead)
- ❌ Don't inline mode-specific logic in multiple places — factor it out
- ❌ Don't delete source until tests pass for all modes

## Examples

### Steam Optimization Merge

```powershell
# Before: Two separate scripts with 80% overlap
Scripts/steam.ps1            # Default mode (NoGPU=1, SmallMode=1)
Scripts/arc-raiders/steam.ps1 # ArcRaiders mode (NoGPU=0, SmallMode=0)

# After: Single parameterized script
Scripts/steam.ps1            # -Mode Default | -Mode ArcRaiders
```

## Validation

After merging:
- Both modes execute without errors
- No duplicate functions remain
- `mise run lint` passes
- Tests for both modes pass (if applicable)
