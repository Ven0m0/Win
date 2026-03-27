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

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$script:CurrentSetupStep = 'initialization'

function Set-SetupStep {
  param(
    [Parameter(Mandatory)]
    [string]$Name
  )

  $script:CurrentSetupStep = $Name
}

function Invoke-NativeCommand {
  param(
    [Parameter(Mandatory)]
    [string]$FilePath,

    [string[]]$ArgumentList = @(),

    [Parameter(Mandatory)]
    [string]$Action,

    [int[]]$AllowedExitCodes = @(0)
  )

  & $FilePath @ArgumentList 2>&1 | Out-Null
  if ($LASTEXITCODE -notin $AllowedExitCodes) {
    throw "$Action failed with exit code $LASTEXITCODE."
  }
}

function Set-RegistryValueChecked {
  param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter(Mandatory)]
    [string]$Type,

    [Parameter(Mandatory)]
    [string]$Data
  )

  Set-RegistryValue -Path $Path -Name $Name -Type $Type -Data $Data
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to set registry value '$Name' at '$Path'."
  }
}

function Remove-RegistryValueChecked {
  param(
    [Parameter(Mandatory)]
    [string]$Path,

    [string]$Name,

    [switch]$IgnoreMissing
  )

  Remove-RegistryValue -Path $Path -Name $Name
  if ($LASTEXITCODE -ne 0) {
    if ($IgnoreMissing -and $LASTEXITCODE -eq 1) {
      return
    }

    if ($Name) {
      throw "Failed to remove registry value '$Name' at '$Path'."
    }

    throw "Failed to remove registry key '$Path'."
  }
}

function Invoke-Winget {
  param(
    [Parameter(Mandatory)]
    [string[]]$ArgumentList,

    [Parameter(Mandatory)]
    [string]$Action
  )

  Invoke-NativeCommand -FilePath 'winget' -ArgumentList $ArgumentList -Action $Action
}

function Get-ActivePhysicalAdapterAlias {
  try {
    return @(Get-NetAdapter -Physical -ErrorAction Stop |
      Where-Object { $_.Status -eq 'Up' } |
      Select-Object -ExpandProperty Name -Unique)
  } catch {
    Write-Host "  Unable to enumerate physical adapters: $($_.Exception.Message)" -ForegroundColor Yellow
    return @()
  }
}

function Set-DnsServersForActiveAdapters {
  param(
    [Parameter(Mandatory)]
    [string[]]$ServerAddresses
  )

  $adapterAliases = Get-ActivePhysicalAdapterAlias
  if (-not $adapterAliases.Count) {
    Write-Host "  No active physical adapters found; skipping DNS configuration." -ForegroundColor Yellow
    return
  }

  foreach ($adapterAlias in $adapterAliases) {
    try {
      Set-DnsClientServerAddress -InterfaceAlias $adapterAlias -ServerAddresses $ServerAddresses -ErrorAction Stop
      Write-Host "  Applied DNS servers to $adapterAlias" -ForegroundColor Green
    } catch {
      Write-Host "  Skipping DNS configuration for ${adapterAlias}: $($_.Exception.Message)" -ForegroundColor Yellow
    }
  }
}

try {
  Invoke-NativeCommand -FilePath 'reg' -ArgumentList @('add', 'HKCU\CONSOLE', '/v', 'VirtualTerminalLevel', '/t', 'REG_DWORD', '/d', '1', '/f') -Action 'Enable virtual terminal support'
  Set-Location -Path $env:USERPROFILE -ErrorAction Stop

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Windows Setup & Configuration Script" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================
# SYSTEM CONFIGURATION - Registry Tweaks
# ============================================
Set-SetupStep -Name 'system configuration'
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
  Set-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name $setting.Name -Type 'REG_DWORD' -Data ([string]$setting.Value)
}
Set-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState' -Name 'FullPath' -Type 'REG_DWORD' -Data '1'
Set-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' -Name 'StartupDelayInMSec' -Type 'REG_DWORD' -Data '0'
Set-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Type 'REG_DWORD' -Data '2'

# Dark Mode
Set-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme' -Type 'REG_DWORD' -Data '0'
Set-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'SystemUsesLightTheme' -Type 'REG_DWORD' -Data '0'
Set-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'EnableTransparency' -Type 'REG_DWORD' -Data '0'

# Classic Right-Click Menu (Win11)
Invoke-NativeCommand -FilePath 'reg' -ArgumentList @('add', 'HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32', '/ve', '/f') -Action 'Enable classic context menu'

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
    Set-RegistryValueChecked -Path $key.Name -Name $value.Name -Type 'REG_DWORD' -Data ([string]$value.Value)
  }
}

# OneDrive Removal
Set-RegistryValueChecked -Path 'HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive' -Name 'DisableFileSyncNGSC' -Type 'REG_DWORD' -Data '1'
Remove-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDrive' -IgnoreMissing

# Gaming Optimizations
Set-RegistryValueChecked -Path 'HKCU\System\GameConfigStore' -Name 'GameDVR_Enabled' -Type 'REG_DWORD' -Data '0'
Set-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR' -Name 'AppCaptureEnabled' -Type 'REG_DWORD' -Data '0'
Set-RegistryValueChecked -Path 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' -Name 'HwSchMode' -Type 'REG_DWORD' -Data '2'

# Mouse Settings - Disable Acceleration
Set-RegistryValueChecked -Path 'HKCU\Control Panel\Mouse' -Name 'MouseSpeed' -Type 'REG_SZ' -Data '0'
Set-RegistryValueChecked -Path 'HKCU\Control Panel\Mouse' -Name 'MouseThreshold1' -Type 'REG_SZ' -Data '0'
Set-RegistryValueChecked -Path 'HKCU\Control Panel\Mouse' -Name 'MouseThreshold2' -Type 'REG_SZ' -Data '0'

# Disable Sticky/Filter/Toggle Keys
Set-RegistryValueChecked -Path 'HKCU\Control Panel\Accessibility\StickyKeys' -Name 'Flags' -Type 'REG_SZ' -Data '506'
Set-RegistryValueChecked -Path 'HKCU\Control Panel\Accessibility\Keyboard Response' -Name 'Flags' -Type 'REG_SZ' -Data '122'
Set-RegistryValueChecked -Path 'HKCU\Control Panel\Accessibility\ToggleKeys' -Name 'Flags' -Type 'REG_SZ' -Data '58'

# Network Optimizations - Reduce Latency
Set-RegistryValueChecked -Path 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'NetworkThrottlingIndex' -Type 'REG_DWORD' -Data '4294967295'
Set-RegistryValueChecked -Path 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' -Name 'SystemResponsiveness' -Type 'REG_DWORD' -Data '0'
Set-RegistryValueChecked -Path 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -Name 'TcpAckFrequency' -Type 'REG_DWORD' -Data '1'
Set-RegistryValueChecked -Path 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -Name 'TCPNoDelay' -Type 'REG_DWORD' -Data '1'

# Windows Update Settings
Set-RegistryValueChecked -Path 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' -Name 'NoAutoRebootWithLoggedOnUsers' -Type 'REG_DWORD' -Data '1'

# Compression Settings
Set-RegistryValueChecked -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\SideBySide\Configuration' -Name 'DisableResetbase' -Type 'REG_DWORD' -Data '0'
Set-RegistryValueChecked -Path 'HKLM\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'NtfsDisableCompression' -Type 'REG_DWORD' -Data '0'
Set-RegistryValueChecked -Path 'HKLM\SYSTEM\CurrentControlSet\Policies' -Name 'NtfsDisableCompression' -Type 'REG_DWORD' -Data '0'

# ============================================
# POWER MANAGEMENT
# ============================================
Set-SetupStep -Name 'power management'
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
Set-SetupStep -Name 'service management'
Write-Host "[3/12] Disabling unnecessary services..." -ForegroundColor Cyan
$servicesToDisable = @('SysMain', 'NvTelemetryContainer', 'icssvc', 'Fax')
foreach ($service in $servicesToDisable) {
  $serviceObject = Get-Service -Name $service -ErrorAction Stop
  Set-Service -Name $serviceObject.Name -StartupType Disabled -ErrorAction Stop
  if ($serviceObject.Status -ne 'Stopped') {
    Stop-Service -Name $serviceObject.Name -Force -ErrorAction Stop
  }
}

# ============================================
# DNS CONFIGURATION
# ============================================
Set-SetupStep -Name 'dns configuration'
Write-Host "[4/12] Configuring DNS..." -ForegroundColor Cyan
Set-DnsServersForActiveAdapters -ServerAddresses @('1.1.1.1', '1.0.0.1')

# ============================================
# BLOATWARE REMOVAL
# ============================================
Set-SetupStep -Name 'bloatware removal'
Write-Host "[5/12] Removing bloatware..." -ForegroundColor Cyan
Invoke-NativeCommand -FilePath 'taskkill' -ArgumentList @('/f', '/im', 'OneDrive.exe') -Action 'Stop OneDrive' -AllowedExitCodes @(0, 128, 255)
Invoke-NativeCommand -FilePath "$env:SystemRoot\System32\OneDriveSetup.exe" -ArgumentList @('/uninstall') -Action 'Uninstall OneDrive (System32)'
if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") {
  Invoke-NativeCommand -FilePath "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" -ArgumentList @('/uninstall') -Action 'Uninstall OneDrive (SysWOW64)'
}

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
  Remove-AppxPackageSafe -AppName $app
}

# ============================================
# SOFTWARE INSTALLATION
# ============================================
Set-SetupStep -Name 'package upgrades'
Write-Host "[6/12] Updating existing packages..." -ForegroundColor Cyan
Invoke-Winget -ArgumentList @('upgrade', '-r', '-u', '-h', '--accept-package-agreements', '--accept-source-agreements', '--force', '--purge', '--disable-interactivity', '--nowarn', '--no-proxy', '--include-unknown') -Action 'Upgrade installed winget packages'

Set-SetupStep -Name 'runtime installation'
Write-Host "[7/12] Installing runtimes..." -ForegroundColor Cyan
$runtimes = @(
  'Microsoft.VCRedist.2015+.x64', 'Microsoft.VCRedist.2013.x64',
  'Microsoft.DotNet.DesktopRuntime.9', 'Microsoft.DotNet.DesktopRuntime.8', 'Microsoft.DotNet.DesktopRuntime.7',
  'Microsoft.DotNet.Runtime.6', 'Microsoft.DotNet.Framework.DeveloperPack_4',
  'Microsoft.DirectX', 'KhronosGroup.VulkanRT', 'KhronosGroup.VulkanSDK', 'Microsoft.XNARedist',
  'Oracle.JavaRuntimeEnvironment', 'EclipseAdoptium.Temurin.21.JRE', 'EclipseAdoptium.Temurin.25.JRE',
  'OpenAL.OpenAL'
)
foreach ($pkg in $runtimes) {
  Invoke-Winget -ArgumentList @('install', "--id=$pkg", '-e', '-h') -Action "Install runtime package '$pkg'"
}

Set-SetupStep -Name 'toolchain installation'
Write-Host "[8/12] Installing toolchains..." -ForegroundColor Cyan
$toolchains = @(
  'MartinStorsjo.LLVM-MinGW.UCRT', 'Rustlang.Rust.MSVC', 'astral-sh.uv', 'Oven-sh.Bun',
  'oxc-project.oxlint', 'BiomeJS.Biome', 'koalaman.shellcheck', 'ast-grep.ast-grep', 'SQLite.SQLite'
)
foreach ($pkg in $toolchains) {
  Invoke-Winget -ArgumentList @('install', "--id=$pkg", '-e', '-h') -Action "Install toolchain package '$pkg'"
}
if (Get-Command uv -ErrorAction SilentlyContinue) { uv python install 2>&1 | Out-Null }

Set-SetupStep -Name 'development tool installation'
Write-Host "[9/12] Installing development tools..." -ForegroundColor Cyan
$devTools = @(
  'Git.Git', 'GitHub.cli', 'evilmartians.lefthook', 'Notepad++.Notepad++', 'VSCodium.VSCodium',
  'Microsoft.PowerShell', 'Microsoft.WindowsTerminal', 'CodeSector.TeraCopy', 'Microsoft.VisualStudioCode',
  'MathiasCodes.Winstow', 'OpenJS.NodeJS', 'PuTTY.PuTTY', 'Eugeny.Terminus'
)
foreach ($pkg in $devTools) {
  Invoke-Winget -ArgumentList @('install', "--id=$pkg", '-e', '-h') -Action "Install development tool '$pkg'"
}

Set-SetupStep -Name 'cli tool installation'
Write-Host "[10/12] Installing CLI tools..." -ForegroundColor Cyan
$cliTools = @(
  'eza-community.eza', 'BurntSushi.ripgrep.MSVC', 'Genivia.ugrep', 'sharkdp.fd',
  'sharkdp.bat', 'dandavison.delta', 'Starship.Starship', 'JanDeDobbeleer.OhMyPosh'
)
foreach ($pkg in $cliTools) {
  Invoke-Winget -ArgumentList @('install', "--id=$pkg", '-e', '-h') -Action "Install CLI tool '$pkg'"
}

Set-SetupStep -Name 'application installation'
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
foreach ($pkg in $applications) {
  Invoke-Winget -ArgumentList @('install', "--id=$pkg", '-e', '-h') -Action "Install application '$pkg'"
}

Invoke-Winget -ArgumentList @('install', 'FFmpeg (Essentials Build)', '-h') -Action 'Install FFmpeg (Essentials Build)'
Invoke-Winget -ArgumentList @('install', 'CodeF0x.ffzap', '-h') -Action 'Install ffzap'
Invoke-Winget -ArgumentList @('install', 'PaulPacifico.ShutterEncoder', '-h') -Action 'Install Shutter Encoder'
Invoke-Winget -ArgumentList @('install', 'Microsoft.Edit', '-h') -Action 'Install Microsoft Edit'
Invoke-Winget -ArgumentList @('install', 'yadm', '-h') -Action 'Install yadm'

# GMK Driver
Invoke-RestMethod https://offset-power.net/GMKDriver/setup.exe -OutFile "$env:TEMP\gmk.exe"
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
Invoke-RestMethod https://get.scoop.sh -OutFile "$env:TEMP\install.ps1"
& "$env:TEMP\install.ps1" -NoProxy 2>&1 | Out-Null
if (Get-Command scoop -ErrorAction SilentlyContinue) { scoop bucket add extras 2>&1 | Out-Null }

# ============================================
# CLEANUP & MAINTENANCE
# ============================================
Set-SetupStep -Name 'cleanup and maintenance'
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
Set-SetupStep -Name 'final package upgrades'
Invoke-Winget -ArgumentList @('upgrade', '-h', '-r', '-u', '--accept-package-agreements', '--accept-source-agreements', '--include-unknown', '--force', '--purge', '--disable-interactivity') -Action 'Run final winget upgrades'
if (Get-Command scoop -ErrorAction SilentlyContinue) { scoop update --all 2>&1 | Out-Null }
if (Get-Command choco -ErrorAction SilentlyContinue) { choco upgrade all -y 2>&1 | Out-Null }
if (Get-Command pip -ErrorAction SilentlyContinue) {
  pip list --outdated --format=freeze | ForEach-Object { pip install --upgrade ($_ -split '==')[0] } 2>&1 | Out-Null
}

Write-Host "Setup completed successfully!" -ForegroundColor Green
Write-Host "Restart required for all changes to take effect." -ForegroundColor Yellow
exit 0
} catch {
  Write-Host "Setup failed during $script:CurrentSetupStep." -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  exit 1
}
