---
description: Apply gaming performance optimizations — fullscreen registry tweaks, MPO, shader cache, DLSS update
allowed-tools: Read, Glob, Grep, Bash
---

Apply gaming performance optimizations. $ARGUMENTS

Read the relevant scripts first to understand current state, then guide the user:

**Full gaming optimization suite:**

```powershell
# Requires elevated session
pwsh -File Scripts/Optimize-Gaming.ps1

# Dry-run preview
pwsh -File Scripts/Optimize-Gaming.ps1 -WhatIf

# Skip restore point (if one was created recently)
pwsh -File Scripts/Optimize-Gaming.ps1 -NoRestorePoint
```

**Targeted optimizations:**

```powershell
# Only fullscreen/MPO registry tweaks
pwsh -File Scripts/gpu-display-manager.ps1

# Only clear shader caches (Steam, NVIDIA, temp)
pwsh -File Scripts/system-maintenance.ps1 -Action Shader

# Force latest DLSS DLLs across game directories
pwsh -File Scripts/DLSS-force-latest.ps1
```

**What each step does:**

- **Fullscreen & MPO**: registry tweaks under `HKCU:\System\GameConfig` for exclusive fullscreen; NVIDIA MultiPlane Overlay disable
- **Shader cache**: clears `%LOCALAPPDATA%\Temp`, Steam shader cache, NVIDIA/AMD cache directories
- **DLSS update**: finds DLSS `.dll` files in game directories and replaces with latest version

A restore point is created automatically before changes. To undo, use the restore point created by the script or pass `-Restore` to individual tweak scripts.

If the user wants to add a new game-specific optimization, read `Scripts/arc-raiders/game-boost.ps1` as a reference for the pattern.
