# Steam_min.ps1 - always restarts Steam in SmallMode with reduced RAM and CPU usage when idle - AveYo, 2025.08.23

# Options
$FriendsSignIn = 0
$FriendsAnimed = 0
$ShowGameIcons = 0
$NoJoystick    = 1
$NoShaders     = 1
$NoGPU         = 1

# Steam quick launch arguments
$QUICK = "-silent -quicklogin -forceservice -vrdisable -oldtraymenu -nofriendsui -no-dwrite " + (if ($NoJoystick) { "-nojoy " } else { "" })
$QUICK += (if ($NoShaders) { "-noshaders " } else { "" }) + (if ($NoGPU) { "-nodirectcomp -cef-disable-gpu -cef-disable-gpu-sandbox " } else { "" })
$QUICK += "-cef-allow-browser-underlay -cef-delaypageload -cef-force-occlusion -cef-disable-hang-timeouts -console"

# Locate Steam installation
try {
  $STEAM = (Get-ItemProperty "HKCU:\SOFTWARE\Valve\Steam" -ErrorAction 0).SteamPath
  if (-not (Test-Path "$STEAM\steam.exe") -or -not (Test-Path "$STEAM\steamapps\libraryfolders.vdf")) {
    Write-Host "Steam not found!" -ForegroundColor Black -BackgroundColor Yellow; Start-Sleep 7; exit
  }
} catch { Write-Error "Steam not found in registry!"; exit }

# If running, shut down gracefully
$focus = $false
if ((Get-ItemProperty "HKCU:\Software\Valve\Steam\ActiveProcess" -ErrorAction 0).pid -gt 0 -and (Get-Process -Name steamwebhelper -ErrorAction SilentlyContinue)) {
  Start-Process "$STEAM\Steam.exe" -ArgumentList '-ifrunning -silent -shutdown +quit now' -Wait
  $focus = $true
}
# Force kill if needed
while (Get-Process -Name steamwebhelper,steam -ErrorAction SilentlyContinue) {
  Stop-Process -Name steamwebhelper,steam -Force -ErrorAction SilentlyContinue
  Remove-Item "$STEAM\.crash" -Force -ErrorAction SilentlyContinue
  $focus = $true
  Start-Sleep -Milliseconds 250
}
if ($focus) { $QUICK += " -foreground" }

# --- VDF parse/print helpers
function vdf_parse {
  param([string[]]$vdf, [ref]$line=([ref]0), [string]$re='\A\s*("(?<k>[^"]+)"|(?<b>[\{\}]))\s*(?<v>"(?:\\"|[^"])*")?\Z')
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
function vdf_print {
  param($vdf, [ref]$indent=([ref]0))
  if ($vdf -isnot [System.Collections.Specialized.OrderedDictionary] -and $vdf -isnot [hashtable]) {return}
  foreach ($key in $vdf.Keys) {
    if ($vdf[$key] -is [System.Collections.Specialized.OrderedDictionary] -or $vdf[$key] -is [hashtable]) {
      $tabs = "`t" * $indent.Value
      Write-Output "$tabs""$key`n$tabs{`n"
      $indent.Value++; vdf_print -vdf $vdf[$key] -indent $indent; $indent.Value--
      Write-Output "$tabs}`n"
    } else {
      $tabs = "`t" * $indent.Value
      Write-Output "$tabs""$key`t`t$($vdf[$key])`n"
    }
  }
}
function vdf_mkdir {
  param($vdf, [string]$path = '')
  $s = $path -split '\\',2
  $key, $recurse = $s[0], $s.Count -gt 1 ? $s[1] : $null
  if ($key -and $vdf.Keys -notcontains $key) { $vdf[$key] = [ordered]@{} }
  if ($recurse) { vdf_mkdir $vdf[$key] $recurse }
}
function sc-nonew($fn, $txt) {
  if ((Get-Command Set-Content).Parameters['NoNewline']) { Set-Content -LiteralPath $fn $txt -NoNewline -Force }
  else { [IO.File]::WriteAllText($fn, $txt -join [char]10) }
}

# --- Update sharedconfig.vdf: main UI/friends/game list tweaks
Get-ChildItem "$STEAM\userdata\*\7\remote\sharedconfig.vdf" -Recurse | ForEach-Object {
  $file = $_.FullName
  $write = $false
  $vdf = vdf_parse -vdf (Get-Content $file -Force)
  if ($vdf.Count -eq 0) { $vdf = vdf_parse @('"UserRoamingConfigStore"','{','}') }
  vdf_mkdir $vdf.Item(0) 'Software\Valve\Steam\FriendsUI'
  $key = $vdf.Item(0)["Software"]["Valve"]["Steam"]
  if ($key["SteamDefaultDialog"] -ne '"#app_games"') { $key["SteamDefaultDialog"] = '"#app_games"'; $write = $true }
  $ui = $key["FriendsUI"]["FriendsUIJSON"]; if (-not ($ui -like '*{*')) { $ui = '' }
  if ($FriendsSignIn -eq 0 -and ($ui -like '*bSignIntoFriends\":true*' -or $ui -like '*PersonaNotifications\":1*') ) {
    $ui = $ui.Replace('bSignIntoFriends\":true','bSignIntoFriends\":false')
    $ui = $ui.Replace('PersonaNotifications\":1','PersonaNotifications\":0'); $write = $true
  }
  if ($FriendsAnimed -eq 0 -and ($ui -like '*bAnimatedAvatars\":true*' -or $ui -like '*bDisableRoomEffects\":false*') ) {
    $ui = $ui.Replace('bAnimatedAvatars\":true','bAnimatedAvatars\":false')
    $ui = $ui.Replace('bDisableRoomEffects\":false','bDisableRoomEffects\":true'); $write = $true
  }
  $key["FriendsUI"]["FriendsUIJSON"] = $ui
  if ($write) { sc-nonew $file (vdf_print $vdf); Write-Output "Updated $file" }
}

# --- Update localconfig.vdf: library perf/small mode
$opt = @{LibraryDisableCommunityContent=1; LibraryLowBandwidthMode=1; LibraryLowPerfMode=1; LibraryDisplayIconInGameList=0}
if ($ShowGameIcons -eq 1) {$opt.LibraryDisplayIconInGameList = 1}
Get-ChildItem "$STEAM\userdata\*\config\localconfig.vdf" -Recurse | ForEach-Object {
  $file = $_.FullName
  $write = $false
  $vdf = vdf_parse -vdf (Get-Content $file -Force)
  if ($vdf.Count -eq 0) { $vdf = vdf_parse @('"UserLocalConfigStore"','{','}') }
  vdf_mkdir $vdf.Item(0) 'Software\Valve\Steam'; vdf_mkdir $vdf.Item(0) 'friends'
  $key = $vdf.Item(0)["Software"]["Valve"]["Steam"]
  if ($key["SmallMode"] -ne '"1"') { $key["SmallMode"] = '"1"'; $write = $true }
  foreach ($o in $opt.Keys) { if ($vdf.Item(0)["$o"] -ne """$($opt[$o])""") {
    $vdf.Item(0)["$o"] = """$($opt[$o])"""; $write = $true
  }}
  if ($FriendsSignIn -eq 0) {
    $key = $vdf.Item(0)["friends"]
    if ($key["SignIntoFriends"] -ne '"0"') { $key["SignIntoFriends"] = '"0"'; $write = $true }
  }
  if ($write) { sc-nonew $file (vdf_print $vdf); Write-Output "Updated $file" }
}

# --- Refresh desktop shortcut: Steam_min
$wsh = New-Object -ComObject WScript.Shell
$shortcutPath = "$([Environment]::GetFolderPath('Desktop'))\Steam_min.lnk"
$lnk = $wsh.CreateShortcut($shortcutPath)
$lnk.Description = "$STEAM\steam.exe"
$lnk.IconLocation = "$STEAM\steam.exe,0"
$lnk.WindowStyle = 7
$lnk.TargetPath  = "powershell"
$lnk.Arguments = "-nop -nol -ep remotesigned -file `"$PSCommandPath`""
$lnk.Save()

# --- Start Steam with tweaks
Start-Process -FilePath "$STEAM\Steam.exe" -ArgumentList $QUICK
