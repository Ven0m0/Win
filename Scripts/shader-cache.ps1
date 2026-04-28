 # clear_shader_cache.ps1 - Clears Steam/game/log/shader/GPU caches. AveYo, 2025-07-10
#Requires -RunAsAdministrator
# Import common functions
. "$PSScriptRoot\Common.ps1"
# Request admin elevation
Request-AdminElevation
#--- Detect Steam
try {
  $STEAM = (Get-ItemProperty 'HKCU:\SOFTWARE\Valve\Steam').SteamPath
  if (!(Test-Path "$STEAM\steam.exe") -or !(Test-Path "$STEAM\steamapps\libraryfolders.vdf")) {
    Write-Warning "Steam not found!"; Start-Sleep 5; Exit 1
  }
} catch { Write-Warning "Steam not found in registry!"; Exit 1 }
#--- Targeted Apps
$apps = @(
  @{id=730; name='cs2';   mod='csgo';  installdir='Counter-Strike Global Offensive'}
)
#--- Find per-app install locations (using Common.ps1 VDF parser)
$vdf=(Get-Content "$STEAM\steamapps\libraryfolders.vdf" -Force -ErrorAction SilentlyContinue)
if (!$vdf) { $vdf = @('"libraryfolders"','{','}') }
$vdfParsed = (ConvertFrom-VDF -Content $vdf).Item(0)
$rootsList = [System.Collections.Generic.List[string]]::new()
foreach ($nr in $vdfParsed.Keys) {
  $entry = $vdfParsed[$nr]
  if ($entry -and $entry["path"]) {
    $rootsList.Add($entry["path"].Trim('"'))
  }
}
$roots = $rootsList.ToArray()
foreach ($app in $apps) {
  foreach ($root in $roots) {
    $i = "$root\steamapps\common\$($app.installdir)"
    if (Test-Path "$i\game\$($app.mod)\steam.inf") {
      $app.gameroot = "$i\game"
      $app.game     = "$i\game\$($app.mod)"
      $app.exe      = "$i\game\bin\win64\$($app.name).exe"
      $app.steamapps= "$root\steamapps"
    }
  }
}
#--- Graceful/forced Steam & app shutdown
$gameProcesses = $apps.name
$stopParts = foreach ($app in $apps) { "+app_stop $($app.id)" }
$appStopArgs = $stopParts -join ' '

# Stop Steam gracefully (including per-app stops)
Stop-SteamGracefully -AppStopArgs $appStopArgs

# Kill any remaining game processes (force)
$gameProcesses | ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
Remove-Item "$STEAM\.crash" -Force -ErrorAction SilentlyContinue

Write-Host "`n* Clearing STEAM logs..." -ForegroundColor Cyan
Clear-DirectorySafe "$STEAM\logs"
Write-Host "`n* Clearing STEAM dumps..." -ForegroundColor Cyan
Clear-DirectorySafe "$STEAM\dumps"
Write-Host "`n* Clearing APP crash dumps..." -ForegroundColor Cyan
foreach ($app in $apps) {
  if ($app.exe) {
    $dir=Split-Path $app.exe
    Get-ChildItem "$dir\*.mdmp" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  }
}
Write-Host "`n* Clearing APP shadercache..." -ForegroundColor Cyan
foreach ($app in $apps) {
  $targets = [System.Collections.Generic.List[string]]::new()
  if ($app.game) { $targets.Add("$($app.game)\shadercache") }
  if ($app.steamapps) { $targets.Add("$($app.steamapps)\shadercache\$($app.id)") }
  if ($app.steamapps -ne "$STEAM\steamapps") { $targets.Add("$STEAM\steamapps\shadercache\$($app.id)") }
  foreach ($t in $targets) { Clear-DirectorySafe $t }
}
Write-Host "`n* Clearing NVIDIA Compute cache..." -ForegroundColor Cyan
Clear-DirectorySafe "$env:APPDATA\NVIDIA\ComputeCache"
Write-Host "`n* Clearing NV_Cache..." -ForegroundColor Cyan
Clear-DirectorySafe "$env:ProgramData\NVIDIA Corporation\NV_Cache"
Write-Host "`n* Clearing Local shader caches..." -ForegroundColor Cyan
@(
  'D3DSCache','NVIDIA\GLCache','NVIDIA\DXCache','NVIDIA\OptixCache','NVIDIA Corporation\NV_Cache',
  'AMD\DX9Cache','AMD\DxCache','AMD\DxcCache','AMD\GLCache','AMD\OglCache','AMD\VkCache','Intel\ShaderCache'
) | ForEach-Object {
  Clear-DirectorySafe "$env:LOCALAPPDATA\$_"
}
Write-Host "`n* Clearing LocalLow shader caches..." -ForegroundColor Cyan
@(
  'NVIDIA\PerDriverVersion\DXCache','NVIDIA\PerDriverVersion\GLCache','Intel\ShaderCache'
) | ForEach-Object {
  Clear-DirectorySafe "$($env:LOCALAPPDATA)\..\LocalLow\$_"
}
Write-Host "`n* Clearing driver temp dirs..." -ForegroundColor Cyan
@("$env:SystemDrive\AMD","$env:SystemDrive\NVIDIA","$env:SystemDrive\Intel") | ForEach-Object {
  Clear-DirectorySafe $_
}
Write-Host "`nAll relevant shader/log/crash caches cleaned."
Start-Sleep -Seconds 3
