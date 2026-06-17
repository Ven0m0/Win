#Requires -Version 5.1

<#
.SYNOPSIS
  Initialize custom PowerShell + tooling environment (Scoop, Winget, Choco, apps, custom downloads).
.NOTES
  Requires Windows, PowerShell 5+; will elevate for certain steps.
  ExecutionPolicy for CurrentUser will be set to RemoteSigned on first run.

  DEPRECATED package lists: the inline Winget/Scoop/Choco arrays below duplicate
  and drift from the canonical catalog in Scripts/packages.psd1. Prefer
  Scripts/Install-Packages.ps1 (which reads packages.psd1). This script is still
  referenced by Setup-Win11.ps1 only as a winget-bootstrap fallback; its bulk
  package install is slated for removal.
#>
[CmdletBinding()]
param(
  [switch]$HomeWorkstation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$VerbosePreference = 'Continue'

. "$PSScriptRoot\Common.ps1"

function Invoke-Elevated {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)] [string]$FilePath,
    [Parameter()] [string[]]$ArgumentList = @(),
    [switch]$Hidden,
    [switch]$NoWait
  )
  $psi = @{
    FilePath     = $FilePath
    ArgumentList = $ArgumentList
    Verb         = 'RunAs'
  }
  if ($Hidden) { $psi.WindowStyle = 'Hidden' }
  $proc = Start-Process @psi -PassThru
  if (-not $NoWait) {
    $proc.WaitForExit()
    if ($proc.ExitCode -ne 0) { throw "Command failed: $FilePath $ArgumentList (exit $($proc.ExitCode))" }
  }
}

function Install-ScoopApp {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Package)
  Write-Verbose "Preparing to install $Package"
  if (-not (scoop info $Package).Installed) {
    Write-Verbose "Installing $Package"
    scoop install $Package
  } else {
    Write-Verbose "Package $Package already installed; skipping."
  }
}



function Install-ChocoApp {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Package)
  Write-Verbose "Preparing to install $Package"
  $listApp = choco list --local $Package
  if ($listApp -like "0 packages installed.") {
    Write-Verbose "Installing $Package"
    Invoke-Elevated -FilePath "PowerShell" -ArgumentList "choco","install","$Package","-y"
  } else {
    Write-Verbose "Package $Package already installed; skipping."
  }
}

function Expand-Download {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Folder,
    [Parameter(Mandatory)][string]$File
  )
  if (-not (Test-Path -LiteralPath $Folder -PathType Container)) { throw "$Folder does not exist." }
  if (Test-Path -LiteralPath $File -PathType Leaf) {
    $ext = ($File.Split(".") | Select-Object -Last 1).ToLowerInvariant()
    switch ($ext) {
      "rar" {
        $null = Start-Process -FilePath "UnRar.exe" -ArgumentList "x", "-op'$Folder'", "-y", "$File" `
          -WorkingDirectory "$Env:ProgramFiles\WinRAR\" -Wait
      }
      "zip" { $null = & 7z x -o"$Folder" -y "$File" }
      "7z"  { $null = & 7z x -o"$Folder" -y "$File" }
      "exe" { $null = & 7z x -o"$Folder" -y "$File" }
      Default { throw "No extractor for $File" }
    }
  }
}

function Get-CustomApp {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Link,
    [Parameter(Mandatory)][string]$Folder
  )
  $headers = curl.exe -sIL "$Link"
  if ($headers | Select-String -Pattern "Content-Disposition") {
    $Package = (($headers | Select-String -Pattern "filename=").Line -split "=")[-1].Trim('"').Trim()
  } else {
    $Package = $Link.Split("/") | Select-Object -Last 1
  }
  Write-Verbose "Downloading $Package"
  aria2c --quiet --dir="$Folder" "$Link"
  return $Package
}

function Install-CustomApp {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$URL,
    [string]$Folder
  )
  $Package = Get-CustomApp -Link $URL -Folder "$Env:UserProfile\Downloads\"
  $downloadPath = Join-Path $Env:UserProfile\Downloads $Package
  if (Test-Path -LiteralPath $downloadPath -PathType Leaf) {
    if ($PSBoundParameters.ContainsKey('Folder')) {
      $target = Join-Path "$Env:UserProfile\bin" $Folder
      if (-not (Test-Path -LiteralPath $target)) { $null = New-Item -Path $target -ItemType Directory }
      Expand-Download -Folder $target -File $downloadPath
    } else {
      Expand-Download -Folder "$Env:UserProfile\bin\" -File $downloadPath
    }
    Remove-Item -LiteralPath $downloadPath -Force
  }
}

function Install-CustomPackage {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$URL)
  $Package = Get-CustomApp -Link $URL -Folder "$Env:UserProfile\Downloads\"
  $downloadPath = Join-Path $Env:UserProfile\Downloads $Package
  if (Test-Path -LiteralPath $downloadPath -PathType Leaf) {
    Invoke-Elevated -FilePath ".\$Package" -ArgumentList "/S" -NoWait:$false -Hidden
    Remove-Item -LiteralPath $downloadPath -Force
  }
}

function Enable-Bucket {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Bucket)
  if (-not ((scoop bucket list).Name -eq "$Bucket")) {
    Write-Verbose "Adding bucket $Bucket"
    scoop bucket add $Bucket
  } else {
    Write-Verbose "Bucket $Bucket already added; skipping."
  }
}

function Start-MainFunction {
  [CmdletBinding(SupportsShouldProcess)]
  [OutputType([string])]
  param([switch]$HomeWorkstation)

# ExecutionPolicy: CurrentUser -> RemoteSigned
if ((Get-ExecutionPolicy -Scope CurrentUser) -notcontains "RemoteSigned") {
  Write-Verbose "Setting Execution Policy for Current User..."
  Invoke-Elevated -FilePath "PowerShell" -ArgumentList "Set-ExecutionPolicy",
    "-Scope",
    "CurrentUser",
    "-ExecutionPolicy",
    "RemoteSigned",
    "-Force"
  Write-Output "Restart/Re-Run script required."
  Start-Sleep -Seconds 10
  return
}

# Scoop
if (-not (Get-Command -Name "scoop" -CommandType Application -ErrorAction SilentlyContinue)) {
  Write-Verbose "Installing Scoop..."
  $scoopInstaller = Join-Path $Env:Temp ("install-scoop-{0}.ps1" -f [System.Guid]::NewGuid().ToString('N'))
  try {
    Invoke-RestMethod -Uri 'https://get.scoop.sh' -OutFile $scoopInstaller
    & $scoopInstaller
  } finally {
    if (Test-Path -LiteralPath $scoopInstaller) {
      Remove-Item -LiteralPath $scoopInstaller -Force
    }
  }
}

# Chocolatey
if (-not (Get-Command -Name "choco" -CommandType Application -ErrorAction SilentlyContinue)) {
Write-Verbose "Installing Chocolatey..."
@'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
$chocoInstaller = Join-Path $Env:Temp ("install-choco-{0}.ps1" -f [System.Guid]::NewGuid().ToString())
try {
  Invoke-RestMethod -Uri 'https://community.chocolatey.org/install.ps1' -OutFile $chocoInstaller
  & $chocoInstaller
}
finally {
  if (Test-Path -LiteralPath $chocoInstaller) {
    Remove-Item -LiteralPath $chocoInstaller -Force
  }
}
'@ > $Env:Temp\choco.ps1
  Invoke-Elevated -FilePath "PowerShell" -ArgumentList "$Env:Temp\choco.ps1"
  Remove-Item -LiteralPath $Env:Temp\choco.ps1 -Force
}

# WinGet
if (-not (Get-AppxPackage -Name "Microsoft.DesktopAppInstaller")) {
  Write-Verbose "Installing WinGet..."
  @'
$releases_url = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Register-PackageSource -Name Nuget -Location "https://www.nuget.org/api/v2" -ProviderName Nuget -Trusted
Install-Package Microsoft.UI.Xaml -RequiredVersion 2.7.1
$releases = Invoke-RestMethod -uri $releases_url
$latestRelease = $releases.assets | Where-Object { $_.browser_download_url.EndsWith('msixbundle') } | Select-Object -First 1
Add-AppxPackage -Path $latestRelease.browser_download_url
'@ > $Env:Temp\winget.ps1
  Invoke-Elevated -FilePath "PowerShell" -ArgumentList "$Env:Temp\winget.ps1"
  Remove-Item -LiteralPath $Env:Temp\winget.ps1 -Force
}

# OpenSSH
if ([Environment]::OSVersion.Version.Major -lt 10) {
  Install-ScoopApp -Package "openssh"
}
@'
if ((Get-WindowsCapability -Online -Name OpenSSH.Client*).State -ne "Installed") {
    Add-WindowsCapability -Online -Name OpenSSH.Client*
}
'@ > "${Env:Temp}\openssh.ps1"
Invoke-Elevated -FilePath "PowerShell" -ArgumentList "${Env:Temp}\openssh.ps1" -Hidden
Remove-Item -LiteralPath "${Env:Temp}\openssh.ps1" -Force

# Git
Invoke-Winget -Id "Git.Git"
Start-Sleep -Seconds 5
refreshenv
Start-Sleep -Seconds 5
if (-not (git config --global credential.helper) -eq "manager-core") {
  git config --global credential.helper manager-core
}
if (-not $Env:GIT_SSH) {
  Write-Verbose "Setting GIT_SSH User Environment Variable"
  [System.Environment]::SetEnvironmentVariable('GIT_SSH', (Resolve-Path (scoop which ssh)), 'USER')
}
if ((Get-Service -Name ssh-agent).Status -ne "Running") {
  Invoke-Elevated -FilePath "PowerShell" -ArgumentList "Set-Service","ssh-agent","-StartupType","Manual" -Hidden
}

# Aria2
Install-ScoopApp -Package "aria2"
if ((scoop config aria2-enabled) -ne $True) { scoop config aria2-enabled true }
if ((scoop config aria2-warning-enabled) -ne $False) { scoop config aria2-warning-enabled false }
if (-not (Get-ScheduledTaskInfo -TaskName "Aria2RPC" -ErrorAction Ignore)) {
@'
$Action = New-ScheduledTaskAction -Execute $Env:UserProfile\scoop\apps\aria2\current\aria2c.exe `
    -Argument "--enable-rpc --rpc-listen-all" `
    -WorkingDirectory $Env:UserProfile\Downloads
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Principal = New-ScheduledTaskPrincipal -UserID "$Env:ComputerName\$Env:Username" -LogonType S4U
$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "Aria2RPC" -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings
'@ > $Env:Temp\aria2.ps1
  Invoke-Elevated -FilePath "PowerShell" -ArgumentList "$Env:Temp\aria2.ps1"
  Remove-Item -LiteralPath $Env:Temp\aria2.ps1 -Force
}

# Buckets
Enable-Bucket -Bucket "extras"
Enable-Bucket -Bucket "nerd-fonts"
Enable-Bucket -Bucket "java"
Enable-Bucket -Bucket "nirsoft"
scoop bucket add foosel https://github.com/foosel/scoop-bucket

# UNIX tools / TERM
if (Get-Alias -Name curl -ErrorAction SilentlyContinue) { Remove-Item alias:curl }
if (-not $Env:TERM) {
  [System.Environment]::SetEnvironmentVariable("TERM", "xterm-256color", "USER")
}

# Home workstation prompt
if (-not $PSBoundParameters.ContainsKey("HomeWorkstation")) {
  $HomeWorkstation = $(Read-Host -Prompt "Is this a workstation for Home use (y/n)?") -eq "y"
}

if ($HomeWorkstation -and -not (Test-Path -LiteralPath $Env:UserProfile\bin)) {
  Write-Verbose "Creating bin directory in $Env:UserProfile"
  $null = New-Item -Path $Env:UserProfile\bin -ItemType Directory
}

# Scoop packages
$Scoop = @("pshazz","cacert","colortool")
foreach ($item in $Scoop) { Install-ScoopApp -Package $item }

if ($HomeWorkstation) {
  $Scoop = @("ffmpeg","lame","cdrtools","cuetools","betterjoy","schismtracker")
  foreach ($item in $Scoop) { Install-ScoopApp -Package $item }
}

# WinGet packages
$WinGet = @(
  "gerardog.gsudo",
    "Microsoft.DotNet.DesktopRuntime.3_1",
    "Microsoft.DotNet.DesktopRuntime.5",
    "Microsoft.DotNet.DesktopRuntime.6",
    "Microsoft.DotNet.DesktopRuntime.7",
  "Microsoft.WindowsTerminal",
    "Microsoft.PowerToys",
    "frippery.busybox-w32",
    "junegunn.fzf",
    "Neovim.Neovim",
    "Obsidian.Obsidian",
    "Microsoft.OpenJDK.17",
  "GoLang.Go.1.19",
    "Python.Python.3.11",
    "chrisant996.Clink",
    "PuTTY.PuTTY",
  "BleachBit.BleachBit",
    "GnuPG.GnuPG",
    "LIGHTNINGUK.ImgBurn",
    "dotPDNLLC.paintdotnet",
    "RevoUninstaller.RevoUninstaller",
  "Starship.Starship"
)
foreach ($item in $WinGet) { Invoke-Winget -Id $item }

if ($HomeWorkstation) {
  $WinGet = @(
    "Discord.Discord",
    "HandBrake.HandBrake",
    "AndreWiethoff.ExactAudioCopy",
    "clsid2.mpc-hc",
    "Plex.Plex",
    "Plex.Plexamp",
    "PointPlanck.FileBot",
    "CPUID.CPU-Z",
    "TechPowerUp.GPU-Z",
    "VideoLAN.VLC",
    "Mp3tag.Mp3tag",
    "MusicBee.MusicBee",
    "OBSProject.OBSStudio",
    "yt-dlp.yt-dlp",
    "MediaArea.MediaInfo",
    "MediaArea.MediaInfo.GUI",
    "MoritzBunkus.MKVToolNix",
    "Ocenaudio.Ocenaudio",
    "OpenMPT.OpenMPT",
    "Romcenter.Romcenter",
    "Valve.Steam"
  )
  foreach ($item in $WinGet) { Invoke-Winget -Id $item }
}

# VSCodium custom install
winget install VSCodium.VSCodium `
    --override '/SILENT /mergetasks="!runcode,addcontextmenufiles,addcontextmenufolders"'
if ($LASTEXITCODE -notin @(0, -1978335189)) {
    throw "VSCodium install failed with exit code $LASTEXITCODE"
}

# Choco packages
$Choco = @("syspin","sd-card-formatter","winimage","winsetupfromusb","fluidsynth")
foreach ($item in $Choco) { Install-ChocoApp -Package $item }

# Steam apps (if home)
if ($HomeWorkstation) {
  $SteamDB = @("1026460","431960","388080","367670","227260","274920")
  $InstalledIDs = [System.Collections.Generic.List[string]]::new()
  $steamCommonPath = Join-Path "${Env:Programfiles(x86)}\Steam\steamapps" 'common'
  $appIdFiles = Get-ChildItem -Path $steamCommonPath -Filter 'steam_appid.txt' -File -Recurse -ErrorAction Ignore
  $appIds = if ($appIdFiles) { Get-Content -Path $appIdFiles.FullName -ErrorAction Ignore } else { @() }
  if ($appIds) { [void]$InstalledIDs.AddRange([string[]]$appIds) }
  foreach ($item in $SteamDB) {
    if ($InstalledIDs -notcontains $item) {
      Start-Process -FilePath ".\steam.exe" -ArgumentList "-applaunch","$item" `
        -WorkingDirectory "${Env:Programfiles(x86)}\Steam\" -Wait
    }
  }
}

# Symlinks
sudo New-Item -ItemType SymbolicLink -Path "$(Split-Path -Path (Get-Command busybox*.exe).Source)\busybox.exe" `
    -Target (Get-Command busybox*.exe).Source
sudo New-Item -ItemType SymbolicLink -Path "$(Split-Path -Path (Get-Command tdmgr*.exe).Source)\tdmgr.exe" `
    -Target (Get-Command tdmgr*.exe).Source

# Custom packages
Install-CustomApp -URL "https://www.chrysocome.net/downloads/0d23e6a31f1d37850fc2040eec98e9f9/rawwritewin-0.7.zip" `
    -Folder "RawWrite"
Install-CustomApp -URL "https://www.handshake.de/user/chmaas/delphi/download/xvi32.zip" -Folder "XVI32"
Install-CustomApp -URL "https://code.kliu.org/misc/winisoutils/eicfg_removal_utility.zip"  `
    -Folder "ei.cfg-removal-utility"
Install-CustomPackage `
    -URL "https://downloads.sourceforge.net/project/catacombae/HFSExplorer/2021.10.9/hfsexplorer-2021.10.9-setup.exe"
$null = New-Item -Path "$Env:UserProfile\bin\RipMe" -ItemType Directory -ErrorAction Ignore
$null = Get-CustomApp `
    -Link "https://github.com/RipMeApp/ripme/releases/download/1.7.95/ripme.jar" `
    -Folder "$Env:UserProfile\bin\RipMe"
Install-CustomApp -URL "https://image.easyeda.com/files/easyeda-router-windows-x64-v0.8.11.zip"

if ($HomeWorkstation) {
  Install-CustomApp `
    -URL "https://files1.majorgeeks.com/10afebdbffcd4742c81a3cb0f6ce4092156b4375/cddvd/CDmage1-01-5.exe" `
    -Folder "CDMage"
  Install-CustomApp -URL "https://downloads.sourceforge.net/project/acidview6-win32/acidview6-win32/6.10/avw-610.zip" `
    -Folder "ACiDView"
  Install-CustomApp -URL "https://downloads.sourceforge.net/project/nohboard/NohBoard-v0.17b.zip"
  Install-CustomApp -URL "https://www.psx-place.com/resources/psx2psp.586/download?version=898"
  Install-CustomPackage -URL "https://mamedev.emulab.it/clrmamepro/binaries/cmp4044c_64.exe"
  Install-CustomApp -URL "https://falcosoft.hu/midiplayer_60_x64.zip"
  Install-CustomApp -URL "https://www.skraper.net/download/beta/Skraper-1.1.1.7z" -Folder "SkraperUI"
  Install-CustomApp `
    -URL "https://www.psx-place.com/resources/obsolete-winhiip-by-gadgetfreak.666/download?version=1066" `
    -Folder "WinHIIP"
  Install-CustomApp -URL "https://www.softwareok.com/Download/WinBin2Iso.zip" -Folder "WinBin2Iso"
  Install-CustomApp -URL "https://github.com/JustArchiNET/ArchiSteamFarm/releases/download/5.2.4.2/ASF-win-x64.zip" `
    -Folder "ArchiSteamFarm2"
  Install-CustomApp `
    -URL "https://github.com/KirovAir/TwilightBoxart/releases/download/0.7/TwilightBoxart-Windows-UX.zip" `
    -Folder "TwilightMenuBoxArt"
  $null = New-Item -Path "$Env:UserProfile\bin\ISOToolkit" -ItemType Directory -ErrorAction Ignore
  $null = Get-CustomApp `
    -Link "https://files1.majorgeeks.com/10afebdbffcd4742c81a3cb0f6ce4092156b4375/cddvd/ISOToolKit.exe" `
    -Folder "$Env:UserProfile\bin\ISOToolkit"
  Install-CustomApp -URL "https://github.com/putnam/binmerge/releases/download/1.0.1/binmerge-1.0.1-win64.zip"
  Install-CustomApp -URL "https://www.psx-place.com/resources/ppf-o-matic.507/download?version=717" `
    -Folder "ppf-o-matic"
  Install-CustomApp -URL "https://github.com/oonqt/MBCord/releases/download/2.3.13/MBCord-win32-x64.zip" `
    -Folder "MBCord"
  Install-CustomApp `
    -URL "https://github.com/extramaster/bchunk/releases/download/v1.2.1_repub.1/bchunk.v1.2.1_repub.1.zip"
  $Package = Get-CustomApp `
    -Link "https://github.com/mamedev/mame/releases/download/mame0242/mame0242b_64bit.exe" `
    -Folder "$Env:UserProfile\Downloads\"
  $null = & 7z e -o"$Env:UserProfile\bin\" -y "$Env:UserProfile\Downloads\$Package" chdman.exe
  Remove-Item -LiteralPath "$Env:UserProfile\Downloads\$Package" -Force
  Install-CustomApp -URL "https://lib.openmpt.org/files/libopenmpt/bin/libopenmpt-0.6.3+release.bin.windows.zip" `
    -Folder "OpenMPT123"
  Install-CustomApp `
    -URL "https://github.com/Mindwerks/wildmidi/releases/download/wildmidi-0.4.4/wildmidi-0.4.4-win64.zip"
  Move-Item -Path "$Env:UserProfile\bin\wildmidi*\" -Destination "$Env:UserProfile\bin\WildMIDI\" -Force
  Install-CustomApp -URL "https://github.com/aaru-dps/Aaru/releases/download/v5.3.1/aaru-5.3.1_windows_x64.zip" `
    -Folder "Aaru"
}

# Startup shortcut for scoop-tray
if (-not (Test-Path -LiteralPath "$Env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\scoop-tray.lnk")) {
  Write-Verbose "Create scoop-tray shortcut in shell:startup..."
  $WSHShell = New-Object -ComObject WScript.Shell
  $Shortcut = $WSHShell.CreateShortcut("$Env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\scoop-tray.lnk")
  $Shortcut.TargetPath = "$Env:UserProfile\scoop\apps\scoop-tray\current\scoop-tray.bat"
  $Shortcut.WindowStyle = 7
  $Shortcut.IconLocation = "%USERPROFILE%\scoop\apps\scoop-tray\current\updates-available.ico"
  $Shortcut.Description = "scoop-tray.bat"
  $Shortcut.WorkingDirectory = Split-Path "$Env:UserProfile\scoop\apps\scoop-tray\current\scoop-tray.bat" -Resolve
  $Shortcut.Save()
}

# GO env
if (-not (Test-Path -LiteralPath "$Env:UserProfile\go\" -PathType Container)) {
  Write-Verbose "Configuring GO Environment..."
  $null = New-Item -Path "${Env:UserProfile}\go" -ItemType Directory
  [System.Environment]::SetEnvironmentVariable('GOPATH', "${Env:UserProfile}\go", 'USER')
}

# DOS/PowerShell environment
Write-Verbose "Customize DOS/PowerShell Environment..."
if ($null -eq (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Command Processor").AutoRun) {
  Start-Process -FilePath "cmd" -ArgumentList "/c","clink","autorun","install" -Wait -WindowStyle Hidden
}
Start-Process -FilePath "cmd" -ArgumentList "/c","concfg","import","solarized-dark" -Verb RunAs -Wait

# Pin Chrome to taskbar
Write-Verbose "Pin Google Chrome to Taskbar..."
Invoke-Elevated -FilePath "PowerShell" -ArgumentList "syspin",
    "'$Env:ProgramData\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk'",
    "c:5386"

# Dotfiles
  if (-not (Test-Path -LiteralPath "$Env:UserProfile\dotposh")) {
    Write-Verbose "Install PowerShell dot files..."
    git clone https://github.com/mikepruett3/dotposh.git "$Env:UserProfile\dotposh" 2>&1
    if ($LASTEXITCODE -ne 0) {
      Write-Warning "git clone failed for dotposh with exit code $LASTEXITCODE"
    }
@'
New-Item -Path $Env:UserProfile\Documents\WindowsPowerShell -ItemType Directory -ErrorAction Ignore
Remove-Item `
    -Path $Env:UserProfile\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 -Force -ErrorAction Ignore
New-Item `
    -Path $Env:UserProfile\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 -ItemType SymbolicLink `
      -Target $Env:UserProfile\dotposh\profile.ps1
'@ > $Env:Temp\dotposh.ps1
  Invoke-Elevated -FilePath "PowerShell" -ArgumentList "$Env:Temp\dotposh.ps1"
  Remove-Item -LiteralPath $Env:Temp\dotposh.ps1 -Force
@'
cd $Env:UserProfile\dotposh
git submodule init
git submodule update
'@ > $Env:Temp\submodule.ps1
  Start-Process -FilePath "PowerShell" -ArgumentList "$Env:Temp\submodule.ps1" -Wait
  Remove-Item -LiteralPath $Env:Temp\submodule.ps1 -Force
}

# Pin PowerShell to Taskbar
Invoke-Elevated -FilePath "PowerShell" -ArgumentList "syspin",
    "'$Env:AppData\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk'",
    "c:5386"

# PowerShell 7 + pin
$PS7 = winget list --exact -q Microsoft.PowerShell
if (-not $PS7) {
  Write-Verbose "Installing PowerShell 7..."
@'
$ps7Installer = Join-Path $Env:Temp ("install-powershell-{0}.ps1" -f [System.Guid]::NewGuid().ToString())
try {
  Invoke-RestMethod -Uri 'https://aka.ms/install-powershell.ps1' -OutFile $ps7Installer
  & $ps7Installer -UseMSI -Quiet
}
finally {
  if (Test-Path -LiteralPath $ps7Installer) {
    Remove-Item -LiteralPath $ps7Installer -Force
  }
}
'@ > $Env:Temp\ps7.ps1
  Invoke-Elevated -FilePath "PowerShell" -ArgumentList "$Env:Temp\ps7.ps1" -Hidden
  Remove-Item -LiteralPath $Env:Temp\ps7.ps1 -Force
}

}

if ($MyInvocation.InvocationName -ne '.') {
  Start-MainFunction @PSBoundParameters
  exit $LASTEXITCODE
}
