# system-settings-manager.ps1

Interactive, menu-driven manager for Windows performance, NVIDIA GPU, MSI mode, EDID override,
gaming display, security hardening, system tweak and Explorer settings. It replaces the older
`settings.ps1`, `nvidia-settings.ps1`, `edid-manager.ps1`, `gaming-display.ps1`, `msi-mode.ps1`
and `gpu-display-manager.ps1`. Self-elevates and creates one restore point before the menu opens.

## Usage

```powershell
.\Scripts\system-settings-manager.ps1
```

There are no parameters. Pick a category from the main menu, then choose Apply or Restore
inside it.

## Main menu

| Category | Apply | Restore / revert |
| --- | --- | --- |
| Performance Optimizations | Hibernate off, fast boot off, lock/sleep flyout options hidden, power throttling off, `WHQLSettings`, raw mouse throttle off, `ms_server` binding disabled on all adapters | "Restore Default Settings" re-enables each; removes the override values |
| NVIDIA GPU Settings | P0 state on, HDCP off, driver signature override toggle, launcher for `user\.dotfiles\config\nvidia\xtremeg-installer.ps1`, view settings | "P0 State: Default", "HDCP: Default" write `0` |
| MSI Mode Configuration | MSI mode on | MSI mode off |
| EDID Override Manager | Apply EDID override | Remove EDID override, view status |
| Gaming Display Optimizations | Fullscreen exclusive (FSE) or optimizations (FSO), Multiplane Overlay On/Off | MPO "Default", FSO |
| Security Hardening | Disable SMB1, require SMB signing, disable WPAD, LLMNR and WDigest caching | "Restore Default Settings" removes the values |
| System Tweaks | Reserved storage off, full powerdown, NumLock at startup, drive autorun off, no app relaunch after update reboot, cursor deadzone fix, scroll inactive window | "Restore Default Settings" removes the values |
| Explorer / Visual Effects | Disable Start menu suggestions and Spotlight features, reduce visual effects and animations | "Restore Default Settings" |

The security menu has a second apply option, "incl. opt-in SMB extras" (`-IncludeOptInExtra`):
SMB AES-256 cipher order and disabling the default admin shares (`AutoShareServer`,
`AutoShareWks`).

## How it works

- **Elevation.** `Start-SystemSettingsManager` calls `Request-AdminElevation`. There is no
  `#Requires -RunAsAdministrator`.
- **Restore point.** `New-RestorePoint -Description "Before System Settings Manager"` runs once
  per session, before the menu. There is no opt-out flag.
- **Registry writes** go through `Set-RegistryValue` / `Remove-RegistryValue` from `Common.ps1`.
  Restore actions delete values the tweak created rather than writing a default, where Windows
  has no value by default.
- **NVIDIA settings** use `Set-NvidiaGpuRegistryValue` and `Get-NvidiaSignatureStatus`
  (Common.ps1). The P0 and HDCP setters have `SupportsShouldProcess` internally.
- **Windows 11 sudo.** System Tweaks enables `Sudo\Enabled` only on build 26100 or later.
- **Loading.** The main block runs only when the script is not dot-sourced.

## Limitations

- No `-WhatIf`, dry-run or non-interactive mode; the script itself exposes no parameters.
- Several changes need a restart or sign-out; the menus print a notice or call
  `Show-RestartRequired`.
- The Explorer restore sets `VisualFXSetting` to `0` and `MenuShowDelay` to `400`, which are
  assumed defaults, not values saved before applying.
- MSI, EDID, fullscreen and MPO logic lives in `Common.ps1`; read it for the exact keys.
