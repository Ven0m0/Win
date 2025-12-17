<#
.SYNOPSIS
  Defrag/optimize volumes and clean MSI Afterburner skins/docs (Windows-only).
.PARAMETER Volume
  Target volume (default: C:). Ignored when -AllVolumes is set.
.PARAMETER AllVolumes
  Run defrag across all volumes.
.PARAMETER NoDefrag
  Skip defrag/optimization steps.
.PARAMETER NoMsi
  Skip MSI Afterburner cleanup.
.PARAMETER MsiDir
  Override MSI Afterburner install path (default: C:\Program Files (x86)\MSI Afterburner).
.PARAMETER DryRun
  Show commands without executing.
.EXAMPLE
  .\system-maintenance.ps1 -Verbose
.EXAMPLE
  .\system-maintenance.ps1 -AllVolumes -DryRun
#>
[CmdletBinding()]
param(
  [string]$Volume = 'C:',
  [switch]$AllVolumes,
  [switch]$NoDefrag,
  [switch]$NoMsi,
  [string]$MsiDir = "${env:ProgramFiles(x86)}\MSI Afterburner",
  [switch]$DryRun
)

function Assert-Admin {
  if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Administrator privileges required (defrag needs admin)."
  }
}

function Invoke-Step {
  param(
    [Parameter(Mandatory)] [string]$CommandLine
  )
  if ($DryRun) {
    Write-Host "DRY: $CommandLine"
  } else {
    Write-Verbose "Run: $CommandLine"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = 'cmd.exe'
    $psi.Arguments = "/c $CommandLine"
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $p = [Diagnostics.Process]::Start($psi)
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) { throw "Command failed: $CommandLine (exit $($p.ExitCode))" }
  }
}

function Invoke-Defrag {
  param(
    [string]$TargetVolume,
    [switch]$All
  )
  if ($All) {
    Write-Verbose "Defrag: all volumes full pass (/C)"
    Invoke-Step -CommandLine 'defrag /C'
    Write-Verbose "Defrag: all volumes optimize (/C /O)"
    Invoke-Step -CommandLine 'defrag /C /O'
    Write-Verbose "Defrag: all volumes retrim (/C /L)"
    Invoke-Step -CommandLine 'defrag /C /L'
  } else {
    Write-Verbose "Defrag: optimize $TargetVolume (/O)"
    Invoke-Step -CommandLine "defrag $TargetVolume /O"
    Write-Verbose "Defrag: retrim $TargetVolume (/L)"
    Invoke-Step -CommandLine "defrag $TargetVolume /L"
    Write-Verbose "Defrag: free-space consolidate $TargetVolume (/X)"
    Invoke-Step -CommandLine "defrag $TargetVolume /X"
    Write-Verbose "Defrag: storage tier optimize $TargetVolume (/G)"
    Invoke-Step -CommandLine "defrag $TargetVolume /G"
    Write-Verbose "Defrag: boot optimization $TargetVolume (/B)"
    Invoke-Step -CommandLine "defrag $TargetVolume /B"
  }
}

function Invoke-MsiCleanup {
  param(
    [string]$Root
  )
  if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "MSI Afterburner not found at: $Root"
  }
  Write-Verbose "MSI cleanup at: $Root"

  $skinsDir = Join-Path $Root 'Skins'
  $keepSkins = @('MSIMystic.usf', 'MSIWin11Dark.usf', 'defaultX.uxf')

  # Stage keepers out of Skins, recreate Skins, move them back.
  foreach ($skin in $keepSkins) {
    $source = Join-Path $skinsDir $skin
    $temp = Join-Path $Root $skin
    if (Test-Path -LiteralPath $source -PathType Leaf) {
      Invoke-Step -CommandLine "copy /Y `"$source`" `"$temp`""
    }
  }

  Invoke-Step -CommandLine "rmdir /S /Q `"$skinsDir`""
  Invoke-Step -CommandLine "rmdir /S /Q `"$Root\Localization`""
  Invoke-Step -CommandLine "rmdir /S /Q `"$Root\Doc`""
  Invoke-Step -CommandLine "rmdir /S /Q `"$Root\SDK\Doc`""
  Invoke-Step -CommandLine "mkdir `"$skinsDir`""

  foreach ($skin in $keepSkins) {
    $temp = Join-Path $Root $skin
    if (Test-Path -LiteralPath $temp -PathType Leaf) {
      Invoke-Step -CommandLine "move /Y `"$temp`" `"$skinsDir`""
    }
  }

  $startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\MSI Afterburner'
  Invoke-Step -CommandLine "rmdir /S /Q `"$startMenu\SDK`""
  Invoke-Step -CommandLine "del /F /Q `"$startMenu\ReadMe.lnk`""
  Write-Verbose "MSI cleanup done."
}

try {
  Assert-Admin

  if (-not $NoDefrag) {
    Invoke-Defrag -TargetVolume $Volume -All:$AllVolumes
  } else {
    Write-Verbose "Skip defrag (--NoDefrag)."
  }

  if (-not $NoMsi) {
    Invoke-MsiCleanup -Root $MsiDir
  } else {
    Write-Verbose "Skip MSI cleanup (--NoMsi)."
  }

  Write-Host "Complete."
} catch {
  Write-Error $_.Exception.Message
  exit 1
}
