# Windows 10 / Windows 11 Rules

These rules apply to all Windows system-modifying scripts in the repository. They govern OS version detection, feature availability branching, and compatibility guarantees.

## OS Version Detection

Use a reliable version check that distinguishes **Windows 10** from **Windows 11**:

```powershell
$osVersion = [Environment]::OSVersion.Version
$isWin11 = $osVersion.Major -eq 10 -and $osVersion.Build -ge 22000
$isWin10 = $osVersion.Major -eq 10 -and $osVersion.Build -lt 22000
# Windows 8/Server fallback check if needed
if ($osVersion.Major -lt 10) {
    Write-Warning "OS version $($osVersion.ToString()) is below supported baseline (Windows 10 1909+)"
}
```

Avoid brittle checks like `(Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild` unless registry access is already required for other reasons.

## Windows 11-Only Features

Guard Win11-specific tweaks with version checks and provide graceful fallback or skip on Win10:

- **AppClip**: `Get-AppxPackage -Name Microsoft.YourPhone` — only present on Win11
- **WSL2 defaults**: Win11 ships with WSL2 as an optional feature; Win10 may need Virtual Platform enabled
- **Modern apps**: Some built-in Appx packages differ between Win10 and Win11

Pattern:

```powershell
if ($isWin11) {
    # Apply Windows 11-specific optimization
    Set-ItemProperty -Path "HKCU:\System\GameConfig" -Name "FullscreenOptimization" -Value 0
} else {
    Write-Verbose "Skipping Windows 11-only tweak on Windows 10"
}
```

## Windows 10 Feature Guarding

- **DirectX 12 Ultimate**: not available on older Win10 builds (< 19041)
- **Game Mode**: present on both but may behave differently; test `Get-Service -Name XblGameSave`
- **MVSC/M365 apps**: different Appx package names across versions

Before removing any built-in app, verify presence first:

```powershell
$app = Get-AppxPackage -Name "Microsoft.WindowsCamera" -AllUsers -ErrorAction SilentlyContinue
if ($app) {
    # Safe to remove
    Remove-AppxPackage -Package $app -AllUsers
}
```

## Architecture Awareness

- Check `$env:PROCESSOR_ARCHITECTURE` (`AMD64`, `ARM64`) when installing/downloading binaries
- NVIDIA/AMD GPU registry paths differ by architecture and device ID; always use `Get-NvidiaGpuRegistryPaths` helper
- 32-bit PowerShell on 64-bit Windows has different registry redirection (`SysWOW64`), prefer 64-bit contexts

## UAC and Admin Context

- All registry changes under `HKLM` require admin; `HKCU` changes generally do not
- System service manipulation requires admin and should include confirmation prompts
- Scheduled task modifications require admin; use `-WhatIf` by default

## Telemetry and Privacy Tweaks

These are OS-version-sensitive:

| Setting | Win10 Path | Win11 Path | Notes |
|---------|-------------|------------|-------|
| Telemetry | `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection` (AllowTelemetry DWORD) | Same path, values differ (0-3) | Win11 has additional `AllowDiagnosticData` under `HKCU` |
| Advertising ID | `HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo` | Same | Disabling `Enabled` opt-out |
| Suggested apps | `HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager` | Same | `SilentInstalledAppsEnabled`, `RotatingLockScreenOverlayEnabled` |

Use helper functions that abstract the version differences — do not scatter version checks across every script.

## Windows Update Behavior

- Win10: `Get-WindowsUpdate` from PSWindowsUpdate module (not built-in)
- Win11: Built-in `Get-WindowsUpdate` via `WindowsUpdate` provider may be present; prefer `winget upgrade` for simplicity
- Reboot detection: `Get-ComputerInfo -Property 'WindowsUpdateAutoUpdateSettings'` works cross-version

## Network Stack Differences

- Win11 introduced improved Wi-Fi 6E/7 support; network tweaks should detect adapter capabilities via `Get-NetAdapter` rather than assume
- TCP autotuning present on both; tune via `Set-NetTCPSetting` only if level `5.1+` supports the parameter

## Testing Matrix

When developing Windows system scripts, validate on:

1. **Windows 10** (latest 22H2) — minimum supported
2. **Windows 11** (23H2+, 24H2) — primary target
3. Clean VM or test machine (no production data)

Always run in `-WhatIf` first, create restore points, and document rollback.

## Breaking Changes to Watch

- Windows 11 24H2 deprecates some legacy network stack options
- Future Windows releases may change Appx/AppxProvisionedPackage cmdlet behavior
- Registry keys under `HKCU:\System\GameConfig` are undocumented and may change

## References

- `Scripts/Common.ps1` — shared helpers for elevation, restore points, UI
- `Scripts/debloat-windows.ps1` — example of safe Win10/Win11 branching
- `Scripts/system-settings-manager.ps1` — registry tweak patterns
- `.kilo/rules/bootstrap-deployment.md` — setup and deployment rules
- `.kilo/rules/powershell.md` — PowerShell coding rules
