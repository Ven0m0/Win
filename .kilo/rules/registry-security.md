---
# Registry and Security Rules

These rules govern registry modification practices in the Ven0m0/Win repository. They apply to any script that reads or writes to the Windows Registry under HKLM or HKCU.

## General Principles

1. **Always create a restore point before making changes** (unless explicitly suppressed with `-NoRestorePoint`)
2. **Wrap system-modifying operations with `SupportsShouldProcess` and support `-WhatIf` / `-Confirm`**
3. **Use Common.ps1 helpers** — `Set-RegistryValue`, `Remove-RegistryValue`, and `Get-NvidiaGpuRegistryPaths` — instead of raw `Set-ItemProperty` or `reg.exe`
4. **Document rollback** — provide a `-Restore` parameter or clear instructions on how to undo the change
5. **Never commit machine-specific values** — no hardcoded hardware IDs, serial numbers, or personalized tweaks

## Registry Value Handling

### Data Types

Use the correct .NET type for the registry value:

| Registry Type | .NET Type | Example |
|---|---|---|
| REG_DWORD | `[int]` (or `[uint32]`) | `-Name "EnableFullscreenOptimization" -Value 0 -Type DWORD` |
| REG_QWORD | `[long]` | `-Name "SomeQwordValue" -Value 1 -Type QWORD` |
| REG_SZ | `[string]` | `-Name "ExePath" -Value "C:\Program Files\App\app.exe"` |
| REG_EXPAND_SZ | `[string]` (with `%ENV%`) | `-Name "Path" -Value "%SystemRoot%\System32" -Type ExpandString` |
| REG_MULTI_SZ | `[string[]]` | `-Name "AllowedApps" -Value @("app1","app2") -Type MultiString` |
| REG_BINARY | `[byte[]]` | `-Name "BinaryData" -Value (0x01,0x02,0x03) -Type Binary` |

`Set-RegistryValue` helper automatically chooses correct type based on .NET type. For explicit control, use `-Type` parameter.

### Safe Write Pattern

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
            Write-Verbose "Registry value removed"
        }
        return
    }

    # Check current value before setting
    $current = Get-ItemProperty -Path $keyPath -Name $valueName -ErrorAction SilentlyContinue
    if ($current -and $current.$valueName -eq 1) {
        Write-Verbose "Already set to 1, skipping"
        return
    }

    if ($PSCmdlet.ShouldProcess("$keyPath\$valueName", "Set to 1 (Enable optimization)")) {
        Set-RegistryValue -Path $keyPath -Name $valueName -Value 1
        Write-Verbose "Registry updated"
    }
}
```

### HKLM vs HKCU

- **HKCU (HKEY_CURRENT_USER)**: per-user settings; generally does NOT require admin elevation (unless policy blocks)
- **HKLM (HKEY_LOCAL_MACHINE)**: system-wide; **requires admin**; request elevation at script start

Always test `Test-Path` before operating:

```powershell
if (-not (Test-Path $keyPath)) {
    New-Item -Path $keyPath -Force | Out-Null
}
```

## GPU Registry Discovery

**Never hardcode PCI vendor/device IDs** in registry paths. GPUs vary across machines.

Instead, use `Get-NvidiaGpuRegistryPaths` from `Common.ps1`:

```powershell
$gpuPaths = Get-NvidiaGpuRegistryPaths
foreach ($regPath in $gpuPaths) {
    Set-RegistryValue -Path $regPath -Name "PowerPreference" -Value 2
}
```

This helper enumerates all NVIDIA GPU registry instances (multi-GPU systems) by scanning `HKLM:\SYSTEM\CurrentControlSet\Enum\PCI` and constructing the correct device path.

## Restore Points

Call `New-RestorePoint` before any batch of registry or service changes:

```powershell
$restorePoint = "Before gaming optimization - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
New-RestorePoint -Description $restorePoint
```

If user passes `-NoRestorePoint`, skip creation but still support `-WhatIf`.

## Rollback Documentation

Every registry-modifying script should include:

1. Description of what keys are changed
2. Original values backup (either saved to file or retrievable from git)
3. `-Restore` parameter implementation that reverses changes

Example rollback file location: `$env:USERPROFILE\AppData\Local\WinDotfiles\Rollback\<script-name>-<timestamp>.json`

## Rollback via git

Since configs are tracked, simple registry tweaks that mirror tracked config files can be rolled back by restoring the file from git and re-running deployment or manually applying:

```powershell
git checkout HEAD~1 -- user/.dotfiles/config/registry/my-tweak.reg
# Then apply via reg import or deployment script
```

## Sensitive Keys to Avoid

Do NOT modify:

- `HKLM:\SECURITY` — security subsystem
- `HKLM:\SAM` — security accounts manager
- `HKLM:\SYSTEM\CurrentControlSet\Control\Lsa` — security policies (unless explicitly intended and documented)
- `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\Start_TrackProgs` — Start menu pinning; in-scope for debloat but documented cautiously

## Testing & Validation

After applying registry changes:

```powershell
$val = (Get-ItemProperty -Path $keyPath -Name $valueName).$valueName
Write-Verbose "Verification: $valueName = $val"
```

For `-WhatIf` runs, output exactly what **would** change:

```
What if: Set-RegistryValue -Path 'HKCU:\...' -Name 'Enable' -Value 1
```

## Committing Registry Changes

- Include the PowerShell script that applies the changes
- If registry values are also stored as `.reg` files for import, track them under `user/.dotfiles/config/registry/`
- Do **not** commit exported hive files (`.reg` exports of entire HKCU/HKLM)

## Example Script Skeleton

```powershell
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName='Apply')]
param(
    [Parameter(Mandatory, Position=0, ParameterSetName='Apply')]
    [ValidateSet('Enable','Disable')]
    [string]$Action,

    [Parameter(Mandatory, ParameterSetName='Restore')]
    [switch]$Restore
)

Begin {
    Request-AdminElevation  # if HKLM access is needed
    $restoreLabel = "TweakName-$(Get-Date -Format 'yyyyMMdd-HHmm')"
}
Process {
    if ($Restore) {
        # Reverse logic
        return
    }

    if ($Action -eq 'Enable') {
        # Apply with ShouldProcess
    }
}
```

## Policy vs Preference

- **Policy** (HKLM\Software\Policies\...): enterprise-enforced settings; may be overwritten by Group Policy
- **Preference** (HKCU\... or HKLM\... without `Policies`): user/tool controlled; safe for dotfiles

Prefer preference keys unless policy is the intended scope.

## Cross-OS Registry Compatibility

Some keys exist only on certain OS versions. Guard with `Test-Path`:

```powershell
$win11OnlyKey = "HKCU:\System\GameConfig"
if (Test-Path $win11OnlyKey) {
    Set-RegistryValue -Path $win11OnlyKey -Name "FullscreenOptimization" -Value 0
}
```

Document any known version-specific keys in script comments.
