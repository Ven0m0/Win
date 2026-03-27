---
name: registry-tweaks
description: Windows registry modification patterns for this repo — correct use of Common.ps1 Set-RegistryValue/Remove-RegistryValue, HKLM vs HKCU selection, REG_DWORD/REG_SZ/REG_BINARY types, and reversibility requirements
---

# Registry Tweaks

## Correct write pattern

```powershell
# Always via Common.ps1 — never raw Set-ItemProperty
Set-RegistryValue -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\..." `
                  -Name "FeatureName" `
                  -Type "REG_DWORD" `
                  -Data "1"
```

## Correct delete pattern

```powershell
Remove-RegistryValue -Path "HKLM\SOFTWARE\..." -Name "FeatureName"
```

## HKLM vs HKCU

| Use `HKLM` | Use `HKCU` |
|---|---|
| System-wide settings (all users) | Per-user settings |
| GPU/display driver tweaks | User-specific shell/UI prefs |
| Network stack settings | Profile/appearance settings |

`HKLM` requires admin (`#Requires -RunAsAdministrator`). `HKCU` does not, but scripts still request elevation for consistency.

## Value types

| Type | Use case | Valid data |
|---|---|---|
| `REG_DWORD` | Flags, integers | 0–0xFFFFFFFF decimal or `"0x..."` hex |
| `REG_SZ` | Plain strings | Any string (no `%VAR%` expansion) |
| `REG_EXPAND_SZ` | Paths with env vars | Strings containing `%WINDIR%` etc. |
| `REG_BINARY` | Raw byte data | Hex string pairs e.g. `"00,01,02"` |

## Reversibility rule

Every script that writes registry values MUST:
1. Document the original/default value in a comment
2. Offer a "Restore defaults" menu option that calls `Set-RegistryValue` with the original value
3. Never delete a key (only values) unless absolutely required

## NVIDIA GPU paths helper

```powershell
$gpuPaths = Get-NvidiaGpuRegistryPaths
foreach ($path in $gpuPaths) {
  Set-RegistryValue -Path $path -Name "..." -Type "REG_DWORD" -Data "1"
}
```

## High-risk paths — always comment with justification

- `HKLM\SYSTEM\CurrentControlSet\Services\*` — driver/service config, reboot required, can brick system
- `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\*` — OS identity/boot config
- `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\*` — GPU driver config

## .reg file format

Files in `Scripts/reg/` follow standard `.reg` format. Always include a restore/undo `.reg` alongside any change `.reg`.
