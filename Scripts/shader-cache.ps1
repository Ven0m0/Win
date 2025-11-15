# clear_shader_cache.ps1 - Clears Steam/game/log/shader/GPU caches. AveYo, 2025-07-10

#--- Self-elevate as Administrator
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Host "Requesting elevated rights..." -BackgroundColor Yellow -ForegroundColor Black
  Start-Process powershell -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
  Exit
}

#--- Detect Steam
try {
  $STEAM = (Get-ItemProperty 'HKCU:\SOFTWARE\Valve\Steam').SteamPath
  if (!(Test-Path "$STEAM\steam.exe") -or !(Test-Path "$STEAM\steamapps\libraryfolders.vdf")) {
    Write-Warning "Steam not found!"; Start-Sleep 5; Exit 1
  }
} catch { Write-Warning "Steam not found in registry!"; Exit 1 }

#--- Targeted Apps
$apps = @(
  @{id=730; name='cs2';   mod='csgo';  installdir='Counter-Strike Global Offensive'},
)

#--- VDF parsing, minimal
function vdf_parse {
  param([string[]]$vdf)
  [ref]$line=0; $re='\A\s*("(?<k>[^"]+)"|(?<b>[\{\}]))\s*(?<v>"(?:\\"|[^"])*")?\Z'
  $obj = [ordered]@{}
  while ($line.Value -lt $vdf.Count) {
    if ($vdf[$line.Value] -match $re) {
      if ($matches.k) { $key = $matches.k }
      if ($matches.v) { $obj[$key] = $matches.v }
      elseif ($matches.b -eq '{') { $line.Value++; $obj[$key] = vdf_parse -vdf $vdf -line $line }
      elseif ($matches.b -eq '}') { break }
    }
    $line.Value++
  }
  return $obj
}

#--- Find per-app install locations
$vdf=(gc "$STEAM\steamapps\libraryfolders.vdf" -Force -EA 0); if (!$vdf) { $vdf = @('"libraryfolders"','{','}') }
$roots = @()
foreach ($nr in (vdf_parse $vdf).Item(0).Keys) {
  $entry = (vdf_parse $vdf).Item(0)[$nr]; if ($entry -and $entry["path"]) {
    $roots += $entry["path"].Trim('"')
  }
}
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
$stop=''; $kill=@('steamwebhelper','steam')
foreach ($a in $apps) { $stop += " +app_stop $($a.id)"; $kill += $a.name }
if ((Get-ItemProperty "HKCU:\Software\Valve\Steam\ActiveProcess" -EA 0).pid -gt 0 -and (Get-Process steamwebhelper -EA 0)) {
  Start-Process "$STEAM\Steam.exe" -ArgumentList "-ifrunning -silent $stop -shutdown +quit now" -Wait
}
while (Get-Process steamwebhelper,steam -EA 0) {
  $kill | ForEach-Object { Stop-Process -Name $_ -Force -EA 0 }
  Remove-Item "$STEAM\.crash" -Force -EA 0
  Start-Sleep -Milliseconds 250
}

#--- Helper to robocopy empty dirs (powershell-native fallback for robocopy)
function empty_and_clear($target) {
  if (!(Test-Path $target)) { return }
  $empty="$target\-EMPTY-"
  mkdir $empty -Force | Out-Null
  # robocopy preferred for native performance (fallback: Remove-Item)
  $null = robocopy "$empty" "$target" /MIR /R:1 /W:0 /ZB /NFL /NDL /NJH /NJS 2>&1
  # fallback
  Get-ChildItem "$target" -Recurse -File -Force -EA 0 | Remove-Item -Force -EA 0
}

Write-Host "`n• Clearing STEAM logs..." -F Cyan
empty_and_clear "$STEAM\logs"
Write-Host "`n• Clearing STEAM dumps..." -F Cyan
empty_and_clear "$STEAM\dumps"

Write-Host "`n• Clearing APP crash dumps..." -F Cyan
foreach ($app in $apps) {
  if ($app.exe) {
    $dir=Split-Path $app.exe
    Get-ChildItem "$dir\*.mdmp" -Force -EA 0 | Remove-Item -Force -EA 0
  }
}

Write-Host "`n• Clearing APP shadercache..." -F Cyan
foreach ($app in $apps) {
  $targets=@()
  if ($app.game) { $targets+= "$($app.game)\shadercache" }
  if ($app.steamapps) { $targets+= "$($app.steamapps)\shadercache\$($app.id)" }
  if ($app.steamapps -ne "$STEAM\steamapps") { $targets+= "$STEAM\steamapps\shadercache\$($app.id)" }
  foreach ($t in $targets) { empty_and_clear $t }
}

Write-Host "`n• Clearing NVIDIA Compute cache..." -F Cyan
$t = "$env:APPDATA\NVIDIA\ComputeCache"; empty_and_clear $t

Write-Host "`n• Clearing NV_Cache..." -F Cyan
$t = "$env:ProgramData\NVIDIA Corporation\NV_Cache"; empty_and_clear $t

Write-Host "`n• Clearing Local shader caches..." -F Cyan
@(
  'D3DSCache','NVIDIA\GLCache','NVIDIA\DXCache','NVIDIA\OptixCache','NVIDIA Corporation\NV_Cache',
  'AMD\DX9Cache','AMD\DxCache','AMD\DxcCache','AMD\GLCache','AMD\OglCache','AMD\VkCache','Intel\ShaderCache'
) | ForEach-Object {
  $t = "$env:LOCALAPPDATA\$_"; empty_and_clear $t
}

Write-Host "`n• Clearing LocalLow shader caches..." -F Cyan
@(
  'NVIDIA\PerDriverVersion\DXCache','NVIDIA\PerDriverVersion\GLCache','Intel\ShaderCache'
) | ForEach-Object {
  $t = "$($env:LOCALAPPDATA)\..\LocalLow\$_"; empty_and_clear $t
}

Write-Host "`n• Clearing driver temp dirs..." -F Cyan
@("$env:SystemDrive\AMD","$env:SystemDrive\NVIDIA","$env:SystemDrive\Intel") | ForEach-Object {
  empty_and_clear $_
}

Write-Host "`nAll relevant shader/log/crash caches cleaned."
Start-Sleep -Seconds 3
