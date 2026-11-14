#Requires -Version 5.1

<#
.SYNOPSIS
    Sets the interrupt affinity policy (DevicePolicy) per device class, with backup and -Restore.
.DESCRIPTION
    Targets present PCI devices only:
      Display adapters                 SpreadMessagesAcrossAllProcessors (5)
      Network adapters                 SpreadMessagesAcrossAllProcessors (5)
      NVMe controllers                 AllCloseProcessors (1)
      USB host controllers             AllCloseProcessors (1)
    Without -Apply it only prints what it would change. -Apply records each device's previous value in
    -BackupPath first; -Restore puts those values back (or deletes the value when none existed).
    A reboot is needed before a change takes effect. Network adapters without MSI-X gain nothing from
    Spread (see issue #107); this script does not detect MSI-X.
.EXAMPLE
    .\set-interrupt-policy.ps1
    Preview only.
.EXAMPLE
    .\set-interrupt-policy.ps1 -Apply
    Back up, then apply the policies.
.EXAMPLE
    .\set-interrupt-policy.ps1 -Restore
    Undo the last -Apply.
#>
[CmdletBinding(SupportsShouldProcess)]
param (
  # Write the policies; without it the script only previews
  [switch]$Apply,
  # Put back the values saved by the last -Apply
  [switch]$Restore,
  # Where previous values are saved and read back
  [string]$BackupPath = (Join-Path -Path $env:USERPROFILE -ChildPath 'interrupt-policy-backup.json'),
  [switch]$NoRestorePoint
)

$ErrorActionPreference = 'Stop'
. (Join-Path -Path $PSScriptRoot -ChildPath 'Common.ps1')

$Script:PolicyKeySuffix = 'Device Parameters\Interrupt Management\Affinity Policy'

function Get-InterruptPolicyTarget {
    <#
    .SYNOPSIS
        Returns the DevicePolicy to set for a PnP class and name, or $null to leave the device alone.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param (
      [Parameter(Mandatory)][string]$Class,
      [Parameter(Mandatory)][string]$FriendlyName
    )
    switch ($Class) {
      'Display' { 5 }
      'Net' { 5 }
      'SCSIAdapter' { if ($FriendlyName -match 'NVM') { 1 } }
      'USB' { if ($FriendlyName -match 'Host Controller') { 1 } }
    }
}

function Get-InterruptPolicyPlan {
    <#
    .SYNOPSIS
        Lists present PCI devices that have a target policy, with their current DevicePolicy.
    #>
    [CmdletBinding()]
    param ()
    foreach ($dev in Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue) {
      if ($dev.InstanceId -notlike 'PCI\*') { continue }
      $target = Get-InterruptPolicyTarget -Class "$($dev.Class)" -FriendlyName "$($dev.FriendlyName)"
      if ($null -eq $target) { continue }
      $keyPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.InstanceId)\$Script:PolicyKeySuffix"
      $current = (Get-ItemProperty -Path $keyPath -Name DevicePolicy -ErrorAction SilentlyContinue).DevicePolicy
      [pscustomobject]@{
        InstanceId = $dev.InstanceId
        Name       = $dev.FriendlyName
        Class      = $dev.Class
        Current    = $current
        Target     = $target
      }
    }
}

function ConvertTo-RegExePath {
    [CmdletBinding()]
    [OutputType([string])]
    param ([Parameter(Mandatory)][string]$InstanceId)
    "HKLM\SYSTEM\CurrentControlSet\Enum\$InstanceId\$Script:PolicyKeySuffix"
}

function Invoke-InterruptPolicyApply {
    [CmdletBinding()]
    param ([Parameter(Mandatory)][object[]]$Plan, [Parameter(Mandatory)][string]$Path)
    # -InputObject keeps a one-device plan an array on 5.1, where piping would unwrap it
    ConvertTo-Json -InputObject @($Plan | Select-Object -Property InstanceId, Current) -Depth 3 |
      Set-Content -LiteralPath $Path -Encoding UTF8
    Write-Info "Previous values saved to $Path"
    foreach ($item in $Plan) {
      Set-RegistryValue -Path (ConvertTo-RegExePath -InstanceId $item.InstanceId) -Name DevicePolicy `
        -Type REG_DWORD -Data "$($item.Target)"
    }
}

function Invoke-InterruptPolicyRestore {
    [CmdletBinding()]
    param ([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Backup not found: $Path" }
    $saved = @(Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
    foreach ($item in $saved) {
      $regPath = ConvertTo-RegExePath -InstanceId $item.InstanceId
      if ($null -eq $item.Current) {
        Remove-RegistryValue -Path $regPath -Name DevicePolicy
      } else {
        Set-RegistryValue -Path $regPath -Name DevicePolicy -Type REG_DWORD -Data "$($item.Current)"
      }
    }
    Write-Info "Restored $($saved.Count) device(s). Reboot to take effect."
}

if ($MyInvocation.InvocationName -ne '.') {
  $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
    IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (($Apply -or $Restore) -and -not $isAdmin) { throw 'Run from an elevated prompt to use -Apply or -Restore.' }

  if ($Restore) {
    Invoke-InterruptPolicyRestore -Path $BackupPath
    return
  }

  $plan = @(Get-InterruptPolicyPlan)
  $plan | Format-Table -AutoSize | Out-String -Width 160 | Write-Host
  if (-not $Apply) {
    Write-Info 'Preview only. Re-run with -Apply to write these values.'
    return
  }
  if (-not $NoRestorePoint) { New-RestorePoint -Description 'set-interrupt-policy' }
  Invoke-InterruptPolicyApply -Plan $plan -Path $BackupPath
  Write-Info 'Done. Reboot to take effect; undo with -Restore.'
}
