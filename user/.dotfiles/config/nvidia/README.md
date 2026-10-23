# NVIDIA Configuration Files

NVIDIA driver tweaks, telemetry removal, and configuration files.

## Directory Structure

```
nvidia/
├── README.md                          # This file
├── nvidia-performance-tweaks.reg      # Consolidated performance tweaks (see below)
├── nvidia-cleanup.cmd                 # Unified shader-cache + telemetry/bloat cleanup
├── nvidia-settings.ps1                # Applies profiles/*.nip + legacy sharpening (-Mode Apply|Restore)
├── NVProfileInspectorPerf.txt         # Profile Inspector setting notes
├── profiles/                          # NVIDIA Profile Inspector profiles
│   └── new.nip                        # Main export: Base, Arc Raiders, BO6, Fortnite, Java, Minecraft, etc.
├── toggles/                           # Standalone enable/disable .reg pairs (HDCP, MPO, NIS, HW scheduling, P-State lock, DLSS indicator)
├── optional-tweaks/                   # Standalone opt-in .reg files (ECC, preemption, signature override, CUDA, OpenGL/Vulkan, ...)
├── nvcpl/                             # NVIDIA Control Panel context-menu utilities
└── msi-afterburner/                   # MSI Afterburner skin
```

## Quick Start

### 1. Apply Performance Tweaks

What it does:
- Enables maximum GPU performance mode
- Locks GPU to P-State 0 (maximum clocks)
- Optimizes memory management
- Enables multi-threading optimizations
- Disables unnecessary logging
- Optimizes display presentation (DirectFlip, Independent Flip)
- Enables NIS (NVIDIA Image Scaling)
- Disables HDCP (breaks DRM content like Netflix, but reduces latency)
- Disables preemption (lower latency, may cause rare TDR errors)

```cmd
:: Run as Administrator
regedit /s nvidia-performance-tweaks.reg

:: Reboot required
shutdown /r /t 0
```

**WARNING:** Disabling HDCP means Netflix/Prime Video/Disney+ won't play in browsers (use Windows apps instead), and some HDMI capture cards may not work.

### 2. Remove Telemetry

What it does:
- Disables all NVIDIA telemetry via registry
- Disables telemetry scheduled tasks
- Uninstalls telemetry packages
- Renames telemetry DLLs to `.OLD`
- Can debloat driver packages before installation

```cmd
:: Run as Administrator
nvidia-cleanup.cmd telemetry
```

For clean driver installs:
1. Download NVIDIA driver
2. Extract with 7-Zip
3. Copy `nvidia-cleanup.cmd` to extracted folder
4. Run `nvidia-cleanup.cmd telemetry` to remove bloat
5. Install driver with `setup.exe`

## Recommended Setup Procedure

### For New Driver Installation

1. Download driver from [NVIDIA Advanced Driver Search](https://www.nvidia.com/download/find.aspx) — choose Game Ready Driver (not Studio or Security update)

2. Extract driver with 7-Zip

3. Run debloat script:
   ```cmd
   cd path\to\extracted\driver
   copy path\to\nvidia-cleanup.cmd .
   nvidia-cleanup.cmd telemetry
   ```

4. Install driver:
   ```cmd
   setup.exe
   ```

5. Apply performance tweaks:
   ```cmd
   regedit /s nvidia-performance-tweaks.reg
   ```

6. Reboot system

7. Configure NVIDIA Control Panel (see guide below)

8. Apply NVIDIA Profile Inspector profile (optional)

## NVIDIA Control Panel Recommended Settings

### Manage 3D Settings — Global Settings

| Setting | Recommended Value | Notes |
|---------|------------------|-------|
| Anisotropic filtering | Off | Let games control this |
| Antialiasing - Gamma correction | Off | Reduces latency |
| Low Latency Mode | Ultra | Use On if game has NVIDIA Reflex |
| Power management mode | Prefer maximum performance | Critical for gaming |
| Shader Cache Size | Unlimited | Improves load times |
| Texture filtering - Quality | High performance | Lower latency |
| Threaded Optimization | Off | Better frame pacing (unless CPU bottlenecked) |
| Vertical sync | Use application setting | Let games control V-Sync |

### Change Resolution

| Setting | Value |
|---------|-------|
| Output dynamic range | Full |
| Resolution | Native resolution |
| Refresh rate | Maximum supported |

### Adjust Video Color Settings

| Setting | Value |
|---------|-------|
| Dynamic range | Full |

## Optional Tweaks & Quick Toggles

`nvidia-performance-tweaks.reg` is the consolidated baseline. Two folders hold standalone files you
apply individually with `regedit /s <file>`:

- `toggles/` - enable/disable pairs: HDCP, MPO, NIS, hardware GPU scheduling, P-State 0 lock,
  DLSS indicator.
- `optional-tweaks/` - opt-in extras: shader memory, CUDA, OpenGL/Vulkan, display scaling/VRR,
  Windows Game Mode, preemption on/off.

Two risky, non-performance files are in `optional-tweaks/` and should not be bulk-imported:
- `disable-ecc.reg` - only relevant for workstation GPUs (Quadro/Tesla); may cause instability.
- `enable-signature-override.reg` - enables Windows test-signing and disables driver integrity
  checks. Do not use unless modding drivers.

## NVIDIA Profile Inspector

### Download

- [Official (Orbmu2k)](https://github.com/Orbmu2k/nvidiaProfileInspector)
- [Revamped (xHybred)](https://github.com/xHybred/NvidiaProfileInspectorRevamped)

### Apply Profiles

1. Launch NVIDIA Profile Inspector
2. Click the import icon
3. Select `profiles/new.nip` (Base profile plus per-game profiles; DLSS overrides are per-game only)
4. Click "Apply changes"

### Key Settings to Check

**Global Profile:**
- Disable Ansel — Prevents unwanted injection
- CUDA - Force P2 State → Disable — Prevents memory downclocking
- Test Resizable BAR settings (rBAR Feature/Options/Size) if your game supports it

## Cleanup & Maintenance

### Remove Old Drivers (before updating)

1. Download [Display Driver Uninstaller (DDU)](https://www.guru3d.com/files-details/display-driver-uninstaller-download.html)
2. Boot into Safe Mode
3. Run DDU → Clean and Restart
4. Install new driver with debloat method above

### Check Telemetry Status

```powershell
# Check scheduled tasks
Get-ScheduledTask | Where-Object { $_.TaskName -like "*NvTm*" }

# Check telemetry services
Get-Service | Where-Object { $_.Name -like "*nvtelemetry*" }
```

## Shader Cache Cleanup

Clear NVIDIA shader caches to fix stuttering, crashes, or visual artifacts:

```cmd
:: Quick NVIDIA-only cleanup
nvidia-cleanup.cmd shader
```

When to use:
- After driver updates
- If games are stuttering or crashing
- If you see visual artifacts/corruption
- To free up disk space

For cleanup including Steam games:
```powershell
cd ~/Scripts
.\system-maintenance.ps1 -Action Shader
```

## PowerShell Scripts

| Script | What It Does |
|--------|--------------|
| `nvidia-settings.ps1` | Imports `profiles/*.nip` via Profile Inspector and toggles legacy sharpening; `-Mode Restore` reverts, `-Unattended` skips the GUI import |
| `Scripts/system-maintenance.ps1 -Action Shader` | Shader cache cleanup including Steam; the NVIDIA-only equivalent is `nvidia-cleanup.cmd shader` |
| `Scripts/system-settings-manager.ps1` | Interactive GPU/display and performance menu |

Use the registry files for quick toggles, automation, or when PowerShell is unavailable.

### Alternative: NVCleanstall

Customize official NVIDIA drivers during install without using modified drivers: [NVCleanstall](https://www.techpowerup.com/nvcleanstall/)

## Notes

### What's Included in Performance Tweaks

The `nvidia-performance-tweaks.reg` file consolidates these previously separate files:
- ~~Full experimental.reg~~ Merged
- ~~NVIDIA TWEAKS (EXPERIMENTAL).reg~~ Merged
- ~~Experimental Tweaks.reg~~ Merged
- ~~HDCP.reg~~ Merged
- ~~New NIS [Default].reg~~ Merged
- Preemption disabled by default (edit the file directly to restore it)

### What's Included in Telemetry Cleanup

The `nvidia-cleanup.cmd telemetry` routine consolidates:
- ~~Remove Telemetry.bat~~ Merged
- ~~NVIDIA.bat~~ Merged
- ~~Debloat.cmd~~ Merged

### GPU Index Note

Registry tweaks target GPU at:
```
HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000
```

The `0000` is the first GPU. If you have multiple GPUs, adjust accordingly (`0001` = second GPU, etc.). Check Device Manager → Display adapters → Properties → Details → Driver key to find your GPU index.

## Warnings & Disclaimers

1. **HDCP Disabled:** DRM content (Netflix, etc.) won't work in browsers
2. **Preemption Disabled:** May cause rare "driver stopped responding" errors
3. Always backup registry before applying tweaks
4. Reboot required after applying registry changes
5. Test in your specific games — not all tweaks work for everyone
6. Use at your own risk — tweaks may cause instability

## Resources

- [NVIDIA Advanced Driver Search](https://www.nvidia.com/download/find.aspx)
- [NVIDIA Profile Inspector (Orbmu2k)](https://github.com/Orbmu2k/nvidiaProfileInspector)
- [NVIDIA Profile Inspector Revamped](https://github.com/xHybred/NvidiaProfileInspectorRevamped)
- [Display Driver Uninstaller (DDU)](https://www.guru3d.com/files-details/display-driver-uninstaller-download.html)
- [Gaming PC Setup Research](https://github.com/djdallmann/GamingPCSetup)

---

**Maintainer:** Ven0m0
**Repository:** https://github.com/Ven0m0/Win
