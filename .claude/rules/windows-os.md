# Windows 10 / Windows 11 Rules

Applies to all Windows system-modifying scripts. Governs OS version detection, feature availability branching, and compatibility guarantees.

## OS Version Detection

```powershell
$osVersion = [Environment]::OSVersion.Version
$isWin11 = $osVersion.Major -eq 10 -and $osVersion.Build -ge 22000
$isWin10 = $osVersion.Major -eq 10 -and $osVersion.Build -lt 22000
if ($osVersion.Major -lt 10) {
  Write-Warning "OS version $($osVersion.ToString()) is below supported baseline (Windows 10 1909+)"
}
```

## Windows 11-Only Features

Guard Win11-specific tweaks with version checks:

```powershell
if ($isWin11) {
  Set-ItemProperty -Path "HKCU:\System\GameConfig" -Name "FullscreenOptimization" -Value 0
} else {
  Write-Verbose "Skipping Windows 11-only tweak on Windows 10"
}
```

## Architecture Awareness

- Check `$env:PROCESSOR_ARCHITECTURE` (`AMD64`, `ARM64`) when installing/downloading binaries
- NVIDIA/AMD GPU registry paths differ by device ID; always use `Get-NvidiaGpuRegistryPaths` helper
- Prefer 64-bit PowerShell contexts (32-bit has registry redirection via SysWOW64)

## UAC and Admin Context

- All registry changes under `HKLM` require admin; `HKCU` changes generally do not
- System service manipulation requires admin and should include confirmation prompts
- Scheduled task modifications require admin; use `-WhatIf` by default

## Telemetry and Privacy Tweaks

| Setting | Path | Notes |
|---------|------|-------|
| Telemetry | `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection` | `AllowTelemetry` DWORD; 0-3 |
| Advertising ID | `HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo` | Disable `Enabled` |
| Suggested apps | `HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager` | `SilentInstalledAppsEnabled` |

## Before Removing a Built-In App

Use `Remove-AppxPackageSafe` from `Common.ps1` — it handles presence checks and `-AllUsers` automatically.

## Breaking Changes to Watch

- Windows 11 24H2 deprecates some legacy network stack options
- Future Windows releases may change Appx/AppxProvisionedPackage cmdlet behavior
- Registry keys under `HKCU:\System\GameConfig` are undocumented and may change
