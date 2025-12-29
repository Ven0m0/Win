# NVIDIA Configuration Files

Optimized and consolidated NVIDIA driver tweaks, telemetry removal, and configuration files.

## 📁 Directory Structure

```
nvidia/
├── README.md                          # This file
├── nvidia-performance-tweaks.reg      # ⭐ Main performance optimizations (consolidated)
├── nvidia-telemetry-cleanup.bat      # ⭐ Complete telemetry removal script
├── toggles/                           # Quick enable/disable settings
│   ├── disable-dlss-indicator.reg
│   ├── enable-dlss-indicator.reg
│   ├── enable-nis-new.reg
│   └── disable-nis-new.reg
├── optional-tweaks/                   # Advanced/risky tweaks (use with caution!)
│   ├── disable-ecc.reg
│   ├── disable-preemption.reg
│   ├── enable-preemption.reg
│   ├── enable-signature-override.reg
│   ├── enable-windows-game-mode.reg
│   └── force-directflip.reg
├── profiles/                          # NVIDIA Profile Inspector profiles
│   ├── Best.nip                       # General performance profile
│   ├── Settings.nip                   # Custom settings profile
│   ├── Bo6.nip                        # Black Ops 6 optimized
│   └── Bo6-light.nip                  # Black Ops 6 light version
├── nvcpl/                            # NVIDIA Control Panel utilities
│   ├── add-contexmenu.bat            # Add NVCPL to context menu
│   ├── del-contextmenu.bat           # Remove NVCPL from context menu
│   └── Nvidia Control Panel.vbs      # Launch NVCPL directly
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

regedit /s optional-tweaks/enable-signature-override.reg
bcdedit /set nointegritychecks on
bcdedit /set testsigning on
```

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
