<#
.SYNOPSIS
  Initialize custom PowerShell + tooling environment (Scoop, Winget, Choco, apps, custom downloads).
.NOTES
  Requires Windows, PowerShell 5+; will elevate for certain steps.
  ExecutionPolicy for CurrentUser will be set to Unrestricted on first run.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

function Assert-Admin {
  $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Administrator privileges required."
  }
}

function Run-Elevated {
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
  if (-not $NoWait) { $proc.WaitForExit(); if ($proc.ExitCode -ne 0) { throw "Command failed: $FilePath $ArgumentList (exit $($proc.ExitCode))" } }
}

function Install-ScoopApp {
  param([Parameter(Mandatory)][string]$Package)
  Write-Verbose "Preparing to install $Package"
  if (-not (scoop info $Package).Installed) {
    Write-Verbose "Installing $Package"
    scoop install $Package
  } else {
    Write-Verbose "Package $Package already installed; skipping."
  }
}

function Install-WinGetApp {
  param([Parameter(Mandatory)][string]$PackageID)
  Write-Verbose "Installing $PackageID"
  winget install --silent --id "$PackageID" --accept-source-agreements --accept-package-agreements
}

function Install-ChocoApp {
  param([Parameter(Mandatory)][string]$Package)
  Write-Verbose "Preparing to install $Package"
  $listApp = choco list --local $Package
  if ($listApp -like "0 packages installed.") {
    Write-Verbose "Installing $Package"
    Run-Elevated -FilePath "PowerShell" -ArgumentList "choco","install","$Package","-y"
  } else {
    Write-Verbose "Package $Package already installed; skipping."
  }
}

function Extract-Download {
  param(
    [Parameter(Mandatory)][string]$Folder,
    [Parameter(Mandatory)][string]$File
  )
  if (-not (Test-Path -LiteralPath $Folder -PathType Container)) { throw "$Folder does not exist." }
  if (Test-Path -LiteralPath $File -PathType Leaf) {
    $ext = ($File.Split(".") | Select-Object -Last 1).ToLowerInvariant()
    switch ($ext) {
      "rar" { Start-Process -FilePath "UnRar.exe" -ArgumentList "x","-op'$Folder'","-y","$File" -WorkingDirectory "$Env:ProgramFiles\WinRAR\" -Wait | Out-Null }
      "zip" { 7z x -o"$Folder" -y "$File" | Out-Null }
      "7z"  { 7z x -o"$Folder" -y "$File" | Out-Null }
      "exe" { 7z x -o"$Folder" -y "$File" | Out-Null }
      Default { throw "No extractor for $File" }
    }
  }
}

function Download-CustomApp {
  param(
    [Parameter(Mandatory)][string]$Link,
    [Parameter(Mandatory)][string]$Folder
  )
  if ((curl -sIL "$Link" | Select-String -Pattern "Content-Disposition")) {
    $Package = (curl -sIL "$Link" | Select-String -Pattern "filename=" | Split-String -Separator "=" | Select-Object -Last 1).Trim('"')
  } else {
    $Package = $Link.Split("/") | Select-Object -Last 1
  }
  Write-Verbose "Downloading $Package"
  aria2c --quiet --dir="$Folder" "$Link"
  return $Package
}

function Install-CustomApp {
  param(
    [Parameter(Mandatory)][string]$URL,
    [string]$Folder
  )
  $Package = Download-CustomApp -Link $URL -Folder "$Env:UserProfile\Downloads\"
  $downloadPath = Join-Path $Env:UserProfile\Downloads $Package
  if (Test-Path -LiteralPath $downloadPath -PathType Leaf) {
    if ($PSBoundParameters.ContainsKey('Folder')) {
      $target = Join-Path "$Env:UserProfile\bin" $Folder
      if (-not (Test-Path -LiteralPath $target)) { New-Item -Path $target -ItemType Directory | Out-Null }
      Extract-Download -Folder $target -File $downloadPath
    } else {
      Extract-Download -Folder "$Env:UserProfile\bin\" -File $downloadPath
    }
    Remove-Item -LiteralPath $downloadPath -Force
  }
}

function Install-CustomPackage {
  param([Parameter(Mandatory)][string]$URL)
  $Package = Download-CustomApp -Link $URL -Folder "$Env:UserProfile\Downloads\"
  $downloadPath = Join-Path $Env:UserProfile\Downloads $Package
  if (Test-Path -LiteralPath $downloadPath -PathType Leaf) {
    Run-Elevated -FilePath ".\$Package" -ArgumentList "/S" -NoWait:$false -Hidden
    Remove-Item -LiteralPath $downloadPath -Force
  }
}

function Remove-InstalledApp {
  param([Parameter(Mandatory)][string]$Package)
  Write-Verbose "Uninstalling: $Package"
  Run-Elevated -FilePath "PowerShell" -ArgumentList "Get-AppxPackage","-AllUsers","-Name","'$Package'" -Hidden
}

function Enable-Bucket {
  param([Parameter(Mandatory)][string]$Bucket)
  if (-not ((scoop bucket list).Name -eq "$Bucket")) {
    Write-Verbose "Adding bucket $Bucket"
    scoop bucket add $Bucket
  } else {
    Write-Verbose "Bucket $Bucket already added; skipping."
  }
}

# ExecutionPolicy: CurrentUser -> Unrestricted
if ((Get-ExecutionPolicy -Scope CurrentUser) -notcontains "Unrestricted") {
  Write-Verbose "Setting Execution Policy for Current User..."
  Run-Elevated -FilePath "PowerShell" -ArgumentList "Set-ExecutionPolicy","-Scope","CurrentUser","-ExecutionPolicy","Unrestricted","-Force"
  Write-Output "Restart/Re-Run script required."
  Start-Sleep -Seconds 10
  return
}

# Scoop
if (-not (Get-Command -Name "scoop" -CommandType Application -ErrorAction SilentlyContinue)) {
  Write-Verbose "Installing Scoop..."
  iex ((New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh'))
}

# Chocolatey
if (-not (Get-Command -Name "choco" -CommandType Application -ErrorAction SilentlyContinue)) {
  Write-Verbose "Installing Chocolatey..."
  @'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
'@ > $Env:Temp\choco.ps1
  Run-Elevated -FilePath "PowerShell" -ArgumentList "$Env:Temp\choco.ps1"
  Remove-Item -LiteralPath $Env:Temp\choco.ps1 -Force
}

# WinGet
if (-not (Get-AppPackage -name "Microsoft.DesktopAppInstaller")) {
  Write-Verbose "Installing WinGet..."
  @'
$releases_url = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Register-PackageSource -Name Nuget -Location "http://www.nuget.org/api/v2" -ProviderName Nuget -Trusted
Install-Package Microsoft.UI.Xaml -RequiredVersion 2.7.1
$releases = Invoke-RestMethod -uri $releases_url
$latestRelease = $releases.assets | Where { $_.browser_download_url.EndsWith('msixbundle') } | Select-Object -First 1
Add-AppxPackage -Path $latestRelease.browser_download_url
'@ > $Env:Temp\winget.ps1
  Run-Elevated -FilePath "PowerShell" -ArgumentList "$Env:Temp\winget.ps1"
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
Run-Elevated -FilePath "PowerShell" -ArgumentList "${Env:Temp}\openssh.ps1" -Hidden
Remove-Item -LiteralPath "${Env:Temp}\openssh.ps1" -Force

# Git
Install-WinGetApp -PackageID "Git.Git"
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
  Run-Elevated -FilePath "PowerShell" -ArgumentList "Set-Service","ssh-agent","-StartupType","Manual" -Hidden
}

# Aria2
Install-ScoopApp -Package "aria2"
if (-not (scoop config aria2-enabled) -eq $True) { scoop config aria2-enabled true }
if (-not (scoop config aria2-warning-enabled) -eq $False) { scoop config aria2-warning-enabled false }
if (-not (Get-ScheduledTaskInfo -TaskName "Aria2RPC" -ErrorAction Ignore)) {
@'
$Action = New-ScheduledTaskAction -Execute $Env:UserProfile\scoop\apps\aria2\current\aria2c.exe -Argument "--enable-rpc --rpc-listen-all" -WorkingDirectory $Env:UserProfile\Downloads
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Principal = New-ScheduledTaskPrincipal -UserID "$Env:ComputerName\$Env:Username" -LogonType S4U
$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "Aria2RPC" -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings
'@ > $Env:Temp\aria2.ps1
  Run-Elevated -FilePath "PowerShell" -ArgumentList "$Env:Temp\aria2.ps1"
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
$HomeWorkstation = $(Read-Host -Prompt "Is this a workstation for Home use (y/n)?") -eq "y"

if ($HomeWorkstation -and -not (Test-Path -LiteralPath $Env:UserProfile\bin)) {
  Write-Verbose "Creating bin directory in $Env:UserProfile"
  New-Item -Path $Env:UserProfile\bin -ItemType Directory | Out-Null
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
  "gerardog.gsudo","Microsoft.DotNet.DesktopRuntime.3_1","Microsoft.DotNet.DesktopRuntime.5","Microsoft.DotNet.DesktopRuntime.6","Microsoft.DotNet.DesktopRuntime.7",
  "Microsoft.WindowsTerminal","Microsoft.PowerToys","frippery.busybox-w32","junegunn.fzf","Neovim.Neovim","Obsidian.Obsidian","Microsoft.OpenJDK.17",
  "GoLang.Go.1.19","Python.Python.3.11","chrisant996.Clink","PuTTY.PuTTY","WinSCP.WinSCP","Balena.Etcher","CPUID.HWMonitor","CrystalDewWorld.CrystalDiskMark",
  "BleachBit.BleachBit","GnuPG.GnuPG","LIGHTNINGUK.ImgBurn","dotPDNLLC.paintdotnet","UderzoSoftware.SpaceSniffer","Rufus.Rufus",
  "scottlerch.hosts-file-editor","thomasnordquist.MQTT-Explorer","jziolkowski.tdm","HDDGURU.HDDRawCopyTool","dnSpyEx.dnSpy","JLC.EasyEDA","Google.Chrome",
  "Lexikos.AutoHotkey","SumatraPDF.SumatraPDF","ScooterSoftware.BeyondCompare4","Eassos.DiskGenius","RevoUninstaller.RevoUninstaller","ElaborateBytes.VirtualCloneDrive",
  "RARLab.WinRAR","Piriform.Speccy","Piriform.Defraggler","Starship.Starship","OliverBetz.ExifTool"
)
foreach ($item in $WinGet) { Install-WinGetApp -PackageID $item }

if ($HomeWorkstation) {
  $WinGet = @(
    "Discord.Discord","HandBrake.HandBrake","AndreWiethoff.ExactAudioCopy","clsid2.mpc-hc","Plex.Plex","Plex.Plexamp","PointPlanck.FileBot",
    "CPUID.CPU-Z","TechPowerUp.GPU-Z","VideoLAN.VLC","Mp3tag.Mp3tag","MusicBee.MusicBee","OBSProject.OBSStudio","yt-dlp.yt-dlp",
    "MediaArea.MediaInfo","MediaArea.MediaInfo.GUI","MoritzBunkus.MKVToolNix","Ocenaudio.Ocenaudio","OpenMPT.OpenMPT","Romcenter.Romcenter","Valve.Steam"
  )
  foreach ($item in $WinGet) { Install-WinGetApp -PackageID $item }
}

# VSCode custom install
winget install Microsoft.VisualStudioCode --override '/SILENT /mergetasks="!runcode,addcontextmenufiles,addcontextmenufolders"'

# Choco packages
$Choco = @("syspin","sd-card-formatter","winimage","winsetupfromusb","fluidsynth")
foreach ($item in $Choco) { Install-ChocoApp -Package $item }

# Steam apps (if home)
if ($HomeWorkstation) {
  $SteamDB = @("1026460","431960","388080","367670","227260","274920")
  $InstalledIDs = [System.Collections.ArrayList]::new()
  foreach ($item in (Get-ChildItem -Path "${Env:Programfiles(x86)}\Steam\steamapps\common\" -Filter "steam_appid.txt" -Recurse).VersionInfo.FileName) {
    [void]$InstalledIDs.Add((Get-Content -Path $item))
  }
  foreach ($item in $SteamDB) {
    if ($item -ne $InstalledIDs) {
      Start-Process -FilePath ".\steam.exe" -ArgumentList "-applaunch","$item" -WorkingDirectory "${Env:Programfiles(x86)}\Steam\" -Wait
    }
  }
}

# Symlinks
sudo New-Item -ItemType SymbolicLink -Path "$(Split-Path -Path (Get-Command busybox*.exe).Source)\busybox.exe" -Target (Get-Command busybox*.exe).Source
sudo New-Item -ItemType SymbolicLink -Path "$(Split-Path -Path (Get-Command tdmgr*.exe).Source)\tdmgr.exe" -Target (Get-Command tdmgr*.exe).Source

# Custom packages
Install-CustomApp -URL "http://www.chrysocome.net/downloads/0d23e6a31f1d37850fc2040eec98e9f9/rawwritewin-0.7.zip" -Folder "RawWrite"
Install-CustomApp -URL "http://www.handshake.de/user/chmaas/delphi/download/xvi32.zip" -Folder "XVI32"
Install-CustomApp -URL "https://code.kliu.org/misc/winisoutils/eicfg_removal_utility.zip"  -Folder "ei.cfg-removal-utility"
Install-CustomPackage -URL "https://downloads.sourceforge.net/project/catacombae/HFSExplorer/2021.10.9/hfsexplorer-2021.10.9-setup.exe"
New-Item -Path "$Env:UserProfile\bin\RipMe" -ItemType Directory -ErrorAction Ignore | Out-Null
Download-CustomApp -Link "https://github.com/RipMeApp/ripme/releases/download/1.7.95/ripme.jar" -Folder "$Env:UserProfile\bin\RipMe" | Out-Null
Install-CustomApp -URL "https://image.easyeda.com/files/easyeda-router-windows-x64-v0.8.11.zip"

if ($HomeWorkstation) {
  Install-CustomApp -URL "https://files1.majorgeeks.com/10afebdbffcd4742c81a3cb0f6ce4092156b4375/cddvd/CDmage1-01-5.exe" -Folder "CDMage"
  Install-CustomApp -URL "https://downloads.sourceforge.net/project/acidview6-win32/acidview6-win32/6.10/avw-610.zip" -Folder "ACiDView"
  Install-CustomApp -URL "https://downloads.sourceforge.net/project/nohboard/NohBoard-v0.17b.zip"
  Install-CustomApp -URL "https://www.psx-place.com/resources/psx2psp.586/download?version=898"
  Install-CustomPackage -URL "https://mamedev.emulab.it/clrmamepro/binaries/cmp4044c_64.exe"
  Install-CustomApp -URL "https://falcosoft.hu/midiplayer_60_x64.zip"
  Install-CustomApp -URL "https://www.skraper.net/download/beta/Skraper-1.1.1.7z" -Folder "SkraperUI"
  Install-CustomApp -URL "https://www.psx-place.com/resources/obsolete-winhiip-by-gadgetfreak.666/download?version=1066" -Folder "WinHIIP"
  Install-CustomApp -URL "https://www.softwareok.com/Download/WinBin2Iso.zip" -Folder "WinBin2Iso"
  Install-CustomApp -URL "https://github.com/JustArchiNET/ArchiSteamFarm/releases/download/5.2.4.2/ASF-win-x64.zip" -Folder "ArchiSteamFarm2"
  Install-CustomApp -URL "https://github.com/KirovAir/TwilightBoxart/releases/download/0.7/TwilightBoxart-Windows-UX.zip" -Folder "TwilightMenuBoxArt"
  New-Item -Path "$Env:UserProfile\bin\ISOToolkit" -ItemType Directory -ErrorAction Ignore | Out-Null
  Download-CustomApp -Link "https://files1.majorgeeks.com/10afebdbffcd4742c81a3cb0f6ce4092156b4375/cddvd/ISOToolKit.exe" -Folder "$Env:UserProfile\bin\ISOToolkit" | Out-Null
  Install-CustomApp -URL "https://github.com/putnam/binmerge/releases/download/1.0.1/binmerge-1.0.1-win64.zip"
  Install-CustomApp -URL "https://www.psx-place.com/resources/ppf-o-matic.507/download?version=717" -Folder "ppf-o-matic"
  Install-CustomApp -URL "https://github.com/oonqt/MBCord/releases/download/2.3.13/MBCord-win32-x64.zip" -Folder "MBCord"
  Install-CustomApp -URL "https://github.com/extramaster/bchunk/releases/download/v1.2.1_repub.1/bchunk.v1.2.1_repub.1.zip"
  $Package = Download-CustomApp -Link "https://github.com/mamedev/mame/releases/download/mame0242/mame0242b_64bit.exe" -Folder "$Env:UserProfile\Downloads\"
  7z e -o"$Env:UserProfile\bin\" -y "$Env:UserProfile\Downloads\$Package" chdman.exe | Out-Null
  Remove-Item -LiteralPath "$Env:UserProfile\Downloads\$Package" -Force
  Install-CustomApp -URL "https://lib.openmpt.org/files/libopenmpt/bin/libopenmpt-0.6.3+release.bin.windows.zip" -Folder "OpenMPT123"
  Install-CustomApp -URL "https://github.com/Mindwerks/wildmidi/releases/download/wildmidi-0.4.4/wildmidi-0.4.4-win64.zip"
  Move-Item -Path "$Env:UserProfile\bin\wildmidi*\" -Destination "$Env:UserProfile\bin\WildMIDI\" -Force
  Install-CustomApp -URL "https://github.com/aaru-dps/Aaru/releases/download/v5.3.1/aaru-5.3.1_windows_x64.zip" -Folder "Aaru"
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
  New-Item -Path "${Env:UserProfile}\go" -ItemType Directory | Out-Null
  [System.Environment]::SetEnvironmentVariable('GOPATH', "${Env:UserProfile}\go", 'USER')
}

# DOS/PowerShell environment
Write-Verbose "Customize DOS/PowerShell Environment..."
if ((Get-ItemProperty -Path "HKCU:\Software\Microsoft\Command Processor").AutoRun -eq $Null) {
  Start-Process -FilePath "cmd" -ArgumentList "/c","clink","autorun","install" -Wait -WindowStyle Hidden
}
Start-Process -FilePath "cmd" -ArgumentList "/c","concfg","import","solarized-dark" -Verb RunAs -Wait

# Pin Chrome to taskbar
Write-Verbose "Pin Google Chrome to Taskbar..."
Run-Elevated -FilePath "PowerShell" -ArgumentList "syspin","'$Env:ProgramData\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk'","c:5386"

# Dotfiles
if (-not (Test-Path -LiteralPath "$Env:UserProfile\dotposh")) {
  Write-Verbose "Install PowerShell dot files..."
  Start-Process -FilePath "PowerShell" -ArgumentList "git","clone","https://github.com/mikepruett3/dotposh.git","$Env:UserProfile\dotposh" -Wait
@'
New-Item -Path $Env:UserProfile\Documents\WindowsPowerShell -ItemType Directory -ErrorAction Ignore
Remove-Item -Path $Env:UserProfile\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 -Force -ErrorAction Ignore
New-Item -Path $Env:UserProfile\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 -ItemType SymbolicLink -Target $Env:UserProfile\dotposh\profile.ps1
'@ > $Env:Temp\dotposh.ps1
  Run-Elevated -FilePath "PowerShell" -ArgumentList "$Env:Temp\dotposh.ps1"
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
Run-Elevated -FilePath "PowerShell" -ArgumentList "syspin","'$Env:AppData\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk'","c:5386"

# PowerShell 7 + pin
$PS7 = winget list --exact -q Microsoft.PowerShell
if (-not $PS7) {
  Write-Verbose "Installing PowerShell 7..."
@'
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
'@ > $Env:Temp\ps7.ps1
  Run-Elevated -FilePath "PowerShell" -ArgumentList "$Env:Temp\ps7.ps1" -Hidden
  Re
