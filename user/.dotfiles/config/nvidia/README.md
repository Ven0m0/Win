# NVIDIA Configuration Files

NVIDIA driver tweaks, telemetry removal, and configuration files.

## Directory Structure

```
nvidia/
├── README.md                          # This file
├── XTREMEG.md                         # XtremeG custom drivers guide
├── SCRIPTS-REFERENCE.md               # PowerShell scripts integration guide
├── nvidia-performance-tweaks.reg      # All performance tweaks, fully consolidated (see below)
├── nvidia-cleanup.cmd                 # Unified shader-cache + telemetry/bloat cleanup
├── xtremeg-installer.ps1              # XtremeG custom driver installer
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

Formerly split across `optional-tweaks/` and `toggles/`, everything is now folded directly into
`nvidia-performance-tweaks.reg` — shader cache, CUDA, OpenGL/Vulkan, VRR/display scaling, DirectFlip,
Windows Game Mode, DLSS indicator, MPO, and hardware GPU scheduling all apply with the single
`regedit /s nvidia-performance-tweaks.reg` command above.

For enable/disable pairs (HDCP, MPO, NIS, HW scheduling, P-State lock, DLSS indicator, preemption),
the file keeps the performance-oriented side active. To flip one back to its default/off state, edit
the corresponding value directly in `nvidia-performance-tweaks.reg` (each section is labeled with a
comment noting its origin).

Two risky, non-performance tweaks are present but **commented out** near the end of the file so a
bulk import never applies them:
- **Disable ECC** — only relevant for workstation GPUs (Quadro/Tesla); may cause instability.
- **Enable Signature Override** — enables Windows test-signing and disables driver integrity checks.
  Do not use unless modding drivers. Use `Scripts/gpu-display-manager.ps1` to toggle this safely instead.

Uncomment the relevant block manually and re-import if you need either of these.

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

See [SCRIPTS-REFERENCE.md](SCRIPTS-REFERENCE.md) for detailed comparison.

## PowerShell Scripts Integration

This directory contains static registry files extracted from interactive PowerShell scripts:

| PowerShell Script | What It Does | Equivalent Registry Files |
|-------------------|--------------|---------------------------|
| `Scripts/gpu-display-manager.ps1` | Interactive menu for GPU/display settings | P-State, HDCP, MPO toggles |
| `Scripts/DLSS-force-latest.ps1` | Force latest DLSS, overlay toggle | DLSS indicator toggles |
| `Scripts/system-maintenance.ps1 -Action Shader` | Cache cleanup with Steam integration | `nvidia-cleanup.cmd shader` |

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
- ~~toggles/ (12 files)~~ Merged — performance side kept active per pair
- ~~optional-tweaks/ (10 files)~~ Merged — risky ECC/signature-override entries kept but commented out
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
