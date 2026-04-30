---
name: dead-code-cleanup
description: |
  Remove dead code, commented-out blocks, and redundant conditionals from PowerShell scripts.
  Use when cleaning up Scripts/*.ps1 or removing unreachable branches.
compatibility: opencode
---

# Dead Code Cleanup Skill

Load this skill when removing commented-out code, unused variables, unreachable branches, or simplifying redundant conditionals.

## When to Load

- "Remove dead code from Scripts/..."
- "Clean up commented-out debug lines"
- "Simplify if-else blocks that only have comments"
- "Strip unused variables and imports"

## Patterns to Target

### 1. Commented-Out Debug Lines
```powershell
# Remove these:
#Write-Host "Powershell"
#Write-Host "Registry"
#Write-Host " Setting X to value Y"
#cls
```

### 2. Commented-Out Fallback Logic
```powershell
# Remove these:
#if ($null -eq $cb_Value.Text -or $cb_Value.Text -eq '' ){
#    $cb_Value.Text='65536'

##Bypass
##Set-NetOffloadGlobalSetting -NetworkDirect $value
```

### 3. Empty If/Else Branches
```powershell
# Before: Useless conditional with only comments
if ($cb_osrss.text -eq $current) {
    #Write-Host " same as Current, skipping."
} else {
    Write-Host "Applying..."
    Set-NetOffloadGlobalSetting -ReceiveSideScaling $cb_osrss.text
}

# After: Simplified
if ($cb_osrss.text -ne $current) {
    Write-Host "Applying..."
    Set-NetOffloadGlobalSetting -ReceiveSideScaling $cb_osrss.text
}
```

### 4. Commented Variable Assignments
```powershell
# Remove these:
#$RegITR = (Get-ItemPropertyValue -Path "$KeyPath" -Name "ITR")
#$AdapterStatus = Get-NetAdapter
```

## Cleanup Checklist

1. Search for commented-out code: `rg "^\s*#\s*(Write-|Set-|Get-|if|foreach|function)" --type ps1`
2. Verify each match is truly dead (not documentation or future feature notes)
3. Remove the commented lines
4. Simplify any conditionals that now have empty branches
5. Remove trailing blank lines left by deletions
6. Verify syntax: `pwsh -Command "[System.Management.Automation.PSParser]::Tokenize(...)"`
7. Run `mise run lint`

## Safety Rules

- ✅ Keep comments that explain **why** code exists
- ✅ Keep TODO/FIXME comments (they indicate pending work)
- ❌ Remove comments that **repeat** what code already does
- ❌ Remove commented-out code blocks (git has the history)
- ❌ Remove debug output that was commented out instead of deleted

## Search Commands

```bash
# Find commented function calls
rg "^\s*#\s*(Write-Host|Write-Verbose|Set-|Get-|Invoke-|Remove-)" --type ps1

# Find commented conditionals
rg "^\s*#if\s*\(" --type ps1

# Find double-commented lines (likely abandoned code)
rg "^##" --type ps1
```

## Validation

After cleanup:
- Script parses without syntax errors
- `mise run lint` passes
- No functional behavior changed (only comments removed)
