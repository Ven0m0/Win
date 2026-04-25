# NVIDIA Configuration Files

NVIDIA driver tweaks, telemetry removal, and configuration files.

## Directory Structure

```
nvidia/
├── README.md                          # This file
├── XTREMEG.md                         # XtremeG custom drivers guide
├── SCRIPTS-REFERENCE.md               # PowerShell scripts integration guide
├── nvidia-performance-tweaks.reg      # Main performance optimizations (consolidated)
├── nvidia-telemetry-cleanup.cmd       # Complete telemetry removal script
├── nvidia-shader-cache-cleanup.cmd    # Clear NVIDIA shader caches
├── xtremeg-installer.ps1              # XtremeG custom driver installer
├── toggles/                           # Quick enable/disable settings
│   ├── disable-dlss-indicator.reg
│   ├── enable-dlss-indicator.reg
│   ├── enable-nis-new.reg
│   ├── disable-nis-new.reg
│   ├── enable-mpo.reg
│   ├── disable-mpo.reg
│   ├── enable-hardware-scheduling.reg
│   ├── disable-hardware-scheduling.reg
│   ├── enable-p-state-0-lock.reg
│   ├── disable-p-state-0-lock.reg
│   ├── enable-hdcp.reg
│   └── disable-hdcp.reg
├── optional-tweaks/                   # Advanced tweaks (use with caution)
│   ├── disable-ecc.reg
│   ├── disable-preemption.reg
│   ├── enable-preemption.reg
│   ├── enable-signature-override.reg
│   ├── enable-windows-game-mode.reg
│   ├── force-directflip.reg
│   ├── advanced-shader-memory-tweaks.reg
│   ├── cuda-optimizations.reg
│   ├── display-scaling-vrr.reg
│   └── opengl-vulkan-optimizations.reg
├── profiles/                          # NVIDIA Profile Inspector profiles
│   ├── Base.nip                       # Base profile (general settings)
│   ├── BlackOps6.nip                  # Black Ops 6 optimized
│   ├── Fortnite.nip                   # Fortnite optimized
│   └── Java.nip                       # Java/Minecraft optimized
├── nvcpl/                             # NVIDIA Control Panel utilities
└── archive/                           # Old/deprecated files (for reference)
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
nvidia-telemetry-cleanup.bat
```

For clean driver installs:
1. Download NVIDIA driver
2. Extract with 7-Zip
3. Copy `nvidia-telemetry-cleanup.bat` to extracted folder
4. Run it to remove bloat
5. Install driver with `setup.exe`

## Recommended Setup Procedure

### For New Driver Installation

1. Download driver from [NVIDIA Advanced Driver Search](https://www.nvidia.com/download/find.aspx) — choose Game Ready Driver (not Studio or Security update)

2. Extract driver with 7-Zip

3. Run debloat script:
   ```cmd
   cd path\to\extracted\driver
   copy path\to\nvidia-telemetry-cleanup.bat .
   nvidia-telemetry-cleanup.bat
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

## Optional Tweaks

Advanced tweaks. Only apply if you know what you're doing.

### Disable Preemption (Lower Latency, Risky)
```cmd
regedit /s optional-tweaks/disable-preemption.reg
```
- Lower input latency
- May cause black screens/TDR errors
- GPU tasks can't be interrupted
- Only for dedicated gaming PCs

### Enable Preemption (Restore Default)
```cmd
regedit /s optional-tweaks/enable-preemption.reg
```

### Disable ECC (Workstation GPUs Only)
```cmd
regedit /s optional-tweaks/disable-ecc.reg
```
- Only relevant for Quadro/Tesla GPUs
- GeForce GPUs don't have ECC

### Force DirectFlip
```cmd
regedit /s optional-tweaks/force-directflip.reg
```
- Forces DirectFlip presentation mode
- May cause issues with overlays (Discord, MSI Afterburner, etc.)

### Enable Signature Override (VERY RISKY)
```cmd
:: Do not use this unless you're modding drivers.
:: This disables driver signature verification.
:: May prevent Windows updates.
:: May cause system instability.

:: Use Scripts/gpu-display-manager.ps1 to toggle this safely.
regedit /s optional-tweaks/enable-signature-override.reg
bcdedit /set nointegritychecks on
bcdedit /set testsigning on
```

### Advanced Community Tweaks

#### Shader Cache & Memory Optimizations

What it does:
- Enables unlimited shader cache size
- Optimizes shader cache location (manual SSD path option)
- Increases TDR delays to prevent false positives
- Sets WDDM mode to 2.x for Windows 10+
- DX12 on hybrid/Optimus systems

```cmd
regedit /s optional-tweaks/advanced-shader-memory-tweaks.reg
```

Notes:
- Shader cache will grow over time (monitor disk space)
- Optionally edit the file to set custom cache path to SSD

#### CUDA Optimizations

What it does:
- Disables CUDA Force P2 State (prevents memory downclocking during compute)
- Sets CUDA sysmem fallback policy to prefer local memory
- Disables compute preemption for lower latency

```cmd
regedit /s optional-tweaks/cuda-optimizations.reg
```

Notes:
- Most beneficial for workloads mixing gaming and compute
- Compute preemption disabled may reduce stability in heavy compute tasks
- Also configurable via NVIDIA Profile Inspector (CUDA - Force P2 State)

**WARNING:** Disabling compute preemption reduces multitasking capability. Only use on dedicated gaming systems.

#### Display Scaling & VRR (Variable Refresh Rate)

What it does:
- Forces GPU scaling instead of display scaling
- Sets maximum color depth (10-bit if supported)
- Sets RGB color format
- Enables Variable Refresh Rate (G-SYNC/FreeSync)
- Disables refresh rate switching (keeps at max)
- Enables Ultra Low Latency Mode

```cmd
regedit /s optional-tweaks/display-scaling-vrr.reg
```

Notes:
- Verify your monitor supports 10-bit color before expecting benefits
- G-SYNC Compatible requires compatible FreeSync monitor
- Some of these settings can also be set via NVIDIA Control Panel
- Commented MPO setting (use toggles instead)

#### OpenGL & Vulkan Optimizations

What it does:
- Disables OpenGL triple buffering (reduces input lag)
- Enables Vulkan heap budget optimization
- Enables Vulkan timeline semaphores
- Disables OpenGL overlay
- Forces maximum OpenGL performance
- Enables threaded optimization for D3D9/D3D11

```cmd
regedit /s optional-tweaks/opengl-vulkan-optimizations.reg
```

Notes:
- OpenGL is used by older games (pre-2010s) and some emulators
- Vulkan is used by modern titles (DOOM Eternal, Cyberpunk 2077, etc.)
- Threaded optimization should be tested per-game per NVIDIA guidance
- Some settings are better controlled via NVIDIA Control Panel

## NVIDIA Profile Inspector

### Download

- [Official (Orbmu2k)](https://github.com/Orbmu2k/nvidiaProfileInspector)
- [Revamped (xHybred)](https://github.com/xHybred/NvidiaProfileInspectorRevamped)

### Apply Profiles

1. Launch NVIDIA Profile Inspector
2. Click the import icon
3. Select a profile from `profiles/` directory:
   - `Base.nip` — Base profile with general settings
   - `BlackOps6.nip` — Black Ops 6 specific
   - `Fortnite.nip` — Fortnite specific
   - `Java.nip` — Java/Minecraft specific
4. Click "Apply changes"

### Key Settings to Check

**Global Profile:**
- Disable Ansel — Prevents unwanted injection
- CUDA - Force P2 State → Disable — Prevents memory downclocking
- Test Resizable BAR settings (rBAR Feature/Options/Size) if your game supports it

## Quick Toggles

### DLSS Indicator

```cmd
:: Hide DLSS indicator
regedit /s toggles/disable-dlss-indicator.reg

:: Show DLSS indicator (for testing)
regedit /s toggles/enable-dlss-indicator.reg
```

### NVIDIA Image Scaling (NIS)

```cmd
:: Enable NIS (for driver 535+)
regedit /s toggles/enable-nis-new.reg

:: Disable NIS
regedit /s toggles/disable-nis-new.reg
```

### Multiplane Overlay (MPO)

Fix flickering/tearing in games:

```cmd
:: Disable MPO (fixes flickering in some games)
regedit /s toggles/disable-mpo.reg

:: Enable MPO (Windows default)
regedit /s toggles/enable-mpo.reg
```

Reboot required after MPO changes.

### Hardware-Accelerated GPU Scheduling

Windows 10 2004+ feature (requires compatible GPU):

```cmd
:: Enable (for RTX 20/30/40 series)
regedit /s toggles/enable-hardware-scheduling.reg

:: Disable
regedit /s toggles/disable-hardware-scheduling.reg
```

Reboot required. Verify in Windows Settings → Display → Graphics.

### P-State 0 Lock

```cmd
:: Force max clocks
regedit /s toggles/enable-p-state-0-lock.reg

:: Restore dynamic clocking
regedit /s toggles/disable-p-state-0-lock.reg
```

### HDCP

```cmd
:: Disable HDCP (lower latency, breaks Netflix/DRM)
regedit /s toggles/disable-hdcp.reg

:: Enable HDCP (restore DRM support)
regedit /s toggles/enable-hdcp.reg
```

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
nvidia-shader-cache-cleanup.cmd
```

When to use:
- After driver updates
- If games are stuttering or crashing
- If you see visual artifacts/corruption
- To free up disk space

For cleanup including Steam games:
```powershell
cd ~/Scripts
.\shader-cache.ps1
```

See [SCRIPTS-REFERENCE.md](SCRIPTS-REFERENCE.md) for detailed comparison.

## PowerShell Scripts Integration

This directory contains static registry files extracted from interactive PowerShell scripts:

| PowerShell Script | What It Does | Equivalent Registry Files |
|-------------------|--------------|---------------------------|
| `Scripts/gpu-display-manager.ps1` | Interactive menu for GPU/display settings | P-State, HDCP, MPO toggles |
| `Scripts/DLSS-force-latest.ps1` | Force latest DLSS, overlay toggle | DLSS indicator toggles |
| `Scripts/shader-cache.ps1` | Cache cleanup with Steam integration | `nvidia-shader-cache-cleanup.bat` |

- Use scripts for interactive menus and advanced features (MSI Mode, EDID Override)
- Use registry files for quick toggles, automation, or when PowerShell is unavailable

See [SCRIPTS-REFERENCE.md](SCRIPTS-REFERENCE.md) for the complete integration guide.

## XtremeG Custom Drivers (Advanced Users Only)

**WARNING: XtremeG drivers are UNOFFICIAL, MODIFIED drivers — not from NVIDIA.**

- Use at your own risk
- May void warranty
- No official support
- May cause instability

Only for advanced users who understand the risks.

XtremeG = Community-modified NVIDIA drivers with telemetry removed, bloatware stripped, and performance tweaks pre-applied. Source: [r/XtremeG](https://www.reddit.com/r/XtremeG)

### Quick Install

```powershell
# Run as Administrator
.\xtremeg-installer.ps1
```

The script guides through downloading from MEGA.nz, optionally running DDU, and installing the driver.

### Manual Install

1. Visit [r/XtremeG](https://www.reddit.com/r/XtremeG)
2. Download latest driver from MEGA.nz link
3. Extract ZIP/7z file
4. Run `setup.exe` as Administrator
5. Reboot

### Comparison

| Feature | Official NVIDIA | XtremeG | Official + Our Tweaks |
|---------|----------------|---------|----------------------|
| Source | NVIDIA | Modified | NVIDIA |
| Safety | Official | Unofficial | Official |
| Size | ~700MB | ~400MB | ~700MB |
| Telemetry | Yes | Removed | You remove |
| Bloat | Yes (GFE) | Removed | You remove |
| Tweaks | Default | Pre-applied | You apply |
| Updates | Auto (GFE) | Manual | Manual |
| Support | Official | Community | Official |

For most users, official drivers + our tweaks is the better balance of safety and performance.

### Alternative: NVCleanstall

Customize official NVIDIA drivers during install without using modified drivers: [NVCleanstall](https://www.techpowerup.com/nvcleanstall/)

See [XTREMEG.md](XTREMEG.md) for the complete installation guide and troubleshooting.

## Notes

### What's Included in Performance Tweaks

The `nvidia-performance-tweaks.reg` file consolidates these previously separate files:
- ~~Full experimental.reg~~ Merged
- ~~NVIDIA TWEAKS (EXPERIMENTAL).reg~~ Merged
- ~~Experimental Tweaks.reg~~ Merged
- ~~HDCP.reg~~ Merged
- ~~New NIS [Default].reg~~ Merged
- Preemption disabled by default (can be toggled in `optional-tweaks/`)

### What's Included in Telemetry Cleanup

The `nvidia-telemetry-cleanup.bat` script consolidates:
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