#Requires -Version 5.1

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
# $DryRun is referenced inside nested functions; suppress PSSA cross-scope false-positive.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'DryRun', Justification = 'Used inside nested functions Invoke-DefragCommand and Invoke-MsiCleanup')]
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$Volume = 'C:',
  [switch]$AllVolumes,
  [switch]$NoDefrag,
  [switch]$NoMsi,
  [string]$MsiDir = "${env:ProgramFiles(x86)}\MSI Afterburner",
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# Import common functions
. "$PSScriptRoot\Common.ps1"

function Invoke-DefragCommand {
  param(
    [Parameter(Mandatory)]
    [string]$Arguments
  )
  if ($DryRun) {
    Write-Information "DRY: defrag $Arguments" -InformationAction Continue
    return
  }
  Write-Verbose "Run: defrag $Arguments"
  Invoke-CommandChecked -FilePath 'defrag.exe' -ArgumentList $Arguments
}

function Invoke-Defrag {
  [CmdletBinding()]
  param(
    [string]$TargetVolume,
    [switch]$All
  )
  if ($All) {
    Write-Verbose "Defrag: all volumes full pass (/C)"
    Invoke-DefragCommand -Arguments '/C'
    Write-Verbose "Defrag: all volumes optimize (/C /O)"
    Invoke-DefragCommand -Arguments '/C /O'
    Write-Verbose "Defrag: all volumes retrim (/C /L)"
    Invoke-DefragCommand -Arguments '/C /L'
  } else {
    Write-Verbose "Defrag: optimize $TargetVolume (/O)"
    Invoke-DefragCommand -Arguments "$TargetVolume /O"
    Write-Verbose "Defrag: retrim $TargetVolume (/L)"
    Invoke-DefragCommand -Arguments "$TargetVolume /L"
    Write-Verbose "Defrag: free-space consolidate $TargetVolume (/X)"
    Invoke-DefragCommand -Arguments "$TargetVolume /X"
    Write-Verbose "Defrag: storage tier optimize $TargetVolume (/G)"
    Invoke-DefragCommand -Arguments "$TargetVolume /G"
    Write-Verbose "Defrag: boot optimization $TargetVolume (/B)"
    Invoke-DefragCommand -Arguments "$TargetVolume /B"
  }
}

function Invoke-MsiCleanup {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)]
    [string]$Root
  )

  if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "MSI Afterburner not found at: $Root"
  }
  Write-Verbose "MSI cleanup at: $Root"

  $skinsDir  = Join-Path -Path $Root -ChildPath 'Skins'
  $keepSkins = @('MSIMystic.usf', 'MSIWin11Dark.usf', 'defaultX.uxf')

  # Stage keepers outside Skins, wipe Skins, recreate, move them back.
  foreach ($skin in $keepSkins) {
    $source = Join-Path -Path $skinsDir -ChildPath $skin
    $temp   = Join-Path -Path $Root     -ChildPath $skin
    if (Test-Path -LiteralPath $source -PathType Leaf) {
      if ($DryRun) {
        Write-Information "DRY: Copy-Item '$source' -> '$temp'" -InformationAction Continue
      } elseif ($PSCmdlet.ShouldProcess($source, 'Copy to temp')) {
        Copy-Item -LiteralPath $source -Destination $temp -Force
      }
    }
  }

  foreach ($subDir in @('Skins', 'Localization', 'Doc', 'SDK\Doc')) {
    $target = Join-Path -Path $Root -ChildPath $subDir
    if (Test-Path -LiteralPath $target -PathType Container) {
      if ($DryRun) {
        Write-Information "DRY: Remove-Item '$target'" -InformationAction Continue
      } elseif ($PSCmdlet.ShouldProcess($target, 'Remove directory')) {
        Remove-Item -LiteralPath $target -Recurse -Force
      }
    }
  }

  if ($DryRun) {
    Write-Information "DRY: New-Item '$skinsDir' -ItemType Directory" -InformationAction Continue
  } elseif ($PSCmdlet.ShouldProcess($skinsDir, 'Create directory')) {
    $null = New-Item -Path $skinsDir -ItemType Directory -Force
  }

  foreach ($skin in $keepSkins) {
    $temp = Join-Path -Path $Root -ChildPath $skin
    if (Test-Path -LiteralPath $temp -PathType Leaf) {
      $dest = Join-Path -Path $skinsDir -ChildPath $skin
      if ($DryRun) {
        Write-Information "DRY: Move-Item '$temp' -> '$dest'" -InformationAction Continue
      } elseif ($PSCmdlet.ShouldProcess($temp, 'Move to Skins')) {
        Move-Item -LiteralPath $temp -Destination $dest -Force
      }
    }
  }

  $startMenu = Join-Path -Path $env:APPDATA -ChildPath 'Microsoft\Windows\Start Menu\Programs\MSI Afterburner'
  $sdkLink    = Join-Path -Path $startMenu -ChildPath 'SDK'
  $readmeLink = Join-Path -Path $startMenu -ChildPath 'ReadMe.lnk'

  if (Test-Path -LiteralPath $sdkLink -PathType Container) {
    if ($DryRun) {
      Write-Information "DRY: Remove-Item '$sdkLink'" -InformationAction Continue
    } elseif ($PSCmdlet.ShouldProcess($sdkLink, 'Remove SDK shortcut folder')) {
      Remove-Item -LiteralPath $sdkLink -Recurse -Force
    }
  }

  if (Test-Path -LiteralPath $readmeLink -PathType Leaf) {
    if ($DryRun) {
      Write-Information "DRY: Remove-Item '$readmeLink'" -InformationAction Continue
    } elseif ($PSCmdlet.ShouldProcess($readmeLink, 'Remove ReadMe shortcut')) {
      Remove-Item -LiteralPath $readmeLink -Force
    }
  }

  Write-Verbose "MSI cleanup done."
}

if ($MyInvocation.InvocationName -ne '.') {
  try {
    Request-AdminElevation

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

    Write-Verbose "Complete."
  } catch {
    Write-Error $_.Exception.Message
    exit 1
  }
}
