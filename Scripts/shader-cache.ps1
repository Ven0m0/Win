 # clear_shader_cache.ps1 - Clears Steam/game/log/shader/GPU caches. AveYo, 2025-07-10
#Requires -Version 5.1
#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# Import common functions
if ($MyInvocation.InvocationName -ne '.') { . "$PSScriptRoot\Common.ps1" }
# Request admin elevation
if ($MyInvocation.InvocationName -ne '.') { Request-AdminElevation }

function Invoke-ShaderCacheCleanup {
  <#
  .SYNOPSIS
      Clears shader caches and game logs.
  #>
  [CmdletBinding()]
  param()

  #--- Detect Steam
  try {
    $STEAM = (Get-ItemProperty -Path 'HKCU:\SOFTWARE\Valve\Steam').SteamPath
    if (-not (Test-Path -Path "$STEAM\steam.exe") -or -not (Test-Path -Path "$STEAM\steamapps\libraryfolders.vdf")) {
      Write-Warning 'Steam not found!'
      Start-Sleep -Seconds 5
      return
    }
  } catch {
    Write-Warning 'Steam not found in registry!'
    return
  }

  #--- Targeted Apps
  $apps = @(
    @{ id = 730; name = 'cs2'; mod = 'csgo'; installdir = 'Counter-Strike Global Offensive' }
  )

  #--- Find per-app install locations (using Common.ps1 VDF parser)
  $vdf = Get-Content -Path "$STEAM\steamapps\libraryfolders.vdf" -Force -ErrorAction SilentlyContinue
  if (-not $vdf) { $vdf = @('"libraryfolders"', '{', '}') }
  $vdfParsed = (ConvertFrom-VDF -Content $vdf).Item(0)
  $rootsList = [System.Collections.Generic.List[string]]::new()
  foreach ($nr in $vdfParsed.Keys) {
    $entry = $vdfParsed[$nr]
    if ($entry -and $entry['path']) {
      $rootsList.Add($entry['path'].Trim('"'))
    }
  }
  $roots = $rootsList.ToArray()

  foreach ($app in $apps) {
    foreach ($root in $roots) {
      $i = "$root\steamapps\common\$($app.installdir)"
      if (Test-Path -Path "$i\game\$($app.mod)\steam.inf") {
        $app.gameroot  = "$i\game"
        $app.game      = "$i\game\$($app.mod)"
        $app.exe       = "$i\game\bin\win64\$($app.name).exe"
        $app.steamapps = "$root\steamapps"
      }
    }
  }

  #--- Graceful/forced Steam & app shutdown
  $gameProcesses = $apps.name
  $stopParts    = foreach ($app in $apps) { "+app_stop $($app.id)" }
  $appStopArgs  = $stopParts -join ' '

  Stop-SteamGracefully -AppStopArgs $appStopArgs

  foreach ($proc in $gameProcesses) {
    Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
  }
  Remove-Item -Path "$STEAM\.crash" -Force -ErrorAction SilentlyContinue

  Write-Verbose 'Clearing Steam logs...'
  Clear-DirectorySafe -Path "$STEAM\logs"

  Write-Verbose 'Clearing Steam dumps...'
  Clear-DirectorySafe -Path "$STEAM\dumps"

  Write-Verbose 'Clearing app crash dumps...'
  foreach ($app in $apps) {
    if ($app.exe) {
      $dir = Split-Path -Path $app.exe
      Get-ChildItem -Path "$dir\*.mdmp" -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
    }
  }

  Write-Verbose 'Clearing app shader cache...'
  $allTargets = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($app in $apps) {
    if ($app.game)      { $null = $allTargets.Add("$($app.game)\shadercache") }
    if ($app.steamapps) { $null = $allTargets.Add("$($app.steamapps)\shadercache\$($app.id)") }
    if ($app.steamapps -ne "$STEAM\steamapps") {
      $null = $allTargets.Add("$STEAM\steamapps\shadercache\$($app.id)")
    }
  }
  foreach ($t in $allTargets) { Clear-DirectorySafe -Path $t }

  Write-Verbose 'Clearing NVIDIA Compute cache...'
  Clear-DirectorySafe -Path "$env:APPDATA\NVIDIA\ComputeCache"

  Write-Verbose 'Clearing NV_Cache...'
  Clear-DirectorySafe -Path "$env:ProgramData\NVIDIA Corporation\NV_Cache"

  Write-Verbose 'Clearing local shader caches...'
  foreach ($entry in @(
    'D3DSCache', 'NVIDIA\GLCache', 'NVIDIA\DXCache', 'NVIDIA\OptixCache',
    'NVIDIA Corporation\NV_Cache', 'AMD\DX9Cache', 'AMD\DxCache', 'AMD\DxcCache',
    'AMD\GLCache', 'AMD\OglCache', 'AMD\VkCache', 'Intel\ShaderCache'
  )) {
    Clear-DirectorySafe -Path "$env:LOCALAPPDATA\$entry"
  }

  Write-Verbose 'Clearing LocalLow shader caches...'
  $localLow = Join-Path -Path $env:LOCALAPPDATA -ChildPath '..\LocalLow'
  foreach ($entry in @(
    'NVIDIA\PerDriverVersion\DXCache', 'NVIDIA\PerDriverVersion\GLCache', 'Intel\ShaderCache'
  )) {
    Clear-DirectorySafe -Path "$localLow\$entry"
  }

  Write-Verbose 'Clearing driver temp dirs...'
  foreach ($entry in @("$env:SystemDrive\AMD", "$env:SystemDrive\NVIDIA", "$env:SystemDrive\Intel")) {
    Clear-DirectorySafe -Path $entry
  }

  Write-Host 'All relevant shader/log/crash caches cleaned.'
}

if ($MyInvocation.InvocationName -ne '.') {
  Invoke-ShaderCacheCleanup
  Exit $LASTEXITCODE
}
