# Registry and Security Rules

Governs registry modification practices for any script reading or writing the Windows Registry under HKLM or HKCU.

## General Principles

1. Always create a restore point before making changes (unless explicitly suppressed with `-NoRestorePoint`)
2. Wrap system-modifying operations with `SupportsShouldProcess` and support `-WhatIf` / `-Confirm`
3. Use Common.ps1 helpers — `Set-RegistryValue`, `Remove-RegistryValue`, and `Get-NvidiaGpuRegistryPaths` — instead of raw `Set-ItemProperty` or `reg.exe`
4. Document rollback — provide a `-Restore` parameter or clear instructions on how to undo the change
5. Never commit machine-specific values — no hardcoded hardware IDs, serial numbers, or personalized tweaks

## Registry Value Data Types

| Registry Type | .NET Type                 | Example                                                          |
| ------------- | ------------------------- | ---------------------------------------------------------------- |
| REG_DWORD     | `[int]` (or `[uint32]`)   | `-Name "EnableFullscreenOptimization" -Value 0 -Type DWORD`      |
| REG_QWORD     | `[long]`                  | `-Name "SomeQwordValue" -Value 1 -Type QWORD`                    |
| REG_SZ        | `[string]`                | `-Name "ExePath" -Value "C:\Program Files\App\app.exe"`          |
| REG_EXPAND_SZ | `[string]` (with `%ENV%`) | `-Name "Path" -Value "%SystemRoot%\System32" -Type ExpandString` |
| REG_MULTI_SZ  | `[string[]]`              | `-Name "AllowedApps" -Value @("app1","app2") -Type MultiString`  |
| REG_BINARY    | `[byte[]]`                | `-Name "BinaryData" -Value (0x01,0x02,0x03) -Type Binary`        |

## Safe Write Pattern

```powershell
function Set-MyRegistryTweak {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [ValidateSet('Apply','Restore')]
    [string]$Mode = 'Apply'
  )
  $keyPath = "HKCU:\Software\MyTweak"
  $valueName = "OptimizationEnabled"
  if ($Mode -eq 'Restore') {
    if ($PSCmdlet.ShouldProcess("$keyPath\$valueName", "Remove")) {
      Remove-RegistryValue -Path $keyPath -Name $valueName
    }
    return
  }
  if ($PSCmdlet.ShouldProcess("$keyPath\$valueName", "Set to 1")) {
    Set-RegistryValue -Path $keyPath -Name $valueName -Value 1
  }
}
```

## HKLM vs HKCU

- **HKCU**: per-user settings; generally does NOT require admin elevation
- **HKLM**: system-wide; **requires admin**; request elevation at script start

Always test `Test-Path` before operating:

```powershell
if (-not (Test-Path $keyPath)) {
  New-Item -Path $keyPath -Force | Out-Null
}
```

## GPU Registry Discovery

**Never hardcode PCI vendor/device IDs.** Use `Get-NvidiaGpuRegistryPaths` from `Common.ps1`:

```powershell
$gpuPaths = Get-NvidiaGpuRegistryPaths
foreach ($regPath in $gpuPaths) {
  Set-RegistryValue -Path $regPath -Name "PowerPreference" -Value 2
}
```

## Restore Points

Call `New-RestorePoint` before any batch of registry or service changes:

```powershell
New-RestorePoint -Description "Before gaming optimization - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
```

## Sensitive Keys — Do NOT Modify

- `HKLM:\SECURITY` — security subsystem
- `HKLM:\SAM` — security accounts manager
- `HKLM:\SYSTEM\CurrentControlSet\Control\Lsa` — security policies

## Policy vs Preference

- **Policy** (`HKLM\Software\Policies\...`): enterprise-enforced; may be overwritten by Group Policy
- **Preference** (`HKCU\...` or `HKLM\...` without `Policies`): user/tool controlled; safe for dotfiles

Prefer preference keys unless policy is the intended scope.
