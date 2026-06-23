#Requires -Version 5.1
<#
.SYNOPSIS
    Applies NVIDIA Inspector Base Profile settings and enables legacy sharpening.
.DESCRIPTION
    Applies the tracked Base.nip profile via NvidiaProfileInspector and toggles the
    legacy sharpening registry key. Elevates automatically if not already admin.
.PARAMETER Mode
    Apply (default): imports Base.nip and enables legacy sharpen.
    Restore: resets Base Profile to Inspector defaults and disables legacy sharpen.
.EXAMPLE
    .\nvidia-settings.ps1
.EXAMPLE
    .\nvidia-settings.ps1 -Mode Restore
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
  [ValidateSet('Apply', 'Restore')]
  [string]$Mode = 'Apply'
)

$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
  $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Mode $Mode"
  Start-Process -FilePath 'pwsh.exe' -ArgumentList $argList -Verb RunAs -Wait
  return
}

$inspectorExe = Join-Path $env:TEMP 'Inspector.exe'
$baseNip = Join-Path $PSScriptRoot '..\nvidia\profiles\Base.nip'
$drsPath = 'C:\ProgramData\NVIDIA Corporation\Drs'

if (-not (Test-Path $inspectorExe)) {
  Write-Host '  Downloading NvidiaProfileInspector...' -ForegroundColor Cyan
  $ProgressPreference = 'SilentlyContinue'
  Invoke-WebRequest -Uri 'https://github.com/FR33THYFR33THY/files/raw/main/Inspector.exe' `
    -OutFile $inspectorExe -UseBasicParsing
}

if (Test-Path $drsPath) {
  Get-ChildItem -Path $drsPath -Recurse | Unblock-File
}

switch ($Mode) {
  'Apply' {
    if (-not (Test-Path $baseNip)) {
      Write-Warning "  [SKIP] NVIDIA Inspector settings - Base.nip not found: $baseNip"
      return
    }
    if ($PSCmdlet.ShouldProcess('NVIDIA Base Profile', 'Import Base.nip and enable legacy sharpen')) {
      Start-Process -FilePath $inspectorExe -ArgumentList "`"$baseNip`"" -Wait
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
