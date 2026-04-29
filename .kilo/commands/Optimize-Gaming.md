# Optimize-Gaming

**Category:** Gaming Optimization
**Scope:** Fullscreen, MPO, shader cache, DLSS

## Synopsis

Comprehensive gaming performance tuning suite: applies fullscreen/GameConfig registry tweaks, clears shader caches, and forces DLSS to latest version.

## Description

Workflows executed:

| Step | Action | Script wrapper |
|------|--------|----------------|
| **Fullscreen & MPO** | Registry tweaks for exclusive fullscreen, multiplane overlay | `Scripts/gaming-display.ps1`, `Scripts/gpu-display-manager.ps1` |
| **Shader Cache** | Clears Steam, temp, NVIDIA/AMD shader caches | `Scripts/shader-cache.ps1` (with manual fallback) |
| **DLSS Update** | Forces latest DLSS DLLs across game directories | `Scripts/DLSS-force-latest.ps1` |

Creates a system restore point automatically (unless `-NoRestorePoint`), requires admin elevation, and supports `-WhatIf` for dry-run.

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-FullscreenOnly` | Switch | False | Only fullscreen/MPO tweaks |
| `-ClearShaderCacheOnly` | Switch | False | Only clear shader caches |
| `-UpdateDLSSOnly` | Switch | False | Only force-update DLSS |
| `-NoRestorePoint` | Switch | False | Skip restore point creation |
| `-WhatIf` | Switch | False | Show actions without making changes |

## Usage

```powershell
# Run all gaming optimizations
.\Optimize-Gaming.ps1

# Dry-run preview
.\Optimize-Gaming.ps1 -WhatIf

# Only clear shader caches
.\Optimize-Gaming.ps1 -ClearShaderCacheOnly

# Skip restore point creation (run after previous point exists)
.\Optimize-Gaming.ps1 -NoRestorePoint
```

## Exit Behavior

- Elevation check: relaunches as admin if not elevated
- Restore point: `Checkpoint-Computer` with `"Before gaming optimizations — <timestamp>"`
- Sub-script failures are logged but do not stop remaining steps
- Exit code `0` regardless of individual script failures (best-effort)

## Notes

- Real script: `Scripts/Optimize-Gaming.ps1`
- This `.md` is Kilo command reference.
- Sub-scripts must exist in `Scripts/` to execute; missing ones are skipped with warning.

## Related

- `Scripts/gaming-display.ps1` — fullscreen optimizations
- `Scripts/gpu-display-manager.ps1` — GPU-specific settings
- `Scripts/shader-cache.ps1` — cache cleanup
- `Scripts/DLSS-force-latest.ps1` — DLSS updater
- `New-RestorePointSafe.ps1` — manual restore point management
