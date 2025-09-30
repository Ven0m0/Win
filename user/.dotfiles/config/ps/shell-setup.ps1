<#
.SYNOPSIS
    Script to Initialize my custom powershell setup.
.DESCRIPTION
    Script uses scoop
.NOTES
    **NOTE** Will configure the Execution Policy for the "CurrentUser" to Unrestricted.

    Author: Mike Pruett
    Date: October 18th, 2018

    Last Updated on August 4th, 2023
#>

$VerbosePreference = "Continue"

function Install-ScoopApp {
    param (
        [string]$Package
    )
    Write-Verbose -Message "Preparing to install $Package"
    if (! (scoop info $Package).Installed ) {
        Write-Verbose -Message "Installing $Package"
        scoop install $Package
    } else {
        Write-Verbose -Message "Package $Package already installed! Skipping..."
    }
}

function Install-WinGetApp {
    param (
        [string]$PackageID
    )
    Write-Verbose -Message "Preparing to install $PackageID"
    # Added accept options based on this issue - https://github.com/microsoft/winget-cli/issues/1559
    #$listApp = winget list --exact -q $PackageID --accept-source-agreements
    #if (winget list --exact --id "$PackageID" --accept-source-agreements) {
    #    Write-Verbose -Message "Package $PackageID already installed! Skipping..."
    #} else {
    #    Write-Verbose -Message "Installing $Package"
    #    winget install --silent --id "$PackageID" --accept-source-agreements --accept-package-agreements
    #}
    Write-Verbose -Message "Installing $Package"
    winget install --silent --id "$PackageID" --accept-source-agreements --accept-package-agreements
}

function Install-ChocoApp {
    param (
        [string]$Package
    )
    Write-Verbose -Message "Preparing to install $Package"
    $listApp = choco list --local $Package
    if ($listApp -like "0 packages installed.") {
        Write-Verbose -Message "Installing $Package"
        Start-Process -FilePath "PowerShell" -ArgumentList "choco","install","$Package","-y" -Verb RunAs -Wait
    } else {
        Write-Verbose -Message "Package $Package already installed! Skipping..."
    }
}

function Extract-Download {
    param (
        [string]$Folder,
        [string]$File
    )
    if (!(Test-Path -Path "$Folder" -PathType Container)) {
        Write-Error "$Folder does not exist!!!"
        Break
    }
    if (Test-Path -Path "$File" -PathType Leaf) {
        switch ($File.Split(".") | Select-Object -Last 1) {
            "rar" { Start-Process -FilePath "UnRar.exe" -ArgumentList "x","-op'$Folder'","-y","$File" -WorkingDirectory "$Env:ProgramFiles\WinRAR\" -Wait | Out-Null }
            "zip" { 7z x -o"$Folder" -y "$File" | Out-Null }
            "7z" { 7z x -o"$Folder" -y "$File" | Out-Null }
            "exe" { 7z x -o"$Folder" -y "$File" | Out-Null }
            Default { Write-Error "No way to Extract $File !!!"; Break }
        }
    }
}

function Download-CustomApp {
    param (
        [string]$Link,
        [string]$Folder
    )
    if ((curl -sIL "$Link" | Select-String -Pattern "Content-Disposition") -ne $Null) {
        $Package = $(curl -sIL "$Link" | Select-String -Pattern "filename=" | Split-String -Separator "=" | Select-Object -Last 1).Trim('"')
    } else {
        $Package = $Link.split("/") | Select-Object -Last 1
    }
    Write-Verbose -Message "Preparing to download $Package"
    aria2c --quiet --dir="$Folder" "$Link"
    Return $Package
}

function Install-CustomApp {
    param (
        [string]$URL,
        [string]$Folder
    )
    $Package = Download-CustomApp -Link $URL -Folder "$Env:UserProfile\Downloads\"
    if (Test-Path -Path "$Env:UserProfile\Downloads\$Package" -PathType Leaf) {
        if (Test-Path Variable:Folder) {
            if (!(Test-Path -Path "$Env:UserProfile\bin\$Folder")) {
                New-Item -Path "$Env:UserProfile\bin\$Folder" -ItemType Directory | Out-Null
            }
            Extract-Download -Folder "$Env:UserProfile\bin\$Folder" -File "$Env:UserProfile\Downloads\$Package"
        } else {
            Extract-Download -Folder "$Env:UserProfile\bin\" -File "$Env:UserProfile\Downloads\$Package"
        }
        Remove-Item -Path "$Env:UserProfile\Downloads\$Package"
    }
}

function Install-CustomPackage {
    param (
        [string]$URL
    )
    $Package = Download-CustomApp -Link $URL
    if (Test-Path -Path "$Env:UserProfile\Downloads\$Package" -PathType Leaf) {
        Start-Process -FilePath ".\$Package" -ArgumentList "/S" -WorkingDirectory "${Env:UserProfile}\Downloads\" -Verb RunAs -Wait #-WindowStyle Hidden
        Remove-Item -Path "$Env:UserProfile\Downloads\$Package"
    }
}

function Remove-InstalledApp {
    param (
        [string]$Package
    )
    Write-Verbose -Message "Uninstalling: $Package"
    Start-Process -FilePath "PowerShell" -ArgumentList "Get-AppxPackage","-AllUsers","-Name","'$Package'" -Verb RunAs -WindowStyle Hidden
}

function Enable-Bucket {
    param (
        [string]$Bucket
    )
    if (!($(scoop bucket list).Name -eq "$Bucket")) {
        Write-Verbose -Message "Adding Bucket $Bucket to scoop..."
        scoop bucket add $Bucket
    } else {
        Write-Verbose -Message "Bucket $Bucket already added! Skipping..."
    }
}

# Configure ExecutionPolicy to Unrestricted for CurrentUser Scope
if ((Get-ExecutionPolicy -Scope CurrentUser) -notcontains "Unrestricted") {
    Write-Verbose -Message "Setting Execution Policy for Current User..."
    Start-Process -FilePath "PowerShell" -ArgumentList "Set-ExecutionPolicy","-Scope","CurrentUser","-ExecutionPolicy","Unrestricted","-Force" -Verb RunAs -Wait
    Write-Output "Restart/Re-Run script!!!"
    Start-Sleep -Seconds 10
    Break
}

# Install Scoop, if not already installed
#$scoopInstalled = Get-Command "scoop"
if ( !(Get-Command -Name "scoop" -CommandType Application -ErrorAction SilentlyContinue | Out-Null) ) {
    Write-Verbose -Message "Installing Scoop..."
    iex ((New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh'))
}

# Install Chocolatey, if not already installed
#$chocoInstalled = Get-Command -Name "choco" -CommandType Application -ErrorAction SilentlyContinue | Out-Null
if (! (Get-Command -Name "choco" -CommandType Application -ErrorAction SilentlyContinue | Out-Null) ) {
    Write-Verbose -Message "Installing Chocolatey..."
@'
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
'@ > $Env:Temp\choco.ps1
    Start-Process -FilePath "PowerShell" -ArgumentList "$Env:Temp\choco.ps1" -Verb RunAs -Wait
    Remove-Item -Path $Env:Temp\choco.ps1 -Force
}

# Install WinGet, if not already installed
# From crutkas's gist - https://gist.github.com/crutkas/6c2096eae387e544bd05cde246f23901
#$hasPackageManager = Get-AppPackage -name "Microsoft.DesktopAppInstaller"
if (!(Get-AppPackage -name "Microsoft.DesktopAppInstaller")) {
    Write-Verbose -Message "Installing WinGet..."
@'
# Set URL and Enable TLSv12
$releases_url = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Dont Think We Need This!!!
#Install-PackageProvider -Name NuGet

# Install Nuget as Package Source Provider
Register-PackageSource -Name Nuget -Location "http://www.nuget.org/api/v2" -ProviderName Nuget -Trusted

# Install Microsoft.UI.Xaml (This is not currently working!!!)
Install-Package Microsoft.UI.Xaml -RequiredVersion 2.7.1

# Grab "Latest" release
$releases = Invoke-RestMethod -uri $releases_url
$latestRelease = $releases.assets | Where { $_.browser_download_url.EndsWith('msixbundle') } | Select -First 1

# Install Microsoft.DesktopAppInstaller Package
Add-AppxPackage -Path $latestRelease.browser_download_url
'@ > $Env:Temp\winget.ps1
    Start-Process -FilePath "PowerShell" -ArgumentList "$Env:Temp\winget.ps1" -Verb RunAs -Wait
    Remove-Item -Path $Env:Temp\winget.ps1 -Force
}

# Only install OpenSSH Package, if not on Windows 10
if ([Environment]::OSVersion.Version.Major -lt 10) {
    Install-ScoopApp -Package "openssh"
}

# Install OpenSSH.Client on Windows 10+
@'
if ((Get-WindowsCapability -Online -Name OpenSSH.Client*).State -ne "Installed") {
    Add-WindowsCapability -Online -Name OpenSSH.Client*
}
'@ > "${Env:Temp}\openssh.ps1"
Start-Process -FilePath "PowerShell" -ArgumentList "${Env:Temp}\openssh.ps1" -Verb RunAs -Wait -WindowStyle Hidden
Remove-Item -Path "${Env:Temp}\openssh.ps1" -Force

# Configure git
Install-WinGetApp -PackageID "Git.Git"
Start-Sleep -Seconds 5
refreshenv
Start-Sleep -Seconds 5
if (!$(git config --global credential.helper) -eq "manager-core") {
    git config --global credential.helper manager-core
}
if (!($Env:GIT_SSH)) {
    Write-Verbose -Message "Setting GIT_SSH User Environment Variable"
    [System.Environment]::SetEnvironmentVariable('GIT_SSH', (Resolve-Path (scoop which ssh)), 'USER')
}
if ((Get-Service -Name ssh-agent).Status -ne "Running") {
    Start-Process -FilePath "PowerShell" -ArgumentList "Set-Service","ssh-agent","-StartupType","Manual" -Verb RunAs -Wait -WindowStyle Hidden
}

# Configure Aria2 Download Manager
Install-ScoopApp -Package "aria2"
if (!$(scoop config aria2-enabled) -eq $True) {
    scoop config aria2-enabled true
}
if (!$(scoop config aria2-warning-enabled) -eq $False) {
    scoop config aria2-warning-enabled false
}
if (!(Get-ScheduledTaskInfo -TaskName "Aria2RPC" -ErrorAction Ignore)) {
@'
$Action = New-ScheduledTaskAction -Execute $Env:UserProfile\scoop\apps\aria2\current\aria2c.exe -Argument "--enable-rpc --rpc-listen-all" -WorkingDirectory $Env:UserProfile\Downloads
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Principal = New-ScheduledTaskPrincipal -UserID "$Env:ComputerName\$Env:Username" -LogonType S4U
$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
Register-ScheduledTask -TaskName "Aria2RPC" -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings
'@ > $Env:Temp\aria2.ps1
    Start-Process -FilePath "PowerShell" -ArgumentList "$Env:Temp\aria2.ps1" -Verb RunAs -Wait #-WindowStyle Hidden
    Remove-Item -Path $Env:Temp\aria2.ps1 -Force
}

## Add Buckets
Enable-Bucket -Bucket "extras"
Enable-Bucket -Bucket "nerd-fonts"
Enable-Bucket -Bucket "java"
Enable-Bucket -Bucket "nirsoft"
scoop bucket add foosel https://github.com/foosel/scoop-bucket

# UNIX Tools
Write-Verbose -Message "Removing curl Alias..."
if (Get-Alias -Name curl -ErrorAction SilentlyContinue) {
    Remove-Item alias:curl
}
if (!($Env:TERM)) {
    Write-Verbose -Message "Setting TERM User Environment Variable"
    [System.Environment]::SetEnvironmentVariable("TERM", "xterm-256color", "USER")
}

# Check if Home Workstation
if ($(Read-Host -Prompt "Is this a workstation for Home use (y/n)?") -eq "y") {
    $HomeWorkstation = $True
} else {
    $HomeWorkstation = $False
}

# Home Workstation Configurations
if ($HomeWorkstation) {
    # Adding games bucket
    Enable-Bucket -Bucket "games"
    # Create $Env:UserProfile\bin, if not exist
    if (!(Test-Path -Path $Env:UserProfile\bin)) {
        Write-Verbose -Message "Creating bin directory in $Env:UserProfile"
        New-Item -Path $Env:UserProfile\bin -ItemType Directory | Out-Null
        #[System.Environment]::SetEnvironmentVariable("PATH", $Env:PATH + ";$Env:UserProfile\bin","USER")
    }
}

# Install Scoop Packages
$Scoop = @(
    "scoop-tray",
    "concfg",
    #"curl",
    #"busybox",
    #"fzf",
    #"neovim",
    "pshazz",
    "cacert",
    "colortool",
    #"sudo",
    #"openjdk",
    "icedtea-web",
    #"go",
    #"python",
    #"gpg",
    #"imgburn",
    #"paint.net",
    #"putty",
    #"winscp",
    #"spacesniffer",
    #"filebot",
    #"rufus",
    #"etcher",
    #"cpu-z",
    #"gpu-z",
    "ssd-z",
    #"hwmonitor",
    #"crystaldiskmark",
    "hotkeyslist",
    "open-log-viewer",
    "baretail",
    #"bleachbit",
    #"hosts-file-editor",
    "minio-client",
    "lessmsi",
    #"mqtt-explorer",
    "tftpd",
    "restic",
    "Hack-NF",
    "driverstoreexplorer",
    "sysinternals")#,"rktools2k3")
foreach ($item in $Scoop) {
    Install-ScoopApp -Package "$item"
}

# Install Scoop Packages, if Home Workstation
if ($HomeWorkstation) {
    Remove-Variable -Name "Scoop"
    $Scoop = @(
        "ffmpeg",
        "mpv",
        #"vlc",
        "lame",
        #"musicbee",
        #"mp3tag",
        #"mkvtoolnix",
        #"obs-studio",
        #"yt-dlp",
        #"ocenaudio",
        #"mediainfo",
        #"mediainfo-gui",
        "cdrtools",
        "cuetools",
        "betterjoy",
        "schismtracker")
    foreach ($item in $Scoop) {
        Install-ScoopApp -Package "$item"
    }
}

# Install WinGet Packages
$WinGet = @(
    #"Microsoft.dotNetFramework",
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
    "WinSCP.WinSCP",
    "Balena.Etcher",
    "CPUID.HWMonitor",
    "CrystalDewWorld.CrystalDiskMark",
    "BleachBit.BleachBit",
    #"TeamViewer.TeamViewer",
    "GnuPG.GnuPG",
    "LIGHTNINGUK.ImgBurn",
    "dotPDNLLC.paintdotnet",
    "UderzoSoftware.SpaceSniffer",
    "Rufus.Rufus",
    "scottlerch.hosts-file-editor",
    #"Minio.Client",
    "thomasnordquist.MQTT-Explorer",
    "jziolkowski.tdm",
    "HDDGURU.HDDRawCopyTool",
    "dnSpyEx.dnSpy",
    "JLC.EasyEDA",
    "Google.Chrome",
    "Lexikos.AutoHotkey",
    "SumatraPDF.SumatraPDF",
    "ScooterSoftware.BeyondCompare4",
    "Eassos.DiskGenius",
    "RevoUninstaller.RevoUninstaller",
    "ElaborateBytes.VirtualCloneDrive",
    "RARLab.WinRAR",
    "Piriform.Speccy",
    "Piriform.Defraggler",
    "Starship.Starship",
    "OliverBetz.ExifTool"
    )
foreach ($item in $WinGet) {
    Install-WinGetApp -PackageID "$item"
}

# Add Directories to User Path
#[System.Environment]::SetEnvironmentVariable("PATH", $Env:PATH + ";$Env:ProgramFiles\WinRAR","USER")

# Install WinGet Packages, if Home Workstation
if ($HomeWorkstation) {
    Remove-Variable -Name "WinGet"
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
    foreach ($item in $WinGet) {
        Install-WinGetApp -PackageID "$item"
    }
}

# Custom WinGet install for VSCode
winget install Microsoft.VisualStudioCode --override '/SILENT /mergetasks="!runcode,addcontextmenufiles,addcontextmenufolders"'

# Install Chocolatey Packages
$Choco = @(
    "syspin",
    "sd-card-formatter",
    "winimage",
    "winsetupfromusb",
    "fluidsynth"
)
foreach ($item in $Choco) {
    Install-ChocoApp -Package "$item"
}

# Install Steam Applications
if ($HomeWorkstation) {
    # Get Steam AppID's from https://steamdb.info/
    # https://developer.valvesoftware.com/wiki/Command_Line_Options#Steam_.28Windows.29
    $SteamDB = @(
        "1026460" #Lossless Scaling Demo,
        "431960"  #Wallpaper Engine,
        "388080"  #Borderless Gaming,
        "367670"  #Controller Companion,
        "227260"  #DisplayFusion,
        "274920"  #FaceRig
    )
    # Collect installed Steam AppID's
    $InstalledIDs = [System.Collections.ArrayList]::new()
    foreach ($item in (Get-ChildItem -Path "${Env:Programfiles(x86)}\Steam\steamapps\common\" -Filter "steam_appid.txt" -Recurse).VersionInfo.FileName) {
        [void]$InstalledIDs.Add((Get-Content -Path $item))
    }
    # Install Steam AppID, if not already installed
    foreach ($item in $SteamDB) {
        if ($item -ne $InstalledIDs) {
            Start-Process -FilePath ".\steam.exe" -ArgumentList "-applaunch","$item" -WorkingDirectory "${Env:Programfiles(x86)}\Steam\" -Wait
        }
    }
}

# Create Symbolic Links
## busybox.exe
sudo New-Item -ItemType SymbolicLink -Path "$(Split-Path -Path (Get-Command busybox*.exe).Source)\busybox.exe" -Target (Get-Command busybox*.exe).Source
## tdmgr.exe
sudo New-Item -ItemType SymbolicLink -Path "$(Split-Path -Path (Get-Command tdmgr*.exe).Source)\tdmgr.exe" -Target (Get-Command tdmgr*.exe).Source


# Install Custom Packages
# Instal RawWrite for Windows from Chrysocome
Install-CustomApp -URL "http://www.chrysocome.net/downloads/0d23e6a31f1d37850fc2040eec98e9f9/rawwritewin-0.7.zip" -Folder "RawWrite"
# Install Tasmota Device Manager from Github
#New-Item -Path "$Env:UserProfile\bin\TasmotaDM" -ItemType Directory | Out-Null
#Download-CustomApp -Link "https://github.com/jziolkowski/tdm/releases/download/v0.2.11/tdmgr_0.2.11.exe" -Folder "$Env:UserProfile\bin\TasmotaDM" | Out-Null
# Install HDD Raw Copy Tool from HDDGURU
#New-Item -Path "$Env:UserProfile\bin\HDDRawCopy" -ItemType Directory | Out-Null
#Download-CustomApp -Link "https://hddguru.com/software/HDD-Raw-Copy-Tool/HDDRawCopy1.10Portable.exe" -Folder "$Env:UserProfile\bin\HDDRawCopy" | Out-Null
# Install XVI32 from Christian Maas
Install-CustomApp -URL "http://www.handshake.de/user/chmaas/delphi/download/xvi32.zip" -Folder "XVI32"
# Install dnSpy from Github
#Install-CustomApp -URL "https://github.com/dnSpy/dnSpy/releases/download/v6.1.8/dnSpy-net-win64.zip" -Folder "dnSpy"
# Install ei.cfg Removal Utility from code.kliu.org
Install-CustomApp -URL "https://code.kliu.org/misc/winisoutils/eicfg_removal_utility.zip"  -Folder "ei.cfg-removal-utility"
# Install HSFExplorer from SourceForge
Install-CustomPackage -URL "https://downloads.sourceforge.net/project/catacombae/HFSExplorer/2021.10.9/hfsexplorer-2021.10.9-setup.exe"
# Install RipMe from Github
New-Item -Path "$Env:UserProfile\bin\RipMe" -ItemType Directory | Out-Null
Download-CustomApp -Link "https://github.com/RipMeApp/ripme/releases/download/1.7.95/ripme.jar" -Folder "$Env:UserProfile\bin\RipMe" | Out-Null
# Install EasyEDA Router from EasyEDA
Install-CustomApp -URL "https://image.easyeda.com/files/easyeda-router-windows-x64-v0.8.11.zip"

# Install Custom Packages for Home Workstations
if ($HomeWorkstation) {
    # Install CDMage from Major Geeks
    Install-CustomApp -URL "https://files1.majorgeeks.com/10afebdbffcd4742c81a3cb0f6ce4092156b4375/cddvd/CDmage1-01-5.exe" -Folder "CDMage"
    # Install ACiD View from SourceForge
    Install-CustomApp -URL "https://downloads.sourceforge.net/project/acidview6-win32/acidview6-win32/6.10/avw-610.zip" -Folder "ACiDView"
    # Install NohBoard from SourceForge
    Install-CustomApp -URL "https://downloads.sourceforge.net/project/nohboard/NohBoard-v0.17b.zip"
    # Install PSX2PSP from PSX-Place
    Install-CustomApp -URL "https://www.psx-place.com/resources/psx2psp.586/download?version=898"
    # Install CLRMamePro from EMULab
    Install-CustomPackage -URL "https://mamedev.emulab.it/clrmamepro/binaries/cmp4044c_64.exe"
    # Install Soundfont Midi Player from Falcosoft
    Install-CustomApp -URL "https://falcosoft.hu/midiplayer_60_x64.zip"
    # Install SkraperUI fro Skraper
    Install-CustomApp -URL "https://www.skraper.net/download/beta/Skraper-1.1.1.7z" -Folder "SkraperUI"
    # Install WinHIIP from PSX-Place
    Install-CustomApp -URL "https://www.psx-place.com/resources/obsolete-winhiip-by-gadgetfreak.666/download?version=1066" -Folder "WinHIIP"
    # Install WinBin2Iso from Major Geeks
    Install-CustomApp -URL "https://www.softwareok.com/Download/WinBin2Iso.zip" -Folder "WinBin2Iso"
    # Install ArchiSteamFarm from Github
    Install-CustomApp -URL "https://github.com/JustArchiNET/ArchiSteamFarm/releases/download/5.2.4.2/ASF-win-x64.zip" -Folder "ArchiSteamFarm2"
    # Install TwilightMenu++ Boxart Downloader from Github
    Install-CustomApp -URL "https://github.com/KirovAir/TwilightBoxart/releases/download/0.7/TwilightBoxart-Windows-UX.zip" -Folder "TwilightMenuBoxArt"
    # Install ISO Toolkit from Major Geeks
    New-Item -Path "$Env:UserProfile\bin\ISOToolkit" -ItemType Directory | Out-Null
    Download-CustomApp -Link "https://files1.majorgeeks.com/10afebdbffcd4742c81a3cb0f6ce4092156b4375/cddvd/ISOToolKit.exe" -Folder "$Env:UserProfile\bin\ISOToolkit" | Out-Null
    # Install binmerge from Github
    Install-CustomApp -URL "https://github.com/putnam/binmerge/releases/download/1.0.1/binmerge-1.0.1-win64.zip"
    # Install PPF-o-Matic from PSX-Place
    Install-CustomApp -URL "https://www.psx-place.com/resources/ppf-o-matic.507/download?version=717" -Folder "ppf-o-matic"
    # Install MBCord from Github
    Install-CustomApp -URL "https://github.com/oonqt/MBCord/releases/download/2.3.13/MBCord-win32-x64.zip" -Folder "MBCord"
    # Install bchunk from Github
    Install-CustomApp -URL "https://github.com/extramaster/bchunk/releases/download/v1.2.1_repub.1/bchunk.v1.2.1_repub.1.zip"
    # Install CHDMan from MAMEDEV
    $Package = Download-CustomApp -Link "https://github.com/mamedev/mame/releases/download/mame0242/mame0242b_64bit.exe" -Folder "$Env:UserProfile\Downloads\"
    7z e -o"$Env:UserProfile\bin\" -y "$Env:UserProfile\Downloads\$Package" chdman.exe | Out-Null
    Remove-Item -Path "$Env:UserProfile\Downloads\$Package"
    # Install ExifTool from ExifTool.org
    #Install-CustomApp -URL "https://www.exiftool.org/exiftool-12.41.zip"
    #Move-Item -Path "$Env:UserProfile\bin\exiftool*.exe" -Destination "$Env:UserProfile\bin\exiftool.exe"
    # Install OpenMPT123 from OpenMPT
    Install-CustomApp -URL "https://lib.openmpt.org/files/libopenmpt/bin/libopenmpt-0.6.3+release.bin.windows.zip" -Folder "OpenMPT123"
    # Install WildMIDI from Github
    Install-CustomApp -URL "https://github.com/Mindwerks/wildmidi/releases/download/wildmidi-0.4.4/wildmidi-0.4.4-win64.zip"
    Move-Item -Path "$Env:UserProfile\bin\wildmidi*\" -Destination "$Env:UserProfile\bin\WildMIDI\"
    # Install Aaru from Github
    Install-CustomApp -URL "https://github.com/aaru-dps/Aaru/releases/download/v5.3.1/aaru-5.3.1_windows_x64.zip" -Folder "Aaru"
}

# Create scoop-tray shortcut in shell:startup
if (!(Test-Path -Path "$Env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\scoop-tray.lnk" -PathType Leaf)) {
    Write-Verbose -Message "Create scoop-tray shortcut in shell:startup..."
    $WSHShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WSHShell.CreateShortcut("$Env:AppData\Microsoft\Windows\Start Menu\Programs\Startup\scoop-tray.lnk")
    $Shortcut.TargetPath = "$Env:UserProfile\scoop\apps\scoop-tray\current\scoop-tray.bat"
    $Shortcut.WindowStyle = 7
    $Shortcut.IconLocation = "%USERPROFILE%\scoop\apps\scoop-tray\current\updates-available.ico"
    $Shortcut.Description = "scoop-tray.bat"
    $Shortcut.WorkingDirectory = Split-Path "$Env:UserProfile\scoop\apps\scoop-tray\current\scoop-tray.bat" -Resolve
    $Shortcut.Save()
}

# Configure GO Environment
if (!(Test-Path -Path "$Env:UserProfile\go\" -PathType Container)) {
    Write-Verbose -Message "Configuring GO Environment..."
    New-Item -Path "${Env:UserProfile}\go" -ItemType Directory | Out-Null
    [System.Environment]::SetEnvironmentVariable('GOPATH', "${Env:UserProfile}\go", 'USER')
}

# Customize DOS/PowerShell Environment
Write-Verbose -Message "Customize DOS/PowerShell Environment..."
if ((Get-ItemProperty -Path "HKCU:\Software\Microsoft\Command Processor").AutoRun -eq $Null) {
    Start-Process -FilePath "cmd" -ArgumentList "/c","clink","autorun","install" -Wait -WindowStyle Hidden
}
Start-Process -FilePath "cmd" -ArgumentList "/c","concfg","import","solarized-dark" -Verb RunAs -Wait

# Install Visual Studio Code Integrations
#if (!(Get-Item -Path "HKCU:\Software\Classes\Directory\shell\Open with &Code" -ErrorAction Ignore)) {
#    Write-Verbose -Message "Install Visual Studio Code Integrations..."
#    Start-Process -FilePath "cmd" -ArgumentList "/c","reg","import","%UserProfile%\scoop\apps\vscode\current\install-context.reg" -Verb RunAs -Wait -WindowStyle Hidden
#    Start-Process -FilePath "cmd" -ArgumentList "/c","reg","import","%UserProfile%\scoop\apps\vscode\current\nstall-associations.reg" -Verb RunAs -Wait -WindowStyle Hidden
#}

# Pin Run to Taskbar
#Start-Process -FilePath "PowerShell" -ArgumentList "syspin","'$Env:AppData\Microsoft\Windows\Start Menu\Programs\System Tools\Run.lnk'","c:5386" -Wait -NoNewWindow
# Pin Google Chrome to Taskbar
Write-Verbose -Message "Pin Google Chrome to Taskbar..."
Start-Process -FilePath "PowerShell" -ArgumentList "syspin","'$Env:ProgramData\Microsoft\Windows\Start Menu\Programs\Google Chrome.lnk'","c:5386" -Wait -NoNewWindow

# Install my PowerShell dot files
if (!(Test-Path -Path "$Env:UserProfile\dotposh" -PathType Container)) {
    Write-Verbose -Message "Install my PowerShell dot files..."
    Start-Process -FilePath "PowerShell" -ArgumentList "git","clone","https://github.com/mikepruett3/dotposh.git","$Env:UserProfile\dotposh" -Wait -NoNewWindow
@'
New-Item -Path $Env:UserProfile\Documents\WindowsPowerShell -ItemType Directory -ErrorAction Ignore
Remove-Item -Path $Env:UserProfile\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 -Force
New-Item -Path $Env:UserProfile\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 -ItemType SymbolicLink -Target $Env:UserProfile\dotposh\profile.ps1
'@ > $Env:Temp\dotposh.ps1
    Start-Process -FilePath "PowerShell" -ArgumentList "$Env:Temp\dotposh.ps1" -Verb RunAs -Wait -WindowStyle Hidden
    Remove-Item -Path $Env:Temp\dotposh.ps1 -Force
@'
cd $Env:UserProfile\dotposh
git submodule init
git submodule update
'@ > $Env:Temp\submodule.ps1
    Start-Process -FilePath "PowerShell" -ArgumentList "$Env:Temp\submodule.ps1" -Wait -NoNewWindow
    Remove-Item -Path $Env:Temp\submodule.ps1 -Force
}

# Pin PowerShell to Taskbar
Write-Verbose -Message "Pin PowerShell to Taskbar..."
Start-Process -FilePath "PowerShell" -ArgumentList "syspin","'$Env:AppData\Microsoft\Windows\Start Menu\Programs\Windows PowerShell\Windows PowerShell.lnk'","c:5386" -Wait -NoNewWindow

# Install PowerShell 7
$PS7 = winget list --exact -q Microsoft.PowerShell
if (!$PS7) {
    Write-Verbose -Message "Installing PowerShell 7..."
@'
iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI -Quiet"
'@ > $Env:Temp\ps7.ps1
    Start-Process -FilePath "PowerShell" -ArgumentList "$Env:Temp\ps7.ps1" -Verb RunAs -Wait -WindowStyle Hidden
    Remove-Item -Path $Env:Temp\ps7.ps1 -Force
}
# Pin PowerShell 7 to Taskbar
Write-Verbose -Message "Pin PowerShell 7 to Taskbar..."
Start-Process -FilePath "PowerShell" -ArgumentList "syspin","'$Env:ProgramData\Microsoft\Windows\Start Menu\Programs\PowerShell\PowerShell 7 (x64).lnk'","c:5386" -Wait -NoNewWindow

# Remove unused Packages/Applications
Write-Verbose -Message "Removing Unused Applications..."
$RemoveApps = @(
    "*3DPrint*",
    "Microsoft.MixedReality.Portal")
foreach ($item in $RemoveApps) {
    Remove-InstalledApp -Package $item
}

# Install Windows SubSystems for Linux
$wslInstalled = Get-Command "wsl" -CommandType Application -ErrorAction Ignore
if (!$wslInstalled) {
    Write-Verbose -Message "Installing Windows SubSystems for Linux..."
    Start-Process -FilePath "PowerShell" -ArgumentList "wsl","--install" -Verb RunAs -Wait -WindowStyle Hidden
}
Install-WinGetApp -PackageID Canonical.Ubuntu.2204
Write-Output "Install complete! Please reboot your machine/worksation!"
Start-Sleep -Seconds 10
