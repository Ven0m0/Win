#Requires -RunAsAdministrator
# Windows Setup Script - Comprehensive automated installation and configuration
# Combines software installation, system optimization, bloatware removal, and privacy tweaks


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

  $output = & $FilePath @ArgumentList 2>&1
  $exitCode = $LASTEXITCODE
  if ($exitCode -notin $AllowedExitCodes) {
    if ($output) {
      Write-Host (($output | Out-String).Trim()) -ForegroundColor Red
    }

    throw "$Action failed with exit code $exitCode."
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

  Invoke-NativeCommand -FilePath 'reg' `
    -ArgumentList @('add', $Path, '/v', $Name, '/t', $Type, '/d', $Data, '/f') `
    -Action "Set registry value '$Name' at '$Path'"
}

function Remove-RegistryValueChecked {
  param(
    [Parameter(Mandatory)]
    [string]$Path,

    [string]$Name,

    [switch]$IgnoreMissing
  )

  $argumentList = @('delete', $Path)
  if ($Name) {
    $argumentList += @('/v', $Name)
  }
  $argumentList += @('/f')

  $allowedExitCodes = @(0)
  if ($IgnoreMissing) {
    $allowedExitCodes += 1
  }

  if ($Name) {
    Invoke-NativeCommand -FilePath 'reg' `
    -ArgumentList $argumentList `
    -Action "Remove registry value '$Name' at '$Path'" `
    -AllowedExitCodes $allowedExitCodes
    return
  }

  Invoke-NativeCommand -FilePath 'reg' `
    -ArgumentList $argumentList `
    -Action "Remove registry key '$Path'" `
    -AllowedExitCodes $allowedExitCodes
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
    $adapterNames = Get-NetAdapter -Physical -ErrorAction Stop |
      Where-Object { $_.Status -eq 'Up' } |
      ForEach-Object { $_.Name }

    return [string[]]$adapterNames
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

function Remove-ItemBestEffort {
  param(
    [Parameter(Mandatory)]
    [string]$Path,

    [switch]$Recurse
  )

  Remove-Item -Path $Path -Force -Recurse:$Recurse -ErrorAction SilentlyContinue
}


function Start-Setup {
  if (Test-Path "$PSScriptRoot\Scripts\Common.ps1") {
    . "$PSScriptRoot\Scripts\Common.ps1"
    Request-AdminElevation
    Initialize-ConsoleUI -Title "Windows Setup Script (Administrator)"
  } else {
    if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
      IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
      Start-Process PowerShell.exe `
      -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) `
      -Verb RunAs
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









  if (-not (Get-Command Remove-AppxPackageSafe -ErrorAction SilentlyContinue)) {
    throw 'Remove-AppxPackageSafe is unavailable.' +
      ' Ensure Common.ps1 is sourced from the Scripts directory before running setup.ps1.'
  }

  try {
    Invoke-NativeCommand -FilePath 'reg' `
    -ArgumentList @('add', 'HKCU\CONSOLE', '/v', 'VirtualTerminalLevel', '/t', 'REG_DWORD', '/d', '1', '/f') `
    -Action 'Enable virtual terminal support'
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
    Set-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' `
    -Name $setting.Name `
    -Type 'REG_DWORD' `
    -Data ([string]$setting.Value)
  }
  Set-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState' `
    -Name 'FullPath' `
    -Type 'REG_DWORD' `
    -Data '1'
  Set-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize' `
    -Name 'StartupDelayInMSec' `
    -Type 'REG_DWORD' `
    -Data '0'
  Set-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' `
    -Name 'VisualFXSetting' `
    -Type 'REG_DWORD' `
    -Data '2'

  # Dark Mode
  Set-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
    -Name 'AppsUseLightTheme' `
    -Type 'REG_DWORD' `
    -Data '0'
  Set-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
    -Name 'SystemUsesLightTheme' `
    -Type 'REG_DWORD' `
    -Data '0'
  Set-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
    -Name 'EnableTransparency' `
    -Type 'REG_DWORD' `
    -Data '0'

  # Classic Right-Click Menu (Win11)
  Invoke-NativeCommand -FilePath 'reg' `
    -ArgumentList @('add', 'HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32', '/ve', `
    '/f') `
    -Action 'Enable classic context menu'

  # Privacy & Telemetry
  $privacySettings = @{
    'HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection' = @{'AllowTelemetry' = 0}
    'HKLM\SOFTWARE\Policies\Microsoft\Windows\System' = @{'PublishUserActivities' = 0; `
      'UploadUserActivities' = 0; 'EnableActivityFeed' = 0}
    'HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' = @{'DisableLocation' = 1}
    'HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' = @{'Enabled' = 0}
    'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search' = @{'AllowCortana' = 0}
    'HKCU\Software\Microsoft\Siuf\Rules' = @{'NumberOfSIUFInPeriod' = 0}
    'HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy' = @{'TailoredExperiencesWithDiagnosticDataEnabled' = 0}
    'HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager' = @{'SubscribedContent-338388Enabled' = 0; `
      'SoftLandingEnabled' = 0}
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
  Set-RegistryValueChecked -Path 'HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive' `
    -Name 'DisableFileSyncNGSC' `
    -Type 'REG_DWORD' `
    -Data '1'
  Remove-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'OneDrive' -IgnoreMissing

  # Gaming Optimizations
  Set-RegistryValueChecked -Path 'HKCU\System\GameConfigStore' -Name 'GameDVR_Enabled' -Type 'REG_DWORD' -Data '0'
  Set-RegistryValueChecked -Path 'HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR' `
    -Name 'AppCaptureEnabled' `
    -Type 'REG_DWORD' `
    -Data '0'
  Set-RegistryValueChecked -Path 'HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' `
    -Name 'HwSchMode' `
    -Type 'REG_DWORD' `
    -Data '2'

  # Mouse Settings - Disable Acceleration
  Set-RegistryValueChecked -Path 'HKCU\Control Panel\Mouse' -Name 'MouseSpeed' -Type 'REG_SZ' -Data '0'
  Set-RegistryValueChecked -Path 'HKCU\Control Panel\Mouse' -Name 'MouseThreshold1' -Type 'REG_SZ' -Data '0'
  Set-RegistryValueChecked -Path 'HKCU\Control Panel\Mouse' -Name 'MouseThreshold2' -Type 'REG_SZ' -Data '0'

  # Disable Sticky/Filter/Toggle Keys
  Set-RegistryValueChecked -Path 'HKCU\Control Panel\Accessibility\StickyKeys' -Name 'Flags' -Type 'REG_SZ' -Data '506'
  Set-RegistryValueChecked -Path 'HKCU\Control Panel\Accessibility\Keyboard Response' `
    -Name 'Flags' `
    -Type 'REG_SZ' `
    -Data '122'
  Set-RegistryValueChecked -Path 'HKCU\Control Panel\Accessibility\ToggleKeys' -Name 'Flags' -Type 'REG_SZ' -Data '58'

  # Network Optimizations - Reduce Latency
  Set-RegistryValueChecked -Path 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' `
    -Name 'NetworkThrottlingIndex' `
    -Type 'REG_DWORD' `
    -Data '4294967295'
  Set-RegistryValueChecked -Path 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile' `
    -Name 'SystemResponsiveness' `
    -Type 'REG_DWORD' `
    -Data '0'
  Set-RegistryValueChecked -Path 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' `
    -Name 'TcpAckFrequency' `
    -Type 'REG_DWORD' `
    -Data '1'
  Set-RegistryValueChecked -Path 'HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' `
    -Name 'TCPNoDelay' `
    -Type 'REG_DWORD' `
    -Data '1'

  # Windows Update Settings
  Set-RegistryValueChecked -Path 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU' `
    -Name 'NoAutoRebootWithLoggedOnUsers' `
    -Type 'REG_DWORD' `
    -Data '1'

  # Compression Settings
  Set-RegistryValueChecked -Path 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\SideBySide\Configuration' `
    -Name 'DisableResetbase' `
    -Type 'REG_DWORD' `
    -Data '0'
  Set-RegistryValueChecked -Path 'HKLM\SYSTEM\CurrentControlSet\Control\FileSystem' `
    -Name 'NtfsDisableCompression' `
    -Type 'REG_DWORD' `
    -Data '0'
  Set-RegistryValueChecked -Path 'HKLM\SYSTEM\CurrentControlSet\Policies' `
    -Name 'NtfsDisableCompression' `
    -Type 'REG_DWORD' `
    -Data '0'

  # ============================================
  # POWER MANAGEMENT
  # ============================================
  Set-SetupStep -Name 'power management'
  Write-Host "[2/12] Configuring power settings..." -ForegroundColor Cyan
  Invoke-NativeCommand -FilePath 'powercfg' -ArgumentList @('-h', 'off') -Action 'Disable hibernation'
  Invoke-NativeCommand -FilePath 'powercfg' `
    -ArgumentList @('-duplicatescheme', 'e9a42b02-d5df-448d-aa00-03f14749eb61') `
    -Action 'Duplicate ultimate performance plan'
  Invoke-NativeCommand -FilePath 'powercfg' `
    -ArgumentList @('/S', 'e9a42b02-d5df-448d-aa00-03f14749eb61') `
    -Action 'Select ultimate performance plan'
  Invoke-NativeCommand -FilePath 'powercfg' `
    -ArgumentList @('-setacvalueindex', 'SCHEME_CURRENT', 'SUB_PROCESSOR', 'PROCTHROTTLEMIN', '100') `
    -Action 'Set minimum processor state'
  Invoke-NativeCommand -FilePath 'powercfg' `
    -ArgumentList @('-setactive', 'SCHEME_CURRENT') `
    -Action 'Activate current power scheme'
  Invoke-NativeCommand -FilePath 'fsutil' `
    -ArgumentList @('behavior', 'set', 'disablecompression', '0') `
    -Action 'Enable NTFS compression behavior'

  # ============================================
  # SERVICE MANAGEMENT
  # ============================================
  Set-SetupStep -Name 'service management'
  Write-Host "[3/12] Disabling unnecessary services..." -ForegroundColor Cyan
  $servicesToDisable = @('SysMain', 'NvTelemetryContainer', 'icssvc', 'Fax')
  foreach ($service in $servicesToDisable) {
    try {
      $serviceObject = Get-Service -Name $service -ErrorAction Stop
    } catch [Microsoft.PowerShell.Commands.ServiceCommandException] {
      Write-Host "  Service $service not found; skipping" -ForegroundColor Yellow
      continue
    }

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
  try {
    $oneDriveProcess = Get-Process -Name 'OneDrive' -ErrorAction Stop
  } catch [Microsoft.PowerShell.Commands.ProcessCommandException] {
    $oneDriveProcess = $null
  }

  if ($oneDriveProcess) {
    Invoke-NativeCommand -FilePath 'taskkill' -ArgumentList @('/f', '/im', 'OneDrive.exe') -Action 'Stop OneDrive'
  } else {
    Write-Host "  OneDrive is not running; skipping process stop" -ForegroundColor Yellow
  }
  Invoke-NativeCommand -FilePath "$env:SystemRoot\System32\OneDriveSetup.exe" `
    -ArgumentList @('/uninstall') `
    -Action 'Uninstall OneDrive (System32)'
  if (Test-Path "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") {
    Invoke-NativeCommand -FilePath "$env:SystemRoot\SysWOW64\OneDriveSetup.exe" `
    -ArgumentList @('/uninstall') `
    -Action 'Uninstall OneDrive (SysWOW64)'
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
  Invoke-Winget `
    -ArgumentList @('upgrade', '-r', '-u', '-h', '--accept-package-agreements', `
      '--accept-source-agreements', '--force', '--purge', `
      '--disable-interactivity', '--nowarn', '--no-proxy', '--include-unknown') `
    -Action 'Upgrade installed winget packages'

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
  if (Get-Command uv -ErrorAction SilentlyContinue) {
    Invoke-NativeCommand -FilePath 'uv' `
    -ArgumentList @('python', 'install') `
    -Action 'Install uv-managed Python runtimes'
  }

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

  Invoke-Winget `
    -ArgumentList @('install', 'FFmpeg (Essentials Build)', '-h') `
    -Action 'Install FFmpeg (Essentials Build)'
  Invoke-Winget -ArgumentList @('install', 'CodeF0x.ffzap', '-h') -Action 'Install ffzap'
  Invoke-Winget -ArgumentList @('install', 'PaulPacifico.ShutterEncoder', '-h') -Action 'Install Shutter Encoder'
  Invoke-Winget -ArgumentList @('install', 'Microsoft.Edit', '-h') -Action 'Install Microsoft Edit'

  # GMK Driver
  Invoke-RestMethod https://offset-power.net/GMKDriver/setup.exe -OutFile "$env:TEMP\gmk.exe"
  Invoke-NativeCommand -FilePath "$env:TEMP\gmk.exe" -Action 'Run GMK driver installer'

  # HEVC/HEIF Extensions
  Get-AppXPackage -AllUsers *Microsoft.HEVCVideoExtension* | ForEach-Object {
    try {
      Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction Stop
    } catch {
      Write-Host "  Skipping HEVC extension registration: $($_.Exception.Message)" -ForegroundColor Yellow
    }
  }
  Get-AppXPackage -AllUsers *Microsoft.HEIFImageExtension* | ForEach-Object {
    try {
      Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml" -ErrorAction Stop
    } catch {
      Write-Host "  Skipping HEIF extension registration: $($_.Exception.Message)" -ForegroundColor Yellow
    }
  }

  # Scoop
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
  $hadScoop = [bool](Get-Command scoop -ErrorAction SilentlyContinue)
  Invoke-RestMethod https://get.scoop.sh -OutFile "$env:TEMP\install.ps1"
  & "$env:TEMP\install.ps1" -NoProxy
  if (-not $hadScoop -and -not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    throw 'Scoop installation failed.'
  }
  Invoke-NativeCommand -FilePath 'scoop' -ArgumentList @('bucket', 'add', 'extras') -Action 'Add Scoop extras bucket'

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
  foreach ($file in $firefoxFiles) { Remove-ItemBestEffort -Path $file }

  # Event Logs
  Invoke-NativeCommand -FilePath 'wevtutil.exe' `
    -ArgumentList @('cl', 'Application') `
    -Action 'Clear Application event log'
  Invoke-NativeCommand -FilePath 'wevtutil.exe' -ArgumentList @('cl', 'System') -Action 'Clear System event log'

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
  foreach ($path in $tempPaths) { Remove-ItemBestEffort -Path $path -Recurse }

  # NVIDIA Cleanup
  $nvidiaPaths = @(
    "$env:ProgramFiles\Nvidia Corporation\Installer2", "$env:ProgramFiles\NVIDIA Corporation\Installer",
    "${env:ProgramFiles(x86)}\NVIDIA Corporation\Installer", "${env:ProgramFiles(x86)}\NVIDIA Corporation\Installer2",
    "$env:ProgramData\NVIDIA Corporation\Downloader", "$env:ProgramData\NVIDIA\Downloader",
    "$env:ALLUSERSPROFILE\NVIDIA Corporation\NetService\*.exe"
  )
  foreach ($path in $nvidiaPaths) { Remove-ItemBestEffort -Path $path -Recurse }

  # System Cleanup
  $systemPaths = @(
    "$env:SystemDrive\MSOCache", "$env:SystemDrive\i386", "$env:SystemDrive\RECYCLER",
    "$env:SystemDrive\`$Recycle.Bin", "$env:ALLUSERSPROFILE\Microsoft\Windows\WER\ReportArchive",
    "$env:ALLUSERSPROFILE\Microsoft\Windows\WER\ReportQueue",
    "$env:ALLUSERSPROFILE\Microsoft\Windows Defender\Scans\History\Results\Quick",
    "$env:ALLUSERSPROFILE\Microsoft\Windows Defender\Scans\History\Results\Resource",
    "$env:ALLUSERSPROFILE\Microsoft\Search\Data\Temp", "$env:WINDIR\Web\Wallpaper\Dell"
  )
  foreach ($path in $systemPaths) { Remove-ItemBestEffort -Path $path -Recurse }

  # OneDrive Cleanup
  $ODrive = "$env:USERPROFILE\OneDrive"
  if (Test-Path $ODrive) {
    $oneDrivePatterns = @("*.bak", "*LOG", "*.old", "*.trace", "*.tmp")
    foreach ($pattern in $oneDrivePatterns) { Remove-ItemBestEffort -Path "$ODrive\$pattern" -Recurse }
    $scalingFactors = @("chrome_200_percent.pak", "chrome_300_percent.pak", "chrome_400_percent.pak")
    foreach ($factor in $scalingFactors) {
      Get-ChildItem -Path $ODrive -Filter $factor -Recurse -ErrorAction SilentlyContinue `
    | Remove-Item -Force -ErrorAction SilentlyContinue
    }
  }

  # Root Drive Cleanup
  $extensions = @('bat', 'cmd', 'txt', 'log', 'jpg', 'jpeg', 'tmp', 'temp', 'bak', 'backup', 'exe')
  foreach ($ext in $extensions) { Remove-ItemBestEffort -Path "$env:SystemDrive\*.$ext" }

  # Windows Files
  $winFiles = @('*.log', '*.txt', '*.bmp', '*.tmp')
  foreach ($pattern in $winFiles) { Remove-ItemBestEffort -Path "$env:WINDIR\$pattern" }

  # Registry Cleanup
  Remove-RegistryValueChecked -Path 'HKCU\SOFTWARE\Classes\Local Settings\Muicache' -IgnoreMissing

  # Disk Operations
  Invoke-NativeCommand -FilePath 'cleanmgr.exe' -ArgumentList @('/sagerun:65535') -Action 'Run Disk Cleanup'
  if (Get-Command msizap -ErrorAction SilentlyContinue) { Invoke-NativeCommand -FilePath 'msizap' `
    -ArgumentList @('G!') `
    -Action 'Run MSI cleanup' }

  # System Maintenance
  Invoke-NativeCommand -FilePath 'DISM' `
    -ArgumentList @('/Online', '/Cleanup-Image', '/RestoreHealth', '/Quiet') `
    -Action 'Restore Windows image health'
  Invoke-NativeCommand -FilePath 'DISM' -ArgumentList @('/Cleanup-Mountpoints') -Action 'Clean DISM mount points'
  Invoke-NativeCommand -FilePath 'DISM' -ArgumentList @('/CleanUp-Wim') -Action 'Clean WIM resources'
  Invoke-NativeCommand -FilePath 'DISM' `
    -ArgumentList @('/Online', '/Cleanup-Image', '/StartComponentCleanup', '/ResetBase') `
    -Action 'Start component cleanup'
  Invoke-NativeCommand -FilePath 'sfc' -ArgumentList @('/scannow') -Action 'Run System File Checker'
  Invoke-NativeCommand -FilePath 'ipconfig' -ArgumentList @('/release') -Action 'Release IP configuration'
  Invoke-NativeCommand -FilePath 'ipconfig' -ArgumentList @('/renew') -Action 'Renew IP configuration'
  Invoke-NativeCommand -FilePath 'ipconfig' -ArgumentList @('/flushdns') -Action 'Flush DNS cache'
  Invoke-NativeCommand -FilePath 'netsh' -ArgumentList @('winsock', 'reset') -Action 'Reset Winsock'
  Invoke-NativeCommand -FilePath 'netsh' -ArgumentList @('int', 'ip', 'reset') -Action 'Reset TCP/IP stack'
  Invoke-NativeCommand -FilePath 'chkdsk' -ArgumentList @('/scan') -Action 'Run disk scan'

  # Final Updates
  Set-SetupStep -Name 'final package upgrades'
  Invoke-Winget `
    -ArgumentList @('upgrade', '-h', '-r', '-u', '--accept-package-agreements', `
      '--accept-source-agreements', '--include-unknown', '--force', '--purge', '--disable-interactivity') `
    -Action 'Run final winget upgrades'
  if (Get-Command scoop -ErrorAction SilentlyContinue) { Invoke-NativeCommand -FilePath 'scoop' `
    -ArgumentList @('update', '--all') `
    -Action 'Update Scoop packages' }
  if (Get-Command choco -ErrorAction SilentlyContinue) { Invoke-NativeCommand -FilePath 'choco' `
    -ArgumentList @('upgrade', 'all', '-y') `
    -Action 'Update Chocolatey packages' }
  if (Get-Command pip -ErrorAction SilentlyContinue) {
    $outdatedPackages = & pip list --outdated --format=freeze 2>&1
    $pipListExitCode = $LASTEXITCODE
    if ($pipListExitCode -ne 0) {
      Write-Host "  Skipping pip upgrades: unable to list outdated packages." -ForegroundColor Yellow
    } else {
      foreach ($package in $outdatedPackages) {
        $packageName = ($package -split '==')[0]
        if ($packageName) {
          Invoke-NativeCommand -FilePath 'pip' `
    -ArgumentList @('install', '--upgrade', $packageName) `
    -Action "Upgrade pip package '$packageName'"
        }
      }
    }
  }

  Write-Host "Setup completed successfully!" -ForegroundColor Green
  Write-Host "Restart required for all changes to take effect." -ForegroundColor Yellow
  exit 0
  } catch {
    Write-Host "Setup failed during $script:CurrentSetupStep." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
  }

}

if ($MyInvocation.InvocationName -ne '.') {
  Start-Setup
  exit $LASTEXITCODE
}
