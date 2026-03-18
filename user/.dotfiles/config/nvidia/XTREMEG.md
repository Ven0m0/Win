# XtremeG Custom NVIDIA Drivers

## ⚠️ IMPORTANT WARNINGS

**THESE ARE MODIFIED/CUSTOM DRIVERS - USE AT YOUR OWN RISK!**

- ❌ **NOT official NVIDIA drivers**
- ❌ **NOT supported by NVIDIA**
- ❌ **May void warranty**
- ❌ **May cause system instability**
- ❌ **Use only if you understand the risks**

**Only proceed if you:**
- ✅ Understand you're using unofficial drivers
- ✅ Are comfortable troubleshooting driver issues
- ✅ Can revert to official drivers if needed
- ✅ Accept all risks

## What are XtremeG Drivers?

**XtremeG** is a community-modified version of NVIDIA drivers optimized for gaming performance.

### Key Modifications:
- 🔧 Pre-configured registry tweaks for maximum performance
- 🔧 Telemetry completely removed
- 🔧 Bloatware stripped out
- 🔧 Optimized for low latency gaming
- 🔧 Custom performance profiles
- 🔧 Enhanced control panel settings

### Sources:
- **Subreddit:** [r/XtremeG](https://www.reddit.com/r/XtremeG)
- **Creator:** XtremeG (independent developer)
- **Distribution:** MEGA.nz hosting
- **Base:** Official NVIDIA Game Ready Drivers (modified)

### Recommended/Verified Links:
- **Latest Verified:** [MEGA Link 1](https://mega.nz/file/rkc20QAY#Xp0RksAw2_omqeB98N1WSJnTDvogzaq1UqCX-rcI9N4)
- **Alternative Verified:** [MEGA Link 2](https://mega.nz/file/3l8CjLwD#ufO8tz8LrY66vqLyjzcf5xfgOvq38SNbTjtO2nwPaYM)

## Comparison: Official vs XtremeG

| Feature | Official NVIDIA | XtremeG Custom |
|---------|----------------|----------------|
| **Source** | NVIDIA | Community modified |
| **Telemetry** | Included | Completely removed |
| **Bloatware** | GFE, containers, etc. | Stripped out |
| **Size** | ~700MB+ | ~400MB |
| **Registry Tweaks** | Default | Pre-optimized |
| **Updates** | Automatic (GFE) | Manual download |
| **Support** | Official NVIDIA | Community only |
| **Safety** | ✅ Official | ⚠️ Unofficial |

## Features

### What's Removed (vs Official Drivers):
- ❌ GeForce Experience (GFE)
- ❌ NVIDIA Telemetry
- ❌ NvContainer services
- ❌ NvBackend
- ❌ ShadowPlay/recording features
- ❌ NVIDIA HD Audio (usually kept, check version)
- ❌ PhysX (usually kept, check version)

### What's Included:
- ✅ Core display driver
- ✅ NVIDIA Control Panel
- ✅ Vulkan support
- ✅ CUDA support
- ✅ OpenGL support
- ✅ Pre-configured performance registry tweaks
- ✅ DLSS/RTX support (for supported games)

### Pre-configured Optimizations:
XtremeG drivers typically include these tweaks pre-applied:
- P-State 0 lock (maximum clocks)
- Multi-threading optimizations
- Memory management tweaks
- Low-latency presentation modes
- Disabled logging/telemetry
- Optimized power management

## Installation Guide

### Prerequisites

1. **Clean driver installation recommended:**
   - Download [Display Driver Uninstaller (DDU)](https://www.guru3d.com/files-details/display-driver-uninstaller-download.html)
   - Boot into Safe Mode
   - Run DDU → Clean and Restart

2. **Disable Secure Boot (may be required):**
   - Enter BIOS/UEFI
   - Disable Secure Boot
   - Some XtremeG versions use modified signatures.

3. **Enable Driver Signature Override (Required for modified drivers):**
   - Run: `bcdedit /set nointegritychecks on`
   - Run: `bcdedit /set testsigning on`
   - Apply NVIDIA-specific registry signature overrides.
   - *Note: Our tools automate this in `xtremeg-installer.ps1` and `Scripts/gpu-display-manager.ps1`.*

4. **Create System Restore Point:**
   - Important for easy rollback if needed

### Installation Methods

#### Method 1: Automated Script (Recommended)

```powershell
# Run as Administrator
# Run as Administrator
# Navigate to this script's directory, then run:
.\xtremeg-installer.ps1
```

The script will:
1. Prompt for MEGA.nz download URL (with pre-verified options)
2. Download driver (requires MEGAcmd or browser download)
3. Extract driver
4. Optionally run DDU first
5. Install driver
6. Apply additional tweaks if desired

#### Method 2: Manual Installation

1. **Find latest driver:**
   - Visit [r/XtremeG](https://www.reddit.com/r/XtremeG)
   - Check pinned posts for latest version
   - Note: Usually posted as "XtremeG [Driver Version]"

2. **Download from MEGA.nz:**
   - Example: `https://mega.nz/file/rkc20QAY#Xp0RksAw2_omqeB98N1WSJnTDvogzaq1UqCX-rcI9N4`
   - Click link → Download
   - Save to downloads folder

3. **Extract driver:**
   - Extract ZIP/7z file
   - Should contain folders like `Display.Driver`, `NVI2`, etc.

4. **Install:**
   - Run `setup.exe` as Administrator
   - Follow installer prompts
   - Reboot when prompted

5. **Verify installation:**
   - Open NVIDIA Control Panel
   - Check driver version
   - Run a game to test stability

## Version Tracking

### Latest Known Versions (Check r/XtremeG for updates):

| Base Driver | XtremeG Version | Release Date | Notes |
|-------------|----------------|--------------|-------|
| 572.42 | XtremeG 572.42 | 2025-01-XX | Example version |
| 566.XX | XtremeG 566.XX | 2024-XX-XX | Check subreddit |

**Always check [r/XtremeG](https://www.reddit.com/r/XtremeG) for the absolute latest version.**

## Troubleshooting

### Installation Issues

**Problem:** "Driver installation failed"
- ✅ Run DDU in Safe Mode first
- ✅ Disable antivirus temporarily
- ✅ Disable Secure Boot in BIOS
- ✅ Check if you have enough disk space

**Problem:** "Code 43" in Device Manager
- ✅ Use DDU to completely remove driver
- ✅ Try official NVIDIA driver first to verify GPU works
- ✅ Check if GPU is supported by this XtremeG version

**Problem:** Black screen after installation
- ✅ Boot into Safe Mode
- ✅ Run DDU and install official driver
- ✅ May need to enable Secure Boot again

### Performance Issues

**Problem:** Lower performance than expected
- ✅ Verify GPU clocks with GPU-Z or MSI Afterburner
- ✅ Check power management mode in NVIDIA Control Panel
- ✅ Apply additional tweaks from `nvidia-performance-tweaks.reg`

**Problem:** Games crashing
- ✅ May need to apply stability tweaks (enable preemption)
- ✅ Check if game-specific profile is needed
- ✅ Try official driver to rule out game issue

## Reverting to Official Drivers

If you have issues:

1. **Boot into Safe Mode**
2. **Run DDU** → Clean NVIDIA drivers
3. **Reboot**
4. **Download official driver** from [NVIDIA](https://www.nvidia.com/download/index.aspx)
5. **Install official driver**
6. **Re-enable Secure Boot** in BIOS if you disabled it

## Additional Optimizations

After installing XtremeG drivers, you can apply additional tweaks:

### Recommended (Safe):
```cmd
# Apply our consolidated performance tweaks
regedit /s nvidia-performance-tweaks.reg

# Disable MPO if you have flickering
regedit /s toggles/disable-mpo.reg

# Enable hardware scheduling
regedit /s toggles/enable-hardware-scheduling.reg
```

### Check What's Already Applied:
XtremeG drivers may already include some tweaks. Use the PowerShell script to check:
```powershell
cd ~/Scripts
.\gpu-display-manager.ps1
# Choose "View Current Settings" to see what's configured
```

## FAQ

**Q: Are XtremeG drivers safe?**
A: They're modified by a community developer, not NVIDIA. Use at your own risk. Many users report no issues, but there's always risk with unofficial software.

**Q: Will I get banned in games?**
A: Unlikely. These are modified drivers, not game cheats. However, always check game-specific anti-cheat policies.

**Q: Can I update through GeForce Experience?**
A: No, GFE is removed. You must manually download new XtremeG versions.

**Q: Do I lose DLSS/Ray Tracing?**
A: No, RTX features are retained.

**Q: How often are XtremeG drivers updated?**
A: Depends on the creator. Check r/XtremeG regularly. Usually follows major NVIDIA releases.

**Q: Can I use NVIDIA Profile Inspector?**
A: Yes, NVIDIA Profile Inspector works normally with XtremeG drivers.

**Q: What about driver signature enforcement?**
A: XtremeG drivers are usually signed, but you may need to:
- Disable Secure Boot in BIOS
- Enable Driver Signature Override (test signing mode)

**Q: Are there other alternatives?**
A: Yes:
- **NVCleanstall** - Tool to customize official drivers during install
- **Official drivers + manual debloat** - Use our `nvidia-telemetry-cleanup.bat`
- **Studio drivers** - More stable, less frequent updates

## Security Considerations

### Risks:
- ⚠️ Modified drivers could theoretically contain malware
- ⚠️ Reduced driver signature validation
- ⚠️ No official support channel
- ⚠️ Dependency on third-party hosting (MEGA.nz)

### Mitigations:
- ✅ Download only from trusted sources (official XtremeG posts)
- ✅ Scan downloads with antivirus
- ✅ Check community feedback before installing
- ✅ Use virtual machine for testing first (if paranoid)
- ✅ Create system restore point before installation

## Alternatives to XtremeG

If you want optimization without custom drivers:

### Option 1: Official + Manual Debloat
```cmd
# Install official NVIDIA driver
# Then run our telemetry cleanup
nvidia-telemetry-cleanup.bat

# Apply performance tweaks
regedit /s nvidia-performance-tweaks.reg
```

### Option 2: NVCleanstall (Recommended for most users)
- [NVCleanstall](https://www.techpowerup.com/nvcleanstall/)
- GUI tool to customize official drivers
- Remove telemetry/bloat during installation
- Safer than pre-modified drivers

### Option 3: Manual Driver Extraction
See our README.md for manual driver debloat instructions.

## Community & Support

- **Subreddit:** [r/XtremeG](https://www.reddit.com/r/XtremeG)
- **Issues:** Post in subreddit (community support only)
- **Updates:** Check subreddit for new releases

## Disclaimer

This documentation is provided for informational purposes only. We do not:
- Create or distribute XtremeG drivers
- Provide support for XtremeG drivers
- Guarantee compatibility or stability
- Take responsibility for any issues arising from use

Always use official NVIDIA drivers unless you understand and accept the risks of modified drivers.

---

**Last Updated:** 2025-12-29
**Latest Tracked Version:** XtremeG 572.42 (example - check subreddit)
