#Requires -Version 5.1

<#
.SYNOPSIS
    Steam optimization: close steam, configure VDFs for max FPS, restart minimal.
#>

# Import common functions
. "$PSScriptRoot\..\Common.ps1"

$FriendsSignIn = 0
$FriendsAnimed = 0
$ShowGameIcons = 0
$NoJoystick    = 1
$NoShaders     = 1
$NoGPU         = 0

function sc-nonew($fn, $txt) {
    [IO.File]::WriteAllText($fn, $txt -join "`n")
}

function vdf_mkdir {
    param($vdf, [string]$path = '')
    $s = $path -split '\\', 2
    $key = $s[0]
    $recurse = if ($s.Count -gt 1) { $s[1] } else { $null }
    if ($key -and -not $vdf.Contains($key)) { $vdf[$key] = [ordered]@{} }
    if ($recurse) { vdf_mkdir $vdf[$key] $recurse }
}

Write-Host "`n[Steam] Restarting in minimal mode..."

try {
    $STEAM = (Get-ItemProperty "HKCU:\SOFTWARE\Valve\Steam" -ErrorAction Stop).SteamPath
    if (-not (Test-Path "$STEAM\steam.exe") -or -not (Test-Path "$STEAM\steamapps\libraryfolders.vdf")) {
        Write-Host "  Steam not found at '$STEAM' — skipped." -ForegroundColor Yellow
        exit
    }
} catch {
    Write-Host "  Steam not found in registry — skipped." -ForegroundColor Yellow
    exit
}

$QUICK  = "-silent -vrdisable -oldtraymenu -nofriendsui -no-dwrite "
if ($NoJoystick) { $QUICK += "-nojoy " }
if ($NoShaders)  { $QUICK += "-noshaders " }
if ($NoGPU)      { $QUICK += "-nodirectcomp -cef-disable-gpu -cef-disable-gpu-sandbox " }
$QUICK += "-cef-allow-browser-underlay -cef-delaypageload -cef-force-occlusion -cef-disable-hang-timeouts -console"

$focus = $false
if (Get-Process -Name 'steam', 'steamwebhelper' -ErrorAction SilentlyContinue) {
    Stop-SteamGracefully
    Remove-Item "$STEAM\.crash" -Force -ErrorAction SilentlyContinue
    $focus = $true
}

if ($focus) { $QUICK += " -foreground" }

Get-ChildItem "$STEAM\userdata\*\7\remote\sharedconfig.vdf" -Recurse | ForEach-Object {
    $file  = $_.FullName
    $write = $false
    $vdf   = ConvertFrom-VDF -Content (Get-Content $file -Force)
    if ($vdf.Count -eq 0) { $vdf = ConvertFrom-VDF -Content @('"UserRoamingConfigStore"', '{', '}') }
    vdf_mkdir $vdf.Item(0) 'Software\Valve\Steam\FriendsUI'
    $key = $vdf.Item(0)["Software"]["Valve"]["Steam"]
    if ($key["SteamDefaultDialog"] -ne '"#app_games"') { $key["SteamDefaultDialog"] = '"#app_games"'; $write = $true }
    $ui = $key["FriendsUI"]["FriendsUIJSON"]
    if (-not ($ui -like '*{*')) { $ui = '' }
    if ($FriendsSignIn -eq 0 -and ($ui -like '*bSignIntoFriends":true*' -or $ui -like '*PersonaNotifications":1*')) {
        $ui = $ui.Replace('bSignIntoFriends":true', 'bSignIntoFriends":false')
        $ui = $ui.Replace('PersonaNotifications":1', 'PersonaNotifications":0')
        $write = $true
    }
    if ($FriendsAnimed -eq 0 -and ($ui -like '*bAnimatedAvatars":true*' -or $ui -like '*bDisableRoomEffects":false*')) {
        $ui = $ui.Replace('bAnimatedAvatars":true', 'bAnimatedAvatars":false')
        $ui = $ui.Replace('bDisableRoomEffects":false', 'bDisableRoomEffects":true')
        $write = $true
    }
    $key["FriendsUI"]["FriendsUIJSON"] = $ui
    if ($write) { sc-nonew $file (ConvertTo-VDF -Data $vdf); Write-Host "  Updated $file" }
}

$opt = @{LibraryDisableCommunityContent=1; LibraryLowBandwidthMode=1; LibraryLowPerfMode=1; LibraryDisplayIconInGameList
if ($ShowGameIcons -eq 1) { $opt.LibraryDisplayIconInGameList = 1 }

Get-ChildItem "$STEAM\userdata\*\config\localconfig.vdf" -Recurse | ForEach-Object {
    $file  = $_.FullName
    $write = $false
    $vdf   = ConvertFrom-VDF -Content (Get-Content $file -Force)
    if ($vdf.Count -eq 0) { $vdf = ConvertFrom-VDF -Content @('"UserLocalConfigStore"', '{', '}') }
    vdf_mkdir $vdf.Item(0) 'Software\Valve\Steam'
    vdf_mkdir $vdf.Item(0) 'friends'
    $key = $vdf.Item(0)["Software"]["Valve"]["Steam"]
    if ($key["SmallMode"] -ne '"0"') { $key["SmallMode"] = '"0"'; $write = $true }
    foreach ($o in $opt.Keys) {
        if ($key["$o"] -ne "`"$($opt[$o])`"") { $key["$o"] = "`"$($opt[$o])`""; $write = $true }
    }
    if ($FriendsSignIn -eq 0) {
        $key = $vdf.Item(0)["friends"]
        if ($key["SignIntoFriends"] -ne '"0"') { $key["SignIntoFriends"] = '"0"'; $write = $true }
    }
    if ($write) { sc-nonew $file (ConvertTo-VDF -Data $vdf); Write-Host "  Updated $file" }
}

Start-Process -FilePath "$STEAM\Steam.exe" -ArgumentList $QUICK
Write-Host "  Steam launched in minimal mode."
