#Requires -RunAsAdministrator
# Windows Setup Script - Comprehensive automated installation and configuration
# Combines software installation, system optimization, bloatware removal, and privacy tweaks

if (Test-Path "$PSScriptRoot\Scripts\Common.ps1") {
  . "$PSScriptRoot\Scripts\Common.ps1"
  Request-AdminElevation
  Initialize-ConsoleUI -Title "Windows Setup Script (Administrator)"
} else {
  if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
  }
  $Host.UI.RawUI.WindowTitle = "Windows Setup Script (Administrator)"
  $Host.UI.RawUI.BackgroundColor = "Black"
  Clear-Host
}

$null = reg add "HKCU\CONSOLE" /v "VirtualTerminalLevel" /t REG_DWORD /d "1" /f 2>&1
Set-Location -Path $env:USERPROFILE -ErrorAction SilentlyContinue
$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Windows Setup & Configuration Script" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# SYSTEM CONFIGURATION - Registry Tweaks
# ============================================
Write-Host "[1/12] Applying system configurations..." -ForegroundColor Cyan

# Explorer Settings
$explorerSettings = @{
  'Hidden' = 1
  'HideFileExt' = 0
  'HideDrivesWithNoMedia' = 0
  'LaunchTo' = 1
  'FolderContentsInfoTip' = 0
  'StartupDelayInMSec' = 0
  'ShowTaskViewButton' = 0
  'ExtendedUIHoverTime' = 10000
  'Start_TrackDocs' = 0
  'TaskbarAl' = 0
  'TaskbarDa' = 0
  'TaskbarMn' = 0
}
foreach ($setting in $explorerSettings.GetEnumerator()) {
  $null = reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v $setting.Name /t REG_DWORD /d $setting.Value /f 2>&1
}
$null = reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" /v "FullPath" /t REG_DWORD /d 1 /f 2>&1
$null = reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" /v "StartupDelayInMSec" /t REG_DWORD /d 0 /f 2>&1
$null = reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v "VisualFXSetting" /t REG_DWORD /d 2 /f 2>&1

# Dark Mode
$null = reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "AppsUseLightTheme" /t REG_DWORD /d 0 /f 2>&1
$null = reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "SystemUsesLightTheme" /t REG_DWORD /d 0 /f 2>&1
$null = reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v "EnableTransparency" /t REG_DWORD /d 0 /f 2>&1

# Classic Right-Click Menu (Win11)
$null = reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /ve /f 2>&1

# Privacy & Telemetry
$privacySettings = @{
  'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection' = @{'AllowTelemetry' = 0}
  'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' = @{'PublishUserActivities' = 0; 'UploadUserActivities' = 0; 'EnableActivityFeed' = 0}
  'HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' = @{'DisableLocation' = 1}
  'HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' = @{'Enabled' = 0}
  'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search' = @{'AllowCortana' = 0}
  'HKCU\Software\Microsoft\Siuf\Rules' = @{'NumberOfSIUFInPeriod' = 0}
  'HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy' = @{'TailoredExperiencesWithDiagnosticDataEnabled' = 0}
  'HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' = @{'SubscribedContent-338388Enabled' = 0; 'SoftLandingEnabled' = 0}
  'HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting' = @{'Disabled' = 1}
  'HKLM\SOFTWARE\Policies\Microsoft\SQMClient\Windows' = @{'CEIPEnable' = 0}
  'HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' = @{'GlobalUserDisabled' = 1}
  'HKCU\Software\Microsoft\Windows\CurrentVersion\Search' = @{'BingSearchEnabled' = 0}
  'HKLM\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config' = @{'AutoConnectAllowedOEM' = 0}
}
foreach ($key in $privacySettings.GetEnumerator()) {
  foreach ($value in $key.Value.GetEnumerator()) {
    $null = reg add $key.Name /v $value.Name /t REG_DWORD /d $value.Value /f 2>&1
  }
}

# OneDrive Removal
$null = reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v "DisableFileSyncNGSC" /t REG_DWORD /d 1 /f 2>&1
$null = reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f 2>&1

# Gaming Optimizations
$null = reg add "HKCU\System\GameConfigStore" /v "GameDVR_Enabled" /t REG_DWORD /d 0 /f 2>&1
$null = reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v "AppCaptureEnabled" /t REG_DWORD /d 0 /f 2>&1
$null = reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v "HwSchMode" /t REG_DWORD /d 2 /f 2>&1

# Mouse Settings - Disable Acceleration
$null = reg add "HKCU\Control Panel\Mouse" /v "MouseSpeed" /t REG_SZ /d "0" /f 2>&1
$null = reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold1" /t REG_SZ /d "0" /f 2>&1
$null = reg add "HKCU\Control Panel\Mouse" /v "MouseThreshold2" /t REG_SZ /d "0" /f 2>&1

# Disable Sticky/Filter/Toggle Keys
$null = reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v "Flags" /t REG_SZ /d "506" /f 2>&1
$null = reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v "Flags" /t REG_SZ /d "122" /f 2>&1
$null = reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v "Flags" /t REG_SZ /d "58" /f 2>&1

# Network Optimizations - Reduce Latency
$null = reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "NetworkThrottlingIndex" /t REG_DWORD /d 4294967295 /f 2>&1
$null = reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v "SystemResponsiveness" /t REG_DWORD /d 0 /f 2>&1
$null = reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" /v "TcpAckFrequency" /t REG_DWORD /d 1 /f 2>&1
$null = reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" /v "TCPNoDelay" /t REG_DWORD /d 1 /f 2>&1

# Windows Update Settings
$null = reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v "NoAutoRebootWithLoggedOnUsers" /t REG_DWORD /d 1 /f 2>&1

# Compression Settings
$null = reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\SideBySide\Configuration" /v "DisableResetbase" /t REG_DWORD /d 0 /f 2>&1
$null = reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v "NtfsDisableCompression" /t REG_DWORD /d 0 /f 2>&1
$null = reg add "HKLM\SYSTEM\CurrentControlSet\Policies" /v "NtfsDisableCompression" /t REG_DWORD /d 0 /f 2>&1

# ============================================
# POWER MANAGEMENT
# ============================================
Write-Host "[2/12] Configuring power settings..." -ForegroundColor Cyan
powercfg -h off
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-Null
powercfg /S e9a42b02-d5df-448d-aa00-03f14749eb61
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100
powercfg -setactive SCHEME_CURRENT
fsutil behavior set disablecompression 0 2>&1 | Out-Null

# ============================================
# SERVICE MANAGEMENT
# ============================================
Write-Host "[3/12] Disabling unnecessary services..." -ForegroundColor Cyan
$servicesToDisable = @('SysMain', 'NvTelemetryContainer', 'icssvc', 'Fax')
foreach ($service in $servicesToDisable) {
  sc.exe config $service start= disabled 2>&1 | Out-Null
  sc.exe stop $service 2>&1 | Out-Null
}

# ============================================
# DNS CONFIGURATION
# ============================================
Write-Host "[4/12] Configuring DNS..." -ForegroundColor Cyan
netsh interface ip set dns "Ethernet" static 1.1.1.1 primary 2>&1 | Out-Null
netsh interface ip add dns "Ethernet" 1.0.0.1 index=2 2>&1 | Out-Null
netsh interface ip set dns "Wi-Fi" static 1.1.1.1 primary 2>&1 | Out-Null
netsh interface ip add dns "Wi-Fi" 1.0.0.1 index=2 2>&1 | Out-Null

# ============================================
# BLOATWARE REMOVAL
# ============================================
Write-Host "[5/12] Removing bloatware..." -ForegroundColor Cyan
taskkill /f /im OneDrive.exe 2>&1 | Out-Null
& "$env:SystemRoot\System32\OneDriveSetup.exe" /uninstall 2>&1 | Out-Null
& "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" /uninstall 2>&1 | Out-Null

$bloatwareApps = @(
  'Microsoft.XboxGamingOverlay', 'Microsoft.XboxGameCallableUI', 'Microsoft.XboxIdentityProvider',
  'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.Xbox.TCUI', '*3DViewer*', 'Microsoft.Microsoft3DViewer',
  'Microsoft.MicrosoftOfficeHub', '*WebExperience*', 'MicrosoftWindows.Client.WebExperience',
  'MicrosoftTeams*', '*Clipchamp*', 'Microsoft.BingWeather', 'Microsoft.BingNews',
  '*CandyCrush*', '*BubbleWitch*', 'king.com*', '*MarchofEmpires*',
  'Microsoft.MicrosoftSolitaireCollection', 'Microsoft.MixedReality.Portal', '*HolographicFirstRun*',
  'Microsoft.SkypeApp', 'Microsoft.GetHelp', 'Microsoft.YourPhone', '*WindowsPhone*',
  'Microsoft.Getstarted', 'Microsoft.MSPaint', 'Microsoft.Office.OneNote',
  'microsoft.windowscommunicationsapps', 'Microsoft.WindowsMaps', 'Microsoft.WindowsCamera',
  'Microsoft.WindowsSoundRecorder'
)
foreach ($app in $bloatwareApps) {
  Get-AppxPackage $app | Remove-AppxPackage 2>&1 | Out-Null
}

# ============================================
# SOFTWARE INSTALLATION
# ============================================
Write-Host "[6/12] Updating existing packages..." -ForegroundColor Cyan
winget upgrade -r -u -h --accept-package-agreements --accept-source-agreements --force --purge --disable-interactivity --nowarn --no-proxy --include-unknown 2>&1 | Out-Null

Write-Host "[7/12] Installing runtimes..." -ForegroundColor Cyan
$runtimes = @(
  'Microsoft.VCRedist.2015+.x64', 'Microsoft.VCRedist.2013.x64',
  'Microsoft.DotNet.DesktopRuntime.9', 'Microsoft.DotNet.DesktopRuntime.8', 'Microsoft.DotNet.DesktopRuntime.7',
  'Microsoft.DotNet.Runtime.6', 'Microsoft.DotNet.Framework.DeveloperPack_4',
  'Microsoft.DirectX', 'KhronosGroup.VulkanRT', 'KhronosGroup.VulkanSDK', 'Microsoft.XNARedist',
  'Oracle.JavaRuntimeEnvironment', 'EclipseAdoptium.Temurin.21.JRE', 'EclipseAdoptium.Temurin.25.JRE',
  'OpenAL.OpenAL'
)
foreach ($pkg in $runtimes) { winget install --id=$pkg -e -h 2>&1 | Out-Null }

Write-Host "[8/12] Installing toolchains..." -ForegroundColor Cyan
$toolchains = @(
  'MartinStorsjo.LLVM-MinGW.UCRT', 'Rustlang.Rust.MSVC', 'astral-sh.uv', 'Oven-sh.Bun',
  'oxc-project.oxlint', 'BiomeJS.Biome', 'koalaman.shellcheck', 'ast-grep.ast-grep', 'SQLite.SQLite'
)
foreach ($pkg in $toolchains) { winget install --id=$pkg -e -h 2>&1 | Out-Null }
if (Get-Command uv -ErrorAction SilentlyContinue) { uv python install 2>&1 | Out-Null }

Write-Host "[9/12] Installing development tools..." -ForegroundColor Cyan
$devTools = @(
  'Git.Git', 'GitHub.cli', 'evilmartians.lefthook', 'Notepad++.Notepad++', 'VSCodium.VSCodium',
  'Microsoft.PowerShell', 'Microsoft.WindowsTerminal', 'CodeSector.TeraCopy', 'Microsoft.VisualStudioCode',
  'MathiasCodes.Winstow', 'OpenJS.NodeJS', 'PuTTY.PuTTY', 'Eugeny.Terminus'
)
foreach ($pkg in $devTools) { winget install --id=$pkg -e -h 2>&1 | Out-Null }

Write-Host "[10/12] Installing CLI tools..." -ForegroundColor Cyan
$cliTools = @(
  'eza-community.eza', 'BurntSushi.ripgrep.MSVC', 'Genivia.ugrep', 'sharkdp.fd',
  'sharkdp.bat', 'dandavison.delta', 'Starship.Starship', 'JanDeDobbeleer.OhMyPosh'
)
foreach ($pkg in $cliTools) { winget install --id=$pkg -e -h 2>&1 | Out-Null }

Write-Host "[11/12] Installing applications..." -ForegroundColor Cyan
$applications = @(
  'CodecGuide.K-LiteCodecPack.Basic', 'Microsoft.Sysinternals.Autoruns', 'Sysinternals.Autologon',
  'AutoHotkey.AutoHotkey', 'UPX.UPX', 'VideoLAN.VLC', 'GIMP.GIMP', 'tannerhelland.PhotoDemon',
  'Greenshot.Greenshot', 'eibol.FFmpegBatchAVConverter', 'HandBrake.HandBrake', 'XnSoft.XnViewMP',
  'XnSoft.XnConvert', 'Avidemux.Avidemux', 'Nikkho.FileOptimizer', 'xanderfrangos.crushee',
  'SaeraSoft.CaesiumImageCompressor', 'OptiPNG.OptiPNG', 'fhanau.Efficient-Compression-Tool',
  'Kornelski.DSSIM', 'chaiNNer-org.chaiNNer', 'OBSProject.OBSStudio', 'Meltytech.Shotcut',
  '7zip.7zip', 'Meta.Zstandard', 'IridiumIO.CompactGUI', 'aria2.aria2', 'GiantPinkRobots.Varia',
  'aandrew-me.ytDownloader', 'DevToys-app.DevToys', 'TimVisee.ffsend', 'Intel.PresentMon.Beta',
  'WindowsPostInstallWizard.UniversalSilentSwitchFinder', 'jdx.mise', 'topgrade-rs.topgrade',
  'MartiCliment.UniGetUI', 'chocolatey.chocolatey', 'Chocolatey.ChocolateyGUI', 'GorillaDevs.Ferium',
  'Ablaze.Floorp', 'Mozilla.Firefox', 'HeroicGamesLauncher.HeroicGamesLauncher', 'Valve.Steam',
  'MoonlightGameStreamingProject.Moonlight', 'smartfrigde.Legcord', 'PrismLauncher.PrismLauncher',
  'Cemu.Cemu', 'Modrinth.ModrinthApp', 'Playnite.Playnite', 'DevelopedMethods.playit',
  'Libretro.RetroArch', 'EpicGames.EpicGamesLauncher', 'Guru3D.Afterburner.Beta', 'BleachBit.BleachBit',
  'qarmin.czkawka.gui', 'EditorConfig-Checker.EditorConfig-Checker', 'SingularLabs.CCEnhancer',
  'szTheory.exifcleaner', 'RevoUninstaller.RevoUninstaller', 'Klocman.BulkCrapUninstaller',
  'WinDirStat.WinDirStat', 'GlennDelahoy.SnappyDriverInstallerOrigin', 'SteelSeries.SteelSeriesEngine',
  'ToastyX.CustomResolutionUtility', 'TechPowerUp.NVCleanstall', 'Wagnardsoft.DisplayDriverUninstaller',
  'ViGEm.ViGEmBus', 'lostindark.DriverStoreExplorer', 'Microsoft.EdgeDriver', 'Recol.DLSSUpdater',
  'Nlitesoft.NTLite', 'CodingWondersSoftware.DISMTools.Stable', 'Rclone.Rclone', 'Upscayl.Upscayl',
  'Universal-Debloater-Alliance.uad-ng', 'TheDocumentFoundation.LibreOffice', 'Audacity.Audacity',
  'KDE.Kdenlive', 'voidtools.Everything', 'CPUID.CPU-Z', 'Microsoft.PowerToys', 'TechPowerUp.GPU-Z',
  'Rainmeter.Rainmeter', 'ShareX.ShareX', 'ClamWin.ClamWin', 'mpv.net'
)
foreach ($pkg in $applications) { winget install --id=$pkg -e -h 2>&1 | Out-Null }

winget install "FFmpeg (Essentials Build)" -h 2>&1 | Out-Null
winget install CodeF0x.ffzap -h 2>&1 | Out-Null
winget install PaulPacifico.ShutterEncoder -h 2>&1 | Out-Null
winget install Microsoft.Edit -h 2>&1 | Out-Null
winget install yadm -h 2>&1 | Out-Null

# GMK Driver
Invoke-RestMethod http://offset-power.net/GMKDriver/setup.exe -OutFile "$env:TEMP\gmk.exe"
& "$env:TEMP\gmk.exe" 2>&1 | Out-Null

# HEVC/HEIF Extensions
Get-AppXPackage -AllUsers *Microsoft.HEVCVideoExtension* | ForEach-Object {
  Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" 2>&1 | Out-Null
}
Get-AppXPackage -AllUsers *Microsoft.HEIFImageExtension* | ForEach-Object {
  Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" 2>&1 | Out-Null
}

# Scoop
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
Invoke-RestMethod get.scoop.sh -OutFile "$env:TEMP\install.ps1"
& "$env:TEMP\install.ps1" -NoProxy 2>&1 | Out-Null
if (Get-Command scoop -ErrorAction SilentlyContinue) { scoop bucket add extras 2>&1 | Out-Null }

# ============================================
# CLEANUP & MAINTENANCE
# ============================================
Write-Host "[12/12] Performing cleanup..." -ForegroundColor Cyan

# Firefox Cleanup
$firefoxFiles = @(
  "$env:ProgramFiles\Mozilla Firefox\crashreporter.exe",
  "$env:ProgramFiles\Mozilla Firefox\browser\features\pictureinpicture@mozilla.org.xpi",
  "$env:ProgramFiles\Mozilla Firefox\browser\features\screenshots@mozilla.org.xpi",
  "$env:ProgramFiles\Mozilla Firefox\browser\VisualElements\PrivateBrowsing_150.png",
  "$env:ProgramFiles\Mozilla Firefox\browser\VisualElements\VisualElements_150.png"
)
foreach ($file in $firefoxFiles) { Remove-Item -Path $file -Force 2>&1 | Out-Null }

# Event Logs
wevtutil.exe cl Application 2>&1 | Out-Null
wevtutil.exe cl System 2>&1 | Out-Null

# Temp Files
$tempPaths = @(
  "$env:TEMP\*", "$env:TMP\*", "$env:SystemDrive\*.tmp", "$env:SystemDrive\*._mp",
  "$env:WINDIR\temp\*", "$env:AppData\temp\*", "$env:USERPROFILE\AppData\LocalLow\Temp\*",
  "$env:SystemDrive\*.log", "$env:SystemDrive\*.old", "$env:SystemDrive\*.trace",
  "$env:WINDIR\*.bak", "$env:SystemDrive\*.chk", "$env:WINDIR\system32\energy-report.html",
  "$env:SystemDrive\AMD\*", "$env:SystemDrive\NVIDIA\*", "$env:SystemDrive\INTEL\*",
  "$env:USERPROFILE\AppData\Local\Temp\*", "$env:WINDIR\TEMP\*", "$env:SystemDrive\Windows\Temp\*",
  "$env:WINDIR\Prefetch\*", "$env:WINDIR\Logs\*", "$env:USERPROFILE\AppData\Local\cache\*",
  "$env:WINDIR\logs\CBS\*"
)
foreach ($path in $tempPaths) { Remove-Item -Path $path -Recurse -Force 2>&1 | Out-Null }

# NVIDIA Cleanup
$nvidiaPaths = @(
  "$env:ProgramFiles\Nvidia Corporation\Installer2", "$env:ProgramFiles\NVIDIA Corporation\Installer",
  "${env:ProgramFiles(x86)}\NVIDIA Corporation\Installer", "${env:ProgramFiles(x86)}\NVIDIA Corporation\Installer2",
  "$env:ProgramData\NVIDIA Corporation\Downloader", "$env:ProgramData\NVIDIA\Downloader",
  "$env:ALLUSERSPROFILE\NVIDIA Corporation\NetService\*.exe"
)
foreach ($path in $nvidiaPaths) { Remove-Item -Path $path -Recurse -Force 2>&1 | Out-Null }

# System Cleanup
$systemPaths = @(
  "$env:SystemDrive\MSOCache", "$env:SystemDrive\i386", "$env:SystemDrive\RECYCLER",
  "$env:SystemDrive\`$Recycle.Bin", "$env:ALLUSERSPROFILE\Microsoft\Windows\WER\ReportArchive",
  "$env:ALLUSERSPROFILE\Microsoft\Windows\WER\ReportQueue",
  "$env:ALLUSERSPROFILE\Microsoft\Windows Defender\Scans\History\Results\Quick",
  "$env:ALLUSERSPROFILE\Microsoft\Windows Defender\Scans\History\Results\Resource",
  "$env:ALLUSERSPROFILE\Microsoft\Search\Data\Temp", "$env:WINDIR\Web\Wallpaper\Dell"
)
foreach ($path in $systemPaths) { Remove-Item -Path $path -Recurse -Force 2>&1 | Out-Null }

# OneDrive Cleanup
$ODrive = "$env:USERPROFILE\OneDrive"
if (Test-Path $ODrive) {
  $oneDrivePatterns = @("*.bak", "*LOG", "*.old", "*.trace", "*.tmp")
  foreach ($pattern in $oneDrivePatterns) { Remove-Item -Path "$ODrive\$pattern" -Recurse -Force 2>&1 | Out-Null }
  $scalingFactors = @("chrome_200_percent.pak", "chrome_300_percent.pak", "chrome_400_percent.pak")
  foreach ($factor in $scalingFactors) {
    Get-ChildItem -Path $ODrive -Filter $factor -Recurse 2>&1 | Remove-Item -Force 2>&1 | Out-Null
  }
}

# Root Drive Cleanup
$extensions = @('bat', 'cmd', 'txt', 'log', 'jpg', 'jpeg', 'tmp', 'temp', 'bak', 'backup', 'exe')
foreach ($ext in $extensions) { Remove-Item -Path "$env:SystemDrive\*.$ext" -Force 2>&1 | Out-Null }

# Windows Files
$winFiles = @('*.log', '*.txt', '*.bmp', '*.tmp')
foreach ($pattern in $winFiles) { Remove-Item -Path "$env:WINDIR\$pattern" -Force 2>&1 | Out-Null }

# Registry Cleanup
$null = reg delete "HKCU\SOFTWARE\Classes\Local Settings\Muicache" /f 2>&1

# Disk Operations
Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:65535" -NoNewWindow -Wait 2>&1 | Out-Null
if (Get-Command msizap -ErrorAction SilentlyContinue) { msizap G! 2>&1 | Out-Null }

# System Maintenance
DISM /Online /Cleanup-Image /RestoreHealth /Quiet
DISM /Cleanup-Mountpoints
DISM /CleanUp-Wim
DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase
sfc /scannow
ipconfig /release 2>&1 | Out-Null
ipconfig /renew 2>&1 | Out-Null
ipconfig /flushdns 2>&1 | Out-Null
netsh winsock reset 2>&1 | Out-Null
netsh int ip reset 2>&1 | Out-Null
chkdsk /scan 2>&1 | Out-Null

# Final Updates
winget upgrade -h -r -u --accept-package-agreements --accept-source-agreements --include-unknown --force --purge --disable-interactivity 2>&1 | Out-Null
if (Get-Command scoop -ErrorAction SilentlyContinue) { scoop update --all 2>&1 | Out-Null }
if (Get-Command choco -ErrorAction SilentlyContinue) { choco upgrade all -y 2>&1 | Out-Null }
if (Get-Command pip -ErrorAction SilentlyContinue) {
  pip list --outdated --format=freeze | ForEach-Object { pip install --upgrade ($_ -split '==')[0] } 2>&1 | Out-Null
}

Write-Host "Setup completed successfully!" -ForegroundColor Green
Write-Host "Restart required for all changes to take effect." -ForegroundColor Yellow
exit 0
