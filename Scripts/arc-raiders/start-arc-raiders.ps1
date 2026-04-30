#Requires -Version 5.1
#Requires -RunAsAdministrator
. "$PSScriptRoot\..\Common.ps1"
<#
.SYNOPSIS
    Arc Raiders pre-launch: clear logs/crashes/temp, trim memory, optimize SSD, restart Steam minimal.
#>

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

function Remove-Glob {
    param([string]$Pattern)
    $items = Get-Item -Path $Pattern -Force -ErrorAction SilentlyContinue
    foreach ($item in $items) {
        $sz = if ($item.PSIsContainer) {
            $dirSize = 0
            try {
                $dirInfo = [System.IO.DirectoryInfo]::new($item.FullName)
                foreach ($f in $dirInfo.EnumerateFiles('*', [System.IO.SearchOption]::AllDirectories)) {
                    $dirSize += $f.Length
                }
                $dirSize
            } catch {
                (Get-ChildItem $item -Recurse -File -Force -ErrorAction SilentlyContinue |
                    Measure-Object Length -Sum).Sum
            }
        } else { $item.Length }
        $script:totalSize  += [long]$sz
        $script:totalCount++
        Remove-Item $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  DEL  $($item.FullName)"
    }
}

    if ((Get-Command Set-Content).Parameters['NoNewline']) { Set-Content -LiteralPath $fn $txt -NoNewline -Force }
    else { [IO.File]::WriteAllText($fn, $txt -join [char]10) }
}

    param($vdf, [string]$path = '')
    $s = $path -split '\\', 2
    $key, $recurse = $s[0], ($s.Count -gt 1 ? $s[1] : $null)
    if ($key -and $vdf.Keys -notcontains $key) { $vdf[$key] = [ordered]@{} }
    if ($recurse) { vdf_mkdir $vdf[$key] $recurse }
}

# ── Arc Raiders: logs + crashes ───────────────────────────────────────────────
Write-Host "`n[Arc Raiders]"
Remove-Glob "$env:LOCALAPPDATA\PioneerGame\Saved\Logs\*"
Remove-Glob "$env:LOCALAPPDATA\PioneerGame\Saved\Crashes\*"
Remove-Glob "$env:LOCALAPPDATA\PioneerGame\Saved\Config\CrashReportClient\*"

# ── Windows temp ──────────────────────────────────────────────────────────────
Write-Host "`n[Temp]"
Remove-Glob "$env:TEMP\*"
Remove-Glob "$env:windir\Temp\*"

# ── Memory: trim working sets + purge standby list ────────────────────────────
Write-Host "`n[Memory] Trimming..."

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class MemUtil2 {
    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);
    [DllImport("kernel32.dll", SetLastError=true)]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);
    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr h);
    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int infoClass, IntPtr buf, int len);

    public static void TrimAll() {
        foreach (var p in System.Diagnostics.Process.GetProcesses()) {
            try {
                IntPtr h = OpenProcess(0x1F0FFF, false, p.Id);
                if (h != IntPtr.Zero) { EmptyWorkingSet(h); CloseHandle(h); }
            } catch {}
        }
    }
    public static void PurgeStandby() {
        IntPtr buf = Marshal.AllocHGlobal(4);
        Marshal.WriteInt32(buf, 4);
        NtSetSystemInformation(80, buf, 4);
        Marshal.FreeHGlobal(buf);
    }
}
"@ -ErrorAction SilentlyContinue

try { [MemUtil2]::TrimAll();      Write-Host "  Working sets trimmed."  } catch { Write-Host "  WS trim skipped: $_" }
try { [MemUtil2]::PurgeStandby(); Write-Host "  Standby list purged."  } catch { Write-Host "  Standby purge skipped: $_

# ── SSD optimize (ReTrim) ─────────────────────────────────────────────────────
Write-Host "`n[SSD] Optimizing..."
Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter } | ForEach-Object {
    $dl = $_.DriveLetter
    $med = try {
        (Get-PhysicalDisk | Where-Object {
            (Get-Partition -DriveLetter $dl -ErrorAction SilentlyContinue |
                Get-Disk -ErrorAction SilentlyContinue).UniqueId -eq $_.UniqueId
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
$QUICK  = "-silent -quicklogin -forceservice -vrdisable -oldtraymenu -nofriendsui -no-dwrite "
$QUICK += if ($NoJoystick) { "-nojoy " } else { "" }
$QUICK += if ($NoShaders)  { "-noshaders " } else { "" }
$QUICK += if ($NoGPU)      { "-nodirectcomp -cef-disable-gpu -cef-disable-gpu-sandbox " } else { "" }
$QUICK += "-cef-allow-browser-underlay -cef-delaypageload -cef-force-occlusion -cef-disable-hang-timeouts -console"

# ── Steam: graceful shutdown then force kill ──────────────────────────────────
$focus = $false
if (Get-Process -Name 'steam', 'steamwebhelper' -ErrorAction SilentlyContinue) {
    Stop-SteamGracefully
    Remove-Item "$STEAM\.crash" -Force -ErrorAction SilentlyContinue
    $focus = $true
}

if ($focus) { $QUICK += " -foreground" }

# ── Steam: update sharedconfig.vdf ────────────────────────────────────────────
Get-ChildItem "$STEAM\userdata\*\7\remote\sharedconfig.vdf" -Recurse | ForEach-Object {
    $file  = $_.FullName
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
    if ($FriendsAnimed -eq 0 -and ($ui -like '*bAnimatedAvatars\":true*' -or $ui -like '*bDisableRoomEffects\":false*'))
        $ui = $ui.Replace('bAnimatedAvatars\":true', 'bAnimatedAvatars\":false')
        $ui = $ui.Replace('bDisableRoomEffects\":false', 'bDisableRoomEffects\":true'); $write = $true
    }
    $key["FriendsUI"]["FriendsUIJSON"] = $ui
    if ($write) { sc-nonew $file (ConvertTo-VDF -Data $vdf); Write-Host "  Updated $file" }
}

# ── Steam: update localconfig.vdf ─────────────────────────────────────────────
$opt = @{LibraryDisableCommunityContent=1; LibraryLowBandwidthMode=1; LibraryLowPerfMode=1; LibraryDisplayIconInGameList
if ($ShowGameIcons -eq 1) { $opt.LibraryDisplayIconInGameList = 1 }
Get-ChildItem "$STEAM\userdata\*\config\localconfig.vdf" -Recurse | ForEach-Object {
    $file  = $_.FullName
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
    if ($write) { sc-nonew $file (ConvertTo-VDF -Data $vdf); Write-Host "  Updated $file" }
}

# ── Steam: refresh desktop shortcut ──────────────────────────────────────────
$wsh  = New-Object -ComObject WScript.Shell
$lnk  = $wsh.CreateShortcut("$([Environment]::GetFolderPath('Desktop'))\Steam_min.lnk")
$lnk.Description  = "$STEAM\steam.exe"
$lnk.IconLocation = "$STEAM\steam.exe,0"
$lnk.WindowStyle  = 7
$lnk.TargetPath   = "powershell"
$lnk.Arguments    = "-nop -nol -ep remotesigned -file `"$PSCommandPath`""
$lnk.Save()

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
