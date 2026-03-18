# NVIDIA Configuration Files

Optimized and consolidated NVIDIA driver tweaks, telemetry removal, and configuration files.

## 📁 Directory Structure

```
nvidia/
├── README.md                          # This file
├── XTREMEG.md                         # XtremeG custom drivers guide
├── SCRIPTS-REFERENCE.md               # PowerShell scripts integration guide
├── nvidia-performance-tweaks.reg      # ⭐ Main performance optimizations (consolidated)
├── nvidia-telemetry-cleanup.bat      # ⭐ Complete telemetry removal script
├── nvidia-shader-cache-cleanup.bat   # ⭐ Clear NVIDIA shader caches
├── xtremeg-installer.ps1              # 🔥 XtremeG custom driver installer (advanced)
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
├── optional-tweaks/                   # Advanced/risky tweaks (use with caution!)
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
│   ├── Best.nip                       # General performance profile
│   ├── Settings.nip                   # Custom settings profile
│   ├── Bo6.nip                        # Black Ops 6 optimized
│   └── Bo6-light.nip                  # Black Ops 6 light version
├── nvcpl/                            # NVIDIA Control Panel utilities
└── archive/                          # Old/deprecated files (for reference)
```

## 🚀 Quick Start

### 1. **Apply Performance Tweaks** (Recommended)

**What it does:**
- Enables maximum GPU performance mode
- Locks GPU to P-State 0 (maximum clocks)
- Optimizes memory management
- Enables multi-threading optimizations
- Disables unnecessary logging
- Optimizes display presentation (DirectFlip, Independent Flip)
- Enables NIS (NVIDIA Image Scaling)
- **Disables HDCP** (breaks DRM content like Netflix, but improves latency)
- **Disables preemption** (lower latency, may cause rare TDR errors)

**How to apply:**
```cmd
# Run as Administrator
regedit /s nvidia-performance-tweaks.reg

# Reboot required
shutdown /r /t 0
```

**⚠️ WARNING:** This disables HDCP, which means:
- ❌ Netflix/Prime Video/Disney+ won't play in browser (use Windows apps instead)
- ❌ Some HDMI capture cards may not work
- ✅ Lower input latency in games
- ✅ Better performance

### 2. **Remove Telemetry & Bloat**

**What it does:**
- Disables all NVIDIA telemetry via registry
- Disables telemetry scheduled tasks
- Uninstalls telemetry packages
- Renames telemetry DLLs to `.OLD`
- Can debloat driver packages before installation

**How to run:**
```cmd
# Run as Administrator
nvidia-telemetry-cleanup.bat
```

**Pro tip:** For clean driver installs:
1. Download NVIDIA driver
2. Extract with 7-Zip
3. Copy `nvidia-telemetry-cleanup.bat` to extracted folder
4. Run it to remove bloat
5. Install driver with `setup.exe`

## 🎮 Recommended Setup Procedure

### For New Driver Installation:

1. **Download driver** from [NVIDIA Advanced Driver Search](https://www.nvidia.com/download/find.aspx)
   - Choose **Game Ready Driver** (not Studio or Security update)

2. **Extract driver** with 7-Zip

3. **Run debloat script:**
   ```cmd
   cd path\to\extracted\driver
   copy path\to\nvidia-telemetry-cleanup.bat .
   nvidia-telemetry-cleanup.bat
   ```

4. **Install driver:**
   ```cmd
   setup.exe
   ```

5. **Apply performance tweaks:**
   ```cmd
   regedit /s nvidia-performance-tweaks.reg
   ```

6. **Reboot system**

7. **Configure NVIDIA Control Panel** (see guide below)

8. **Apply NVIDIA Profile Inspector profile** (optional)

## 🎯 NVIDIA Control Panel Recommended Settings

### Manage 3D Settings → Global Settings

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

## 📊 Optional Tweaks

These are more advanced/risky tweaks. Only apply if you know what you're doing!

### Disable Preemption (Lower Latency, Risky)
```cmd
regedit /s optional-tweaks/disable-preemption.reg
```
- ✅ Lower input latency
- ❌ May cause black screens/TDR errors
- ❌ GPU tasks can't be interrupted
- **Recommended:** Only for dedicated gaming PCs

### Enable Preemption (Restore Default)
```cmd
regedit /s optional-tweaks/enable-preemption.reg
```
- Use this to restore Windows default behavior if you have issues

### Disable ECC (Workstation GPUs Only)
```cmd
regedit /s optional-tweaks/disable-ecc.reg
```
- Only relevant for Quadro/Tesla GPUs
- GeForce GPUs don't have ECC anyway

### Force DirectFlip
```cmd
regedit /s optional-tweaks/force-directflip.reg
```
- Forces DirectFlip presentation mode
- May cause issues with overlays (Discord, MSI Afterburner, etc.)

### Enable Signature Override (⚠️ VERY RISKY!)
```cmd
# DO NOT use this unless you're modding drivers!
# This disables driver signature verification
# May prevent Windows updates
# May cause system instability

# Recommended: Use Scripts/gpu-display-manager.ps1 to toggle this safely
regedit /s optional-tweaks/enable-signature-override.reg
bcdedit /set nointegritychecks on
bcdedit /set testsigning on
```

### Advanced Community Tweaks

These tweaks are based on well-established performance tuning practices from the NVIDIA community, tech forums, and advanced user testing.

#### Shader Cache & Memory Optimizations

**What it does:**
- Enables unlimited shader cache size
- Optimizes shader cache location (manual SSD path option)
- Increases TDR (Timeout Detection and Recovery) delays to prevent false positives
- Sets WDDM mode to 2.x for Windows 10+
- DX12 on hybrid/Optimus systems

**How to apply:**
```cmd
regedit /s optional-tweaks/advanced-shader-memory-tweaks.reg
```

**Benefits:**
- ✅ Faster shader loading after first compile
- ✅ Reduced stuttering in games
- ✅ Prevents driver timeout errors under heavy load

**Notes:**
- Shader cache will grow over time (monitor disk space)
- Optionally edit the file to set custom cache path to SSD

#### CUDA Optimizations

**What it does:**
- Disables CUDA Force P2 State (prevents memory downclocking during compute)
- Sets CUDA sysmem fallback policy to prefer local memory
- Disables compute preemption for lower latency

**How to apply:**
```cmd
regedit /s optional-tweaks/cuda-optimizations.reg
```

**Benefits:**
- ✅ Better performance in CUDA-accelerated applications
- ✅ Prevents memory clock throttling during compute tasks
- ✅ Lower latency for GPU compute workloads

**Notes:**
- Most beneficial for workloads mixing gaming and compute
- Compute preemption disabled may reduce stability in heavy compute tasks
- Also configurable via NVIDIA Profile Inspector (CUDA - Force P2 State)

**⚠️ WARNING:** Disabling compute preemption reduces multitasking capability. Only use on dedicated gaming systems.

#### Display Scaling & VRR (Variable Refresh Rate)

**What it does:**
- Forces GPU scaling instead of display scaling
- Sets maximum color depth (10-bit if supported)
- Sets RGB color format
- Enables Variable Refresh Rate (G-SYNC/FreeSync)
- Disables refresh rate switching (keeps at max)
- Enables Ultra Low Latency Mode

**How to apply:**
```cmd
regedit /s optional-tweaks/display-scaling-vrr.reg
```

**Benefits:**
- ✅ GPU scaling has better quality than display scaling
- ✅ Maximum color output (10-bit on supported monitors)
- ✅ G-SYNC Compatible mode for FreeSync monitors
- ✅ Locked maximum refresh rate
- ✅ Ultra low latency mode

**Notes:**
- Verify your monitor supports 10-bit color before expecting benefits
- G-SYNC Compatible requires compatible FreeSync monitor
- Better to set some of these via NVIDIA Control Panel for easier toggling
- Commented MPO setting (use toggles instead)

#### OpenGL & Vulkan Optimizations

**What it does:**
- Disables OpenGL triple buffering (reduces input lag)
- Enables Vulkan heap budget optimization
- Enables Vulkan timeline semaphores
- Disables OpenGL overlay
- Forces maximum OpenGL performance
- Enables threaded optimization for D3D9/D3D11

**How to apply:**
```cmd
regedit /s optional-tweaks/opengl-vulkan-optimizations.reg
```

**Benefits:**
- ✅ Lower input latency in OpenGL games
- ✅ Better Vulkan memory management
- ✅ Reduced API overhead
- ✅ Better multi-threaded API performance

**Notes:**
- OpenGL is used by older games (pre-2010s) and some emulators
- Vulkan is used by modern titles (DOOM Eternal, Cyberpunk 2077, etc.)
- Threaded optimization "use with caution" per NVIDIA - test in your games
- Some settings better controlled via NVIDIA Control Panel

**When to use:**
- You play older OpenGL games or use emulators
- You play modern Vulkan games
- You want to squeeze every bit of performance
- You've already applied main tweaks and want more

## 🔧 NVIDIA Profile Inspector

### Download & Install

Download NVIDIA Profile Inspector from one of these sources:
- [Official (Orbmu2k)](https://github.com/Orbmu2k/nvidiaProfileInspector)
- [Revamped (xHybred)](https://github.com/xHybred/NvidiaProfileInspectorRevamped) ⭐ Recommended

### Apply Profiles

1. Launch NVIDIA Profile Inspector
2. Click the import icon (📁)
3. Select a profile from `profiles/` directory:
   - `Best.nip` - General gaming optimizations
   - `Settings.nip` - Custom settings
   - `Bo6.nip` - Black Ops 6 specific
4. Click "Apply changes"

### Key Settings to Check

**Global Profile:**
- ✅ **Disable Ansel** - Prevents unwanted injection
- ✅ **CUDA - Force P2 State** → Disable - Prevents memory downclocking
- Test **Resizable BAR** settings (rBAR Feature/Options/Size) if your game supports it

## 🎚️ Quick Toggles

### DLSS Indicator

Show/hide the DLSS indicator overlay in games:

```cmd
# Hide DLSS indicator (recommended)
regedit /s toggles/disable-dlss-indicator.reg

# Show DLSS indicator (for testing)
regedit /s toggles/enable-dlss-indicator.reg
```

### NVIDIA Image Scaling (NIS)

Enable/disable NIS upscaling technology:

```cmd
# Enable NIS (for driver 535+)
regedit /s toggles/enable-nis-new.reg

# Disable NIS
regedit /s toggles/disable-nis-new.reg
```

## 🧹 Cleanup & Maintenance

### Remove Old Drivers (Recommended before updating)

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

## 📝 Notes

### What's Included in Performance Tweaks

The `nvidia-performance-tweaks.reg` file consolidates these previously separate files:
- ~~Full experimental.reg~~ ✅ Merged
- ~~NVIDIA TWEAKS (EXPERIMENTAL).reg~~ ✅ Merged
- ~~Experimental Tweaks.reg~~ ✅ Merged
- ~~HDCP.reg~~ ✅ Merged
- ~~New NIS [Default].reg~~ ✅ Merged
- Preemption disabled by default (can be toggled in `optional-tweaks/`)

### What's Included in Telemetry Cleanup

The `nvidia-telemetry-cleanup.bat` script consolidates:
- ~~Remove Telemetry.bat~~ ✅ Merged
- ~~NVIDIA.bat~~ ✅ Merged
- ~~Debloat.cmd~~ ✅ Merged

### GPU Index Note

Registry tweaks target GPU at:
```
HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000
```

The `0000` is the first GPU. If you have multiple GPUs, you may need to adjust:
- `0000` = First GPU
- `0001` = Second GPU
- etc.

Check Device Manager → Display adapters → Properties → Details → Driver key to find your GPU index.

## ⚠️ Warnings & Disclaimers

1. **HDCP Disabled:** DRM content (Netflix, etc.) won't work in browsers
2. **Preemption Disabled:** May cause rare "driver stopped responding" errors
3. **Always backup registry** before applying tweaks
4. **Reboot required** after applying registry changes
5. **Test in your specific games** - not all tweaks work for everyone
6. **Use at your own risk** - tweaks may cause instability

## 🔗 Resources

- [NVIDIA Advanced Driver Search](https://www.nvidia.com/download/find.aspx)
- [NVIDIA Profile Inspector (Orbmu2k)](https://github.com/Orbmu2k/nvidiaProfileInspector)
- [NVIDIA Profile Inspector Revamped](https://github.com/xHybred/NvidiaProfileInspectorRevamped)
- [Display Driver Uninstaller (DDU)](https://www.guru3d.com/files-details/display-driver-uninstaller-download.html)
- [Gaming PC Setup Research](https://github.com/djdallmann/GamingPCSetup)

## 📜 Changelog

### 2025-12-29 - Advanced Community Tweaks
- ✅ Added `optional-tweaks/advanced-shader-memory-tweaks.reg`
- ✅ Added `optional-tweaks/cuda-optimizations.reg`
- ✅ Added `optional-tweaks/display-scaling-vrr.reg`
- ✅ Added `optional-tweaks/opengl-vulkan-optimizations.reg`
- ✅ Comprehensive documentation for all advanced tweaks

### 2025-12-29 - XtremeG Custom Driver Support
- ✅ Added `XTREMEG.md` comprehensive guide
- ✅ Added `xtremeg-installer.ps1` automated installer
- ✅ Documentation for unofficial driver installation

### 2025-12-29 - Scripts Integration
- ✅ Added 8 new toggle files (MPO, Hardware Scheduling, P-State, HDCP)
- ✅ Added `nvidia-shader-cache-cleanup.bat`
- ✅ Created `SCRIPTS-REFERENCE.md` integration guide

### 2025-12-29 - Major Cleanup
- ✅ Consolidated 3 experimental reg files into `nvidia-performance-tweaks.reg`
- ✅ Consolidated 3 telemetry scripts into `nvidia-telemetry-cleanup.bat`
- ✅ Organized into logical subdirectories (`toggles/`, `optional-tweaks/`, `profiles/`)
- ✅ Removed duplicate and redundant files
- ✅ Created comprehensive documentation
- ✅ Optimized registry tweaks (removed duplicates, added comments)
- ✅ Separated risky tweaks into `optional-tweaks/`

---

**Last Updated:** 2025-12-29
**Maintainer:** Ven0m0
**Repository:** https://github.com/Ven0m0/Win

## 🔧 Additional Toggles (From Scripts Integration)

### Multiplane Overlay (MPO)

Fix flickering/tearing in games like Black Ops 6:

```cmd
# Disable MPO (recommended for gaming, fixes flickering)
regedit /s toggles/disable-mpo.reg

# Enable MPO (Windows default, better for video playback)
regedit /s toggles/enable-mpo.reg
```

**Note:** Reboot required after MPO changes.

### Hardware-Accelerated GPU Scheduling

Windows 10 2004+ feature for lower latency (requires compatible GPU):

```cmd
# Enable (recommended for RTX 20/30/40 series)
regedit /s toggles/enable-hardware-scheduling.reg

# Disable (if you have issues or older GPU)
regedit /s toggles/disable-hardware-scheduling.reg
```

**Note:** Reboot required. Check Windows Settings → Display → Graphics to verify it's enabled.

### P-State 0 Lock Toggles

Individual toggles for P-State 0 (included in main tweaks, use these to revert):

```cmd
# Force max clocks (best for gaming)
regedit /s toggles/enable-p-state-0-lock.reg

# Restore dynamic clocking (saves power when idle)
regedit /s toggles/disable-p-state-0-lock.reg
```

### HDCP Toggles

Individual toggles for HDCP (included in main tweaks, use these to revert):

```cmd
# Disable HDCP (lower latency, breaks Netflix/DRM)
regedit /s toggles/disable-hdcp.reg

# Enable HDCP (restore DRM support)
regedit /s toggles/enable-hdcp.reg
```

## 🧼 Shader Cache Cleanup

Clear NVIDIA shader caches to fix stuttering, crashes, or visual artifacts:

```cmd
# Quick NVIDIA-only cleanup
nvidia-shader-cache-cleanup.bat
```

**When to use:**
- After driver updates
- If games are stuttering or crashing
- If you see visual artifacts/corruption
- To free up disk space

**Advanced:** For comprehensive cleanup including Steam games:
```powershell
cd ~/Scripts
.\shader-cache.ps1
```

See [SCRIPTS-REFERENCE.md](SCRIPTS-REFERENCE.md) for detailed comparison.

## 📚 PowerShell Scripts Integration

This directory contains static registry files extracted from interactive PowerShell scripts:

| PowerShell Script | What It Does | Equivalent Registry Files |
|-------------------|--------------|---------------------------|
| `Scripts/gpu-display-manager.ps1` | Interactive menu for GPU/display settings | P-State, HDCP, MPO toggles |
| `Scripts/DLSS-force-latest.ps1` | Force latest DLSS, overlay toggle | DLSS indicator toggles |
| `Scripts/shader-cache.ps1` | Comprehensive cache cleanup with Steam | `nvidia-shader-cache-cleanup.bat` |

**When to use scripts vs registry files:**
- **Use Scripts:** Interactive menus, advanced features (MSI Mode, EDID Override)
- **Use Registry Files:** Quick toggles, automation, no PowerShell needed

See [SCRIPTS-REFERENCE.md](SCRIPTS-REFERENCE.md) for complete integration guide.


## 🔥 XtremeG Custom Drivers (Advanced Users Only)

### ⚠️ CRITICAL WARNING

**XtremeG drivers are UNOFFICIAL, MODIFIED drivers - NOT from NVIDIA!**

- ❌ **Use at your own risk**
- ❌ **May void warranty**
- ❌ **No official support**
- ❌ **May cause instability**

**Only for advanced users who understand the risks!**

### What are XtremeG Drivers?

**XtremeG** = Community-modified NVIDIA drivers optimized for maximum gaming performance

**Key Features:**
- ✅ Pre-configured performance registry tweaks
- ✅ Telemetry completely removed
- ✅ All bloatware stripped (GeForce Experience, etc.)
- ✅ Optimized for low latency
- ✅ Smaller download size (~400MB vs ~700MB)
- ✅ Based on official Game Ready Drivers

**Source:** [r/XtremeG](https://www.reddit.com/r/XtremeG)

### Quick Install

```powershell
# Run as Administrator
# Navigate to this directory in PowerShell, then run:
.\xtremeg-installer.ps1
```

The script will:
1. Guide you through downloading from MEGA.nz
2. Extract the driver package
3. Optionally run DDU (Display Driver Uninstaller)
4. Install the XtremeG driver
5. Offer post-installation tweaks

### Manual Install (Alternative)

1. Visit [r/XtremeG](https://www.reddit.com/r/XtremeG)
2. Download latest driver from MEGA.nz link
3. Extract ZIP/7z file
4. Run `setup.exe` as Administrator
5. Reboot

### Example Download URL Format

```
https://mega.nz/file/rkc20QAY#Xp0RksAw2_omqeB98N1WSJnTDvogzaq1UqCX-rcI9N4
```

*(Check subreddit for current version)*

### Should You Use XtremeG?

**Use XtremeG if you:**
- ✅ Want absolute maximum performance
- ✅ Don't need GeForce Experience
- ✅ Are comfortable with unofficial software
- ✅ Can troubleshoot driver issues
- ✅ Want telemetry completely removed

**Stick with official drivers if you:**
- ❌ Want official NVIDIA support
- ❌ Need GeForce Experience features
- ❌ Want automatic updates
- ❌ Prefer stability over maximum performance
- ❌ Are uncomfortable with modified software

### Comparison

| Feature | Official NVIDIA | XtremeG | Official + Our Tweaks |
|---------|----------------|---------|----------------------|
| **Source** | NVIDIA | Modified | NVIDIA |
| **Safety** | ✅ Official | ⚠️ Unofficial | ✅ Official |
| **Size** | ~700MB | ~400MB | ~700MB |
| **Telemetry** | Yes | Removed | You remove |
| **Bloat** | Yes (GFE) | Removed | You remove |
| **Tweaks** | Default | Pre-applied | You apply |
| **Updates** | Auto (GFE) | Manual | Manual |
| **Support** | Official | Community | Official |

**Recommendation:** For most users, **official drivers + our tweaks** is the best balance of safety and performance.

### Full Documentation

See [XTREMEG.md](XTREMEG.md) for:
- Complete installation guide
- Troubleshooting
- Reverting to official drivers
- Security considerations
- FAQ

### Alternative: NVCleanstall (Safer)

If you want customized drivers but prefer safety:
- [NVCleanstall](https://www.techpowerup.com/nvcleanstall/)
- Customize official NVIDIA drivers during install
- Remove telemetry/bloat safely
- GUI-based, user-friendly

