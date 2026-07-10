#Requires -Version 5.1
#Requires -RunAsAdministrator
. "$PSScriptRoot\..\Common.ps1"
. "$PSScriptRoot\ArcRaidersCommon.ps1"
<#
.SYNOPSIS
    Arc Raiders pre-launch: clear logs/crashes/temp, trim memory, optimize SSD, restart Steam minimal.
#>
$ProgressPreference = 'SilentlyContinue'

# ── Options ───────────────────────────────────────────────────────────────────
$FriendsSignIn = 0
$FriendsAnimed = 0
$ShowGameIcons = 0
$NoJoystick    = 1
$NoShaders     = 1
$NoGPU         = 1

# ── Helpers ───────────────────────────────────────────────────────────────────
$totalSize  = 0
$totalCount = 0

function Invoke-GlobClean([string]$Pattern) {
    Remove-Glob -Pattern $Pattern -TotalSize ([ref]$script:totalSize) -TotalCount ([ref]$script:totalCount)
}



# ── Arc Raiders: logs + crashes ───────────────────────────────────────────────
Write-Host "`n[Arc Raiders]"
Invoke-GlobClean "$env:LOCALAPPDATA\PioneerGame\Saved\Logs\*"
Invoke-GlobClean "$env:LOCALAPPDATA\PioneerGame\Saved\Crashes\*"
Invoke-GlobClean "$env:LOCALAPPDATA\PioneerGame\Saved\Config\CrashReportClient\*"

# ── Windows temp ──────────────────────────────────────────────────────────────
Write-Host "`n[Temp]"
Invoke-GlobClean "$env:TEMP\*"
Invoke-GlobClean "$env:windir\Temp\*"

# ── Memory: trim working sets + purge standby list ────────────────────────────
Write-Host "`n[Memory] Trimming..."
Invoke-MemoryTrim -TypeName 'MemUtil2'

# ── SSD optimize (ReTrim) ─────────────────────────────────────────────────────
Write-Host "`n[SSD] Optimizing..."
foreach ($item in Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter }) {
    $dl = $item.DriveLetter
    $med = try {
        (Get-PhysicalDisk | Where-Object {
            (Get-Partition -DriveLetter $dl -ErrorAction SilentlyContinue |
                Get-Disk -ErrorAction SilentlyContinue).UniqueId -eq $item.UniqueId
        } | Select-Object -First 1).MediaType
    } catch { 'Unspecified' }
    if ($med -ne 'HDD') {
        Optimize-Volume -DriveLetter $dl -ReTrim -Verbose:$false
        Write-Host "  ${dl}: ReTrim issued."
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
$mb = [math]::Round($totalSize / 1MB, 2)
Write-Host "`n══════════════════════════════════════"
Write-Host " Cleaned: $totalCount item(s), ${mb} MB freed."
Write-Host "══════════════════════════════════════"

# ── Steam: locate ─────────────────────────────────────────────────────────────
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

# ── Steam: build launch args ──────────────────────────────────────────────────
$quickBuilder = [System.Text.StringBuilder]::new("-silent -quicklogin -forceservice -vrdisable -oldtraymenu -nofriendsui -no-dwrite ")
if ($NoJoystick) { [void]$quickBuilder.Append("-nojoy ") }
if ($NoShaders)  { [void]$quickBuilder.Append("-noshaders ") }
if ($NoGPU)      { [void]$quickBuilder.Append("-nodirectcomp -cef-disable-gpu -cef-disable-gpu-sandbox ") }
[void]$quickBuilder.Append("-cef-allow-browser-underlay -cef-delaypageload -cef-force-occlusion -cef-disable-hang-timeouts -console")

# ── Steam: graceful shutdown then force kill ──────────────────────────────────
$focus = $false
if (Get-Process -Name 'steam', 'steamwebhelper' -ErrorAction SilentlyContinue) {
    Stop-SteamGracefully
    Remove-Item "$STEAM\.crash" -Force -ErrorAction SilentlyContinue
    $focus = $true
}

if ($focus) { [void]$quickBuilder.Append(" -foreground") }
$QUICK = $quickBuilder.ToString()

# ── Steam: update sharedconfig.vdf ────────────────────────────────────────────
foreach ($item in Get-ChildItem "$STEAM\userdata\*\7\remote\sharedconfig.vdf" -Recurse) {
    $file  = $item.FullName
    $write = $false
    $vdf   = ConvertFrom-VDF -Content (Get-Content $file -Force)
    if ($vdf.Count -eq 0) { $vdf = ConvertFrom-VDF -Content @('"UserRoamingConfigStore"', '{', '}') }
    vdf_mkdir $vdf.Item(0) 'Software\Valve\Steam\FriendsUI'
    $key = $vdf.Item(0)["Software"]["Valve"]["Steam"]
    if ($key["SteamDefaultDialog"] -ne '"#app_games"') { $key["SteamDefaultDialog"] = '"#app_games"'; $write = $true }
    $ui = $key["FriendsUI"]["FriendsUIJSON"]; if (-not ($ui -like '*{*')) { $ui = '' }
    if ($FriendsSignIn -eq 0 -and ($ui -like '*bSignIntoFriends\":true*' -or $ui -like '*PersonaNotifications\":1*')) {
        $ui = $ui.Replace('bSignIntoFriends\":true', 'bSignIntoFriends\":false')
        $ui = $ui.Replace('PersonaNotifications\":1', 'PersonaNotifications\":0'); $write = $true
    }
    if ($FriendsAnimed -eq 0 -and ($ui -like '*bAnimatedAvatars\":true*' -or $ui -like '*bDisableRoomEffects\":false*')) {
        $ui = $ui.Replace('bAnimatedAvatars\":true', 'bAnimatedAvatars\":false')
        $ui = $ui.Replace('bDisableRoomEffects\":false', 'bDisableRoomEffects\":true'); $write = $true
    }
    $key["FriendsUI"]["FriendsUIJSON"] = $ui
    if ($write) { Set-ContentNoNewline -Path $file -Content (ConvertTo-VDF -Data $vdf); Write-Host "  Updated $file" }
}

# ── Steam: update localconfig.vdf ─────────────────────────────────────────────
$opt = @{LibraryDisableCommunityContent=1; LibraryLowBandwidthMode=1; LibraryLowPerfMode=1; LibraryDisplayIconInGameList=0}
if ($ShowGameIcons -eq 1) { $opt.LibraryDisplayIconInGameList = 1 }
foreach ($item in Get-ChildItem "$STEAM\userdata\*\config\localconfig.vdf" -Recurse) {
    $file  = $item.FullName
    $write = $false
    $vdf   = ConvertFrom-VDF -Content (Get-Content $file -Force)
    if ($vdf.Count -eq 0) { $vdf = ConvertFrom-VDF -Content @('"UserLocalConfigStore"', '{', '}') }
    vdf_mkdir $vdf.Item(0) 'Software\Valve\Steam'; vdf_mkdir $vdf.Item(0) 'friends'
    $key = $vdf.Item(0)["Software"]["Valve"]["Steam"]
    if ($key["SmallMode"] -ne '"1"') { $key["SmallMode"] = '"1"'; $write = $true }
    foreach ($o in $opt.Keys) {
        if ($vdf.Item(0)["$o"] -ne """$($opt[$o])""") { $vdf.Item(0)["$o"] = """$($opt[$o])"""; $write = $true }
    }
    if ($FriendsSignIn -eq 0) {
        $key = $vdf.Item(0)["friends"]
        if ($key["SignIntoFriends"] -ne '"0"') { $key["SignIntoFriends"] = '"0"'; $write = $true }
    }
    if ($write) { Set-ContentNoNewline -Path $file -Content (ConvertTo-VDF -Data $vdf); Write-Host "  Updated $file" }
}

# ── Steam: refresh desktop shortcut ──────────────────────────────────────────
New-Shortcut -ShortcutPath "$([Environment]::GetFolderPath('Desktop'))\Steam_min.lnk" -TargetPath 'powershell' `
    -Arguments "-nop -nol -ep remotesigned -file `"$PSCommandPath`"" -Description "$STEAM\steam.exe" `
    -IconLocation "$STEAM\steam.exe,0" -WindowStyle 7

# ── Steam: launch ─────────────────────────────────────────────────────────────
Start-Process -FilePath "$STEAM\Steam.exe" -ArgumentList $QUICK
Write-Host "  Steam launched."

# ── Timer Resolution (0.5ms) ──────────────────────────────────────────────────
Write-Host "`n[TimerResolution] Ensuring 0.5ms timer resolution..."
$trExe = 'C:\tools\TimerResolution\SetTimerResolution.exe'
if (Test-Path $trExe) {
    if (-not (Get-Process -Name 'SetTimerResolution' -ErrorAction SilentlyContinue)) {
        Start-Process -FilePath $trExe -ArgumentList '--resolution 5000 --no-console' -WindowStyle Hidden
        Write-Host "  Started SetTimerResolution (0.5ms)."
    } else {
        Write-Host "  Already running."
    }
} else {
    Write-Host "  SetTimerResolution.exe not found at $trExe — skipped." -ForegroundColor Yellow
}
