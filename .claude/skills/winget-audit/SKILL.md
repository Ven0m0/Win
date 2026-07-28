---
name: winget-audit
description: Diff currently installed winget packages against Scripts/packages.psd1 to find installed-but-untracked and tracked-but-missing packages. Use when the user says "audit winget packages", "check packages.psd1", or "what's installed but not tracked".
disable-model-invocation: true
---

# Winget Package Audit

One-shot diff between what's actually installed on this machine and the
canonical catalog in `Scripts/packages.psd1`.

## Steps

1. Export the canonical list:

```powershell
$catalog = Import-PowerShellDataFile -Path (Join-Path $PSScriptRoot '..\..\..\Scripts\packages.psd1')
$trackedIds = $catalog.Values | Where-Object { $_ -is [array] } | ForEach-Object { $_ } | Sort-Object -Unique
```

2. Export what's actually installed:

```powershell
$installed = winget list --accept-source-agreements | Out-String
```

`winget list` output is columnar text, not structured — parse the `Id` column
by fixed-width or fall back to `winget export -o - ` (JSON) if available on
the installed winget version for reliable parsing.

3. Diff:
   - **Installed, not in `packages.psd1`**: candidate to add to the catalog
     (or a one-off install that shouldn't be tracked — flag for the user to decide)
   - **In `packages.psd1`, not installed**: either not yet applied on this
     machine, or the catalog has stale entries

## Output

```
### Installed but untracked (N)
- <Id> — <Name>

### Tracked but not installed (N)
- <Id> — under key <WingetXxx>
```

End with: "Untracked packages found on this machine only reflect this
machine's state — confirm before adding to the shared catalog."
