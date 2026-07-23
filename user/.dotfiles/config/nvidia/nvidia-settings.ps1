#Requires -Version 5.1
<#
.SYNOPSIS
    Applies all tracked NVIDIA Inspector profiles and enables legacy sharpening.
.DESCRIPTION
    Imports every .nip profile under the tracked profiles\ folder via NvidiaProfileInspector
    and toggles the legacy sharpening registry key. Elevates automatically if not already admin.
.PARAMETER Mode
    Apply (default): imports every .nip profile and enables legacy sharpen.
    Restore: resets Base Profile to Inspector defaults and disables legacy sharpen.
.PARAMETER Unattended
    Skip the .nip profile import (it opens an Inspector GUI window that blocks until
    closed by hand); still applies the registry-only legacy sharpen toggle.
.EXAMPLE
    .\nvidia-settings.ps1
.EXAMPLE
    .\nvidia-settings.ps1 -Mode Restore
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
  [ValidateSet('Apply', 'Restore')]
  [string]$Mode = 'Apply',
  [switch]$Unattended
)

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
  $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode $Mode"
  if ($Unattended) { $argList += ' -Unattended' }
  Start-Process -FilePath 'pwsh.exe' -ArgumentList $argList -Verb RunAs -Wait
  return
}

function Resolve-NvidiaProfileInspector {
  <#
  .SYNOPSIS
      Resolves the nvpi-r.exe path for the NVPI Revamped winget package
      (xHybred.NVPIRevamped, installed by Scripts/packages.psd1).
  #>
  [CmdletBinding()]
  [OutputType([string])]
  param()

  $wingetLinks = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links'
  if ((Test-Path $wingetLinks) -and ($env:PATH -notlike "*$wingetLinks*")) {
    $env:PATH = "$wingetLinks;$env:PATH"
  }
  $wingetLinksMachine = Join-Path $env:ProgramFiles 'WinGet\Links'
  if ((Test-Path $wingetLinksMachine) -and ($env:PATH -notlike "*$wingetLinksMachine*")) {
    $env:PATH = "$wingetLinksMachine;$env:PATH"
  }

  $nvpiCmd = Get-Command -Name 'nvpi-r' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $nvpiCmd) {
    throw 'nvpi-r.exe not found on PATH. Install NVPI Revamped first (winget install xHybred.NVPIRevamped, or run the package install step).'
  }
  return $nvpiCmd.Source
}

$inspectorExe = Resolve-NvidiaProfileInspector
$profilesDir = Join-Path $PSScriptRoot '..\nvidia\profiles'
$drsPath = 'C:\ProgramData\NVIDIA Corporation\Drs'

if (Test-Path $drsPath) {
  Get-ChildItem -Path $drsPath -Recurse | Unblock-File
}

switch ($Mode) {
  'Apply' {
    $nipFiles = Get-ChildItem -Path $profilesDir -Filter '*.nip' -ErrorAction SilentlyContinue
    if (-not $nipFiles) {
      Write-Warning "  [SKIP] NVIDIA Inspector settings - no .nip files found in: $profilesDir"
      return
    }
    if ($Unattended) {
      Write-Warning "  [SKIP] NVIDIA Inspector profile import - opens a GUI window that blocks unattended runs; re-run '.\nvidia-settings.ps1' manually to import $($nipFiles.Count) profile(s)."
    } else {
      foreach ($nipFile in $nipFiles) {
        if ($PSCmdlet.ShouldProcess($nipFile.Name, 'Import NVIDIA Inspector profile')) {
          Start-Process -FilePath $inspectorExe -ArgumentList "`"$($nipFile.FullName)`"" -Wait
          Write-Host "  [OK] Imported $($nipFile.Name)" -ForegroundColor Green
        }
      }
    }
    if ($PSCmdlet.ShouldProcess('Legacy sharpen registry key', 'Enable')) {
      $null = & reg.exe add 'HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS' /v 'EnableGR535' /t REG_DWORD /d '0' /f 2>&1
      $null = & reg.exe add 'HKLM\SYSTEM\ControlSet001\Services\nvlddmkm\Parameters\FTS' /v 'EnableGR535' /t REG_DWORD /d '0' /f 2>&1
      $null = & reg.exe add 'HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS' /v 'EnableGR535' /t REG_DWORD /d '0' /f 2>&1
      Write-Host '  [OK] NVIDIA Inspector settings applied' -ForegroundColor Green
    }
  }
  'Restore' {
    $defaultNip = Join-Path $env:TEMP 'Inspector_Default.nip'
    $defaultXml = @'
<?xml version="1.0" encoding="utf-16"?>
<ArrayOfProfile>
  <Profile>
    <ProfileName>Base Profile</ProfileName>
    <Executeables />
    <Settings />
  </Profile>
</ArrayOfProfile>
'@
    if ($PSCmdlet.ShouldProcess('NVIDIA Base Profile', 'Reset to Inspector defaults and disable legacy sharpen')) {
      Set-Content -Path $defaultNip -Value $defaultXml -Encoding Unicode -Force
      Start-Process -FilePath $inspectorExe -ArgumentList "`"$defaultNip`"" -Wait
      $null = & reg.exe add 'HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS' /v 'EnableGR535' /t REG_DWORD /d '1' /f 2>&1
      $null = & reg.exe add 'HKLM\SYSTEM\ControlSet001\Services\nvlddmkm\Parameters\FTS' /v 'EnableGR535' /t REG_DWORD /d '1' /f 2>&1
      $null = & reg.exe add 'HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS' /v 'EnableGR535' /t REG_DWORD /d '1' /f 2>&1
      Write-Host '  [OK] NVIDIA Inspector settings restored to defaults' -ForegroundColor Green
    }
  }
}
