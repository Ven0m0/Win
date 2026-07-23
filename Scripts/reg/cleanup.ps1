#Requires -Version 5.1
<#
.SYNOPSIS
    Downloads DeviceCleanup and DriveCleanup utilities to Scripts/reg/.
.DESCRIPTION
    Fetches the latest x64 builds from uwe-sieber.de, extracts the executables,
    and removes intermediate zip/txt files.
.PARAMETER DryRun
    Show what would be downloaded without making changes.
.EXAMPLE
    .\cleanup.ps1
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

. "$PSScriptRoot\..\Common.ps1"

function Expand-ArchiveCompat {
  [CmdletBinding()]
  [OutputType([void])]
  param(
    [Parameter(Mandatory)]
    [string]$Zip,
    [Parameter(Mandatory)]
    [string]$Destination
  )

  $sevenZip = Get-Command -Name 7z, 7za -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($sevenZip) {
    $null = & $sevenZip.Source x '-y' "-o$Destination" $Zip
    return
  }
  if (Get-Command -Name tar -ErrorAction SilentlyContinue) {
    tar -xf $Zip -C $Destination
    return
  }
  Expand-Archive -Path $Zip -DestinationPath $Destination -Force
}

$downloads = @(
  @{ Name = 'DeviceCleanup'; Url = 'https://www.uwe-sieber.de/files/DeviceCleanup_x64.zip' }
  @{ Name = 'DriveCleanup';  Url = 'https://www.uwe-sieber.de/files/DriveCleanup.zip' }
)

foreach ($item in $downloads) {
  $zipFile = Join-Path $PSScriptRoot "$($item.Name).zip"
  $txtFile = Join-Path $PSScriptRoot "$($item.Name).txt"
  $exeFile = Join-Path $PSScriptRoot "$($item.Name).exe"

  if ($DryRun) {
    Write-Verbose "[DRY RUN] Would download $($item.Url) -> $zipFile"
    continue
  }

  if ($PSCmdlet.ShouldProcess($item.Url, "Download $($item.Name)")) {
    Remove-Item -Path $zipFile, $txtFile, $exeFile -Force -ErrorAction SilentlyContinue

    Get-FileFromWeb -URL $item.Url -File $zipFile

    Expand-ArchiveCompat -Zip $zipFile -Destination $PSScriptRoot

    # DriveCleanup ships x64 binaries inside an x64\ subfolder
    $x64Dir = Join-Path -Path $PSScriptRoot -ChildPath 'x64'
    if (Test-Path -Path $x64Dir) {
      Move-Item -Path "$x64Dir\*" -Destination $PSScriptRoot -Force
      Remove-Item -Path $x64Dir -Recurse -Force
    }

    $win32Dir = Join-Path -Path $PSScriptRoot -ChildPath 'Win32'
    if (Test-Path -Path $win32Dir) {
      Remove-Item -Path $win32Dir -Recurse -Force
    }

    Remove-Item -Path $zipFile, $txtFile -Force -ErrorAction SilentlyContinue
    Write-Verbose "$($item.Name) ready."
  }
}
