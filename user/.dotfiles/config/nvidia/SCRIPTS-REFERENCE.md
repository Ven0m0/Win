# PowerShell Scripts Integration

This directory contains static registry files and batch scripts extracted from the PowerShell scripts in the `/Scripts` directory. This reference explains the relationship between them.

## Related PowerShell Scripts

### `Scripts/gpu-display-manager.ps1`

**Unified GPU and Display Settings Manager** - Interactive PowerShell script with menu interface.

**Features:**
- ✅ NVIDIA P-State 0 Lock (force max clocks)
- ✅ HDCP Enable/Disable (content protection)
- ✅ MSI Mode Configuration (for all GPUs)
- ✅ EDID Override Manager (fix monitor stuttering)
- ✅ Fullscreen Optimization settings (FSO/FSE)
- ✅ Multiplane Overlay settings (MPO)
- ✅ Real-time status viewing
- ✅ Automatic GPU detection

**Why use the PowerShell script:**
- Interactive menu system
- Automatic GPU detection (handles multiple GPUs)
- Real-time status viewing
- Error handling and validation
- More user-friendly

**Why use registry files from this directory:**
- Faster (no script execution)
- Can be automated/scripted
- No PowerShell required
- Can be applied remotely

**Equivalent Registry Files:**

| Script Function | Registry File |
|----------------|---------------|
| P-State 0 ON | `toggles/enable-p-state-0-lock.reg` |
| P-State 0 OFF | `toggles/disable-p-state-0-lock.reg` |
| HDCP OFF | `toggles/disable-hdcp.reg` |
| HDCP ON | `toggles/enable-hdcp.reg` |
| MPO Enable | `toggles/enable-mpo.reg` |
| MPO Disable | `toggles/disable-mpo.reg` |
| MSI Mode | *(Not available as reg file - use script)* |
| EDID Override | *(Not available as reg file - use script)* |

**Usage:**
```powershell
cd ~/Scripts
.\gpu-display-manager.ps1
```

---

### `Scripts/DLSS-force-latest.ps1`

**DLSS Force Latest Configuration** - Forces games to use the latest DLSS DLL.

**Features:**
- ✅ Force latest DLSS version override
- ✅ DLSS overlay indicator toggle
- ✅ NVIDIA Profile Inspector integration
- ✅ Read-only protection for DRS database
- ✅ Automatic Inspector download
- ✅ Custom profile generation

**Why use the PowerShell script:**
- Manages NVIDIA Profile Inspector automatically
- Creates and imports .nip profiles
- Handles DRS database protection
- More comprehensive DLSS settings

**Why use registry files from this directory:**
- Quick DLSS indicator toggle only
- No Profile Inspector needed
- Lightweight

**Equivalent Registry Files:**

| Script Function | Registry File |
|----------------|---------------|
| DLSS Overlay ON | `toggles/enable-dlss-indicator.reg` |
| DLSS Overlay OFF | `toggles/disable-dlss-indicator.reg` |
| DLSS Force Latest | *(Use script - requires Profile Inspector)* |
| Legacy NIS Sharpen | `toggles/enable-nis-new.reg` / `disable-nis-new.reg` |

**Usage:**
```powershell
cd ~/Scripts
.\DLSS-force-latest.ps1
```

**Note:** The script downloads Inspector.exe to `%TEMP%` automatically.

---

### `Scripts/shader-cache.ps1`

**Shader Cache Cleanup** - Clears all shader caches for Steam games and GPU drivers.

**Features:**
- ✅ Clears Steam shader caches
- ✅ Clears NVIDIA shader caches (GLCache, DXCache, OptixCache)
- ✅ Clears AMD and Intel shader caches
- ✅ Clears game-specific caches (CS2, etc.)
- ✅ Gracefully shuts down Steam
- ✅ Clears crash dumps and logs

**Why use the PowerShell script:**
- Handles Steam gracefully (proper shutdown)
- Clears game-specific caches
- Uses robust directory clearing (robocopy method)
- Steam library detection

**Why use the batch file from this directory:**
- Faster (no Steam handling)
- NVIDIA-only (no Steam/games)
- Can run without Steam installed
- Simpler

**Equivalent Batch File:**
- `nvidia-shader-cache-cleanup.bat` - NVIDIA caches only

**Differences:**

| Feature | PowerShell Script | Batch File |
|---------|------------------|------------|
| Steam integration | ✅ Yes | ❌ No |
| Game-specific caches | ✅ Yes | ❌ No |
| Steam shutdown | ✅ Yes | ❌ No |
| NVIDIA caches | ✅ Yes | ✅ Yes |
| AMD/Intel caches | ✅ Yes | ❌ No |

**Usage:**
```powershell
cd ~/Scripts
.\shader-cache.ps1
```

Or for NVIDIA-only cleanup:
```cmd
nvidia-shader-cache-cleanup.bat
```

---

## Consolidated Files vs Scripts

### When to Use Registry Files

✅ **Use registry files when:**
- You want quick, simple toggles
- You're automating via scripts/batch files
- You don't need interactive menus
- You know exactly which setting you want
- You're applying settings to multiple machines

### When to Use PowerShell Scripts

✅ **Use PowerShell scripts when:**
- You want interactive menus
- You need automatic GPU detection
- You want to see current status
- You need advanced features (MSI Mode, EDID Override)
- You want error handling and validation
- You're using Steam game integrations

## Registry Files Advantages

1. **Fast** - No script execution overhead
2. **Simple** - Double-click to apply
3. **Portable** - Can be shared easily
4. **Automatable** - Easy to include in setup scripts
5. **No dependencies** - No PowerShell required

## PowerShell Scripts Advantages

1. **Interactive** - Menus and status displays
2. **Smart** - Automatic GPU detection
3. **Safe** - Validation and error handling
4. **Comprehensive** - More features and options
5. **User-friendly** - Easier for non-technical users

## Performance Tweaks Consolidation

The `nvidia-performance-tweaks.reg` file consolidates many settings from the PowerShell scripts:

**From gpu-display-manager.ps1:**
- P-State 0 lock
- HDCP disable
- MPO settings

**From DLSS-force-latest.ps1:**
- NIS enable/disable settings

**From experimental registry files:**
- All performance optimizations
- Multi-threading settings
- Memory optimizations
- Power management

**Not included (use scripts for these):**
- MSI Mode (requires PnP device enumeration)
- EDID Override (requires monitor detection)
- DLSS Force Latest (requires Profile Inspector)

## Quick Reference

### Common Tasks

| Task | Best Method | Command/File |
|------|-------------|--------------|
| Toggle DLSS indicator | Registry | `toggles/enable-dlss-indicator.reg` |
| Toggle MPO | Registry | `toggles/disable-mpo.reg` |
| Toggle P-State 0 | Registry | `toggles/enable-p-state-0-lock.reg` |
| Toggle HDCP | Registry | `toggles/disable-hdcp.reg` |
| Enable MSI Mode | PowerShell | `gpu-display-manager.ps1` |
| Override EDID | PowerShell | `gpu-display-manager.ps1` |
| Force DLSS latest | PowerShell | `DLSS-force-latest.ps1` |
| Clear shader cache | PowerShell (full) | `shader-cache.ps1` |
| Clear NVIDIA cache only | Batch | `nvidia-shader-cache-cleanup.bat` |
| Full performance tweaks | Registry | `nvidia-performance-tweaks.reg` |

## Integration Examples

### Automated Setup Script

```batch
@echo off
:: Apply all NVIDIA optimizations

:: Performance tweaks
regedit /s nvidia-performance-tweaks.reg

:: Disable MPO (fixes flickering in some games)
regedit /s toggles/disable-mpo.reg

:: Enable hardware scheduling
regedit /s toggles/enable-hardware-scheduling.reg

:: Clean shader cache
call nvidia-shader-cache-cleanup.bat

:: For MSI Mode and EDID, use PowerShell script:
:: powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\Scripts\gpu-display-manager.ps1"

echo Reboot required for changes to take effect
pause
```

### Advanced Configuration (PowerShell)

```powershell
# Apply registry optimizations
Start-Process regedit -ArgumentList "/s nvidia-performance-tweaks.reg" -Wait

# Use script for advanced settings
cd ~/Scripts
.\gpu-display-manager.ps1
```

## Notes

- **GPU Index**: Registry files use `0000` for the first GPU. If you have multiple GPUs, you may need to adjust the index in the registry path.
- **Reboot Required**: Most GPU registry changes require a reboot to take effect.
- **Backup**: Always backup your registry before making changes.
- **Testing**: Test one change at a time to identify any issues.

## See Also

- [Main README](README.md) - Complete NVIDIA configuration guide
- [Scripts/Common.ps1](../../Scripts/Common.ps1) - Shared functions used by all scripts
- [Scripts/OPTIMIZATION_NOTES.md](../../Scripts/OPTIMIZATION_NOTES.md) - Script optimization history
