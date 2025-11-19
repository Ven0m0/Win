If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
}

# Enable ANSI Escape Sequences
$null = reg add "HKCU\CONSOLE" /v "VirtualTerminalLevel" /t REG_DWORD /d "1" /f 2>&1

# Set location to user profile
Set-Location -Path $env:USERPROFILE -ErrorAction SilentlyContinue

Write-Host "Winget updates..." -ForegroundColor Cyan
winget upgrade -r -u -h --accept-package-agreements --accept-source-agreements --force --purge --disable-interactivity --nowarn --no-proxy --include-unknown 

Write-Host "Installing VCRedist..." -ForegroundColor Cyan
winget install --id=Microsoft.VCRedist.2015+.x64 -e -h
winget install --id=Microsoft.VCRedist.2013.x64 -e -h

Write-Host "Installing DotNet runtimes..." -ForegroundColor Cyan
winget install --id=Microsoft.DotNet.DesktopRuntime.9 -h
winget install --id=Microsoft.DotNet.DesktopRuntime.8 -h
winget install --id=Microsoft.DotNet.DesktopRuntime.7 -h

Write-Host "Installing DirectX..." -ForegroundColor Cyan
winget install --id=Microsoft.DirectX -e -h

Write-Host "Installing Vulkan runtime..." -ForegroundColor Cyan
winget install --id=KhronosGroup.VulkanRT -e -h
winget install --id=Microsoft.XNARedist -e -h

Write-Host "Installing Java..." -ForegroundColor Cyan
winget install --id=Oracle.JavaRuntimeEnvironment -e -h
winget install --id=EclipseAdoptium.Temurin.21.JRE -e -h
winget install --id=EclipseAdoptium.Temurin.25.JRE -e -h

Write-Host "Installing toolchains..." -ForegroundColor Cyan
winget install --id=MartinStorsjo.LLVM-MinGW.UCRT -e -h
winget install --id=Rustlang.Rust.MSVC -e -h
winget install --id=astral-sh.uv -e -h && uv python install
winget install --id=Oven-sh.Bun -e -h
winget install --id=oxc-project.oxlint -e -h
winget install --id=BiomeJS.Biome -e -h
winget install --id=koalaman.shellcheck -e -h
winget install --id=ast-grep.ast-grep -e -h
winget install --id=SQLite.SQLite -e -h

Write-Host "Installing Media codecs..." -ForegroundColor Cyan
winget install --id=CodecGuide.K-LiteCodecPack.Basic -e -h

Write-Host "Installing Software..." -ForegroundColor Cyan
winget install --id=Microsoft.Sysinternals.Autoruns -e -h
winget install --id=Sysinternals.Autologon -e -h
winget install --id=AutoHotkey.AutoHotkey -e -h
winget install --id=UPX.UPX -e -h
winget install --id=VideoLAN.VLC -e -h
winget install --id=GIMP.GIMP -e -h
winget install --id=tannerhelland.PhotoDemon -e -h
winget install --id=Greenshot.Greenshot -e -h
winget install "FFmpeg (Essentials Build)" -h
winget install CodeF0x.ffzap -h
winget install PaulPacifico.ShutterEncoder -h
winget install --id=eibol.FFmpegBatchAVConverter -e -h
winget install --id=HandBrake.HandBrake -e -h
winget install --id=XnSoft.XnViewMP -e -h
winget install --id=XnSoft.XnConvert -e -h
winget install --id=Avidemux.Avidemux -e -h
winget install --id=Nikkho.FileOptimizer -e -h
winget install --id=xanderfrangos.crushee -e -h
winget install --id=SaeraSoft.CaesiumImageCompressor -e -h
winget install --id=OptiPNG.OptiPNG -e -h
winget install --id=fhanau.Efficient-Compression-Tool -e -h
winget install --id=Kornelski.DSSIM -e -h
winget install --id=chaiNNer-org.chaiNNer -e -h
winget install --id=OBSProject.OBSStudio -e -h
winget install --id=Meltytech.Shotcut -e -h
winget install --id=7zip.7zip -e -h
winget install --id=Meta.Zstandard -e -h
winget install --id=IridiumIO.CompactGUI -e -h
winget install --id=aria2.aria2 -e -h
winget install --id=GiantPinkRobots.Varia -e -h
winget install --id=aandrew-me.ytDownloader -e -h
winget install --id=DevToys-app.DevToys -e -h
winget install --id=TimVisee.ffsend -e -h
winget install --id=Intel.PresentMon.Beta -e -h
winget install --id=WindowsPostInstallWizard.UniversalSilentSwitchFinder -e -h

Write-Host "Installing Updaters..." -ForegroundColor Cyan
winget install jdx.mise -h
# scoop install mise
# choco install mise
winget install --id=topgrade-rs.topgrade -e -h
winget install --id=MartiCliment.UniGetUI -e -h
winget install --id chocolatey.chocolatey --source winget -h
winget install --id=Chocolatey.ChocolateyGUI -e -h
winget install --id=GorillaDevs.Ferium -e -h

Write-Host "Installing Code environment..." -ForegroundColor Cyan
winget install --id=Notepad++.Notepad++ -e -h
winget install --id=VSCodium.VSCodium -e -h
winget install Microsoft.Edit -h
winget install Git.Git -h
winget install --id=GitHub.cli -e -h
winget install --id=evilmartians.lefthook -e -h
winget install yadm -h
winget install --id=MathiasCodes.Winstow  -e -h
winget install Microsoft.PowerShell -h
winget install Microsoft.WindowsTerminal -h
winget install --id=CodeSector.TeraCopy -e -h

Write-Host "Installing cli-tools..." -ForegroundColor Cyan
winget install --id=eza-community.eza -e -h
winget install --id=BurntSushi.ripgrep.MSVC  -e -h
winget install --id=Genivia.ugrep -e -h
winget install --id=sharkdp.fd -e -h
winget install --id=sharkdp.bat -e -h
winget install --id=dandavison.delta -e -h
winget install --id=Starship.Starship -e -h
winget install --id=JanDeDobbeleer.OhMyPosh -e -h

Write-Host "Installing Browser..." -ForegroundColor Cyan
winget install --id=Ablaze.Floorp -e -h

Write-Host "Game setup..." -ForegroundColor Cyan
winget install --id=HeroicGamesLauncher.HeroicGamesLauncher -e -h
winget install --id=Valve.Steam -e -h
winget install --id=MoonlightGameStreamingProject.Moonlight -e -h
winget install --id=smartfrigde.Legcord -e -h
winget install --id=PrismLauncher.PrismLauncher -e -h
winget install --id=Cemu.Cemu -e -h
winget install --id=Modrinth.ModrinthApp -e -h
winget install --id=Playnite.Playnite -e -h
winget install --id=DevelopedMethods.playit -e -h

Write-Host "Tuning..." -ForegroundColor Cyan
winget install --id=Guru3D.Afterburner.Beta -e -h
winget install --id=BleachBit.BleachBit -e -h
winget install --id=qarmin.czkawka.gui -e -h
winget install --id=EditorConfig-Checker.EditorConfig-Checker -e -h
winget install --id=SingularLabs.CCEnhancer -e -h
winget install --id=szTheory.exifcleaner -e -h
winget install --id=RevoUninstaller.RevoUninstaller -e -h
winget install --id=Klocman.BulkCrapUninstaller -e -h
winget install --id=WinDirStat.WinDirStat -e -h

Write-Host "Drivers..." -ForegroundColor Cyan
winget install --id=GlennDelahoy.SnappyDriverInstallerOrigin -e -h
winget install --id=SteelSeries.SteelSeriesEngine -e -h
# winget install --id=SteelSeries.GG -e -h
winget install --id=ToastyX.CustomResolutionUtility -e -h
winget install --id=TechPowerUp.NVCleanstall -e -h
winget install --id=Wagnardsoft.DisplayDriverUninstaller -e -h
winget install --id=ViGEm.ViGEmBus -e -h
winget install --id=lostindark.DriverStoreExplorer -e -h
winget install --id=Microsoft.EdgeDriver -e -h
winget install --id=Recol.DLSSUpdater -e -h
irm http://offset-power.net/GMKDriver/setup.exe -outfile 'gmk.exe'
.\gmk.exe | Out-Null

Write-Host "Misc..." -ForegroundColor Cyan
winget install --id=Nlitesoft.NTLite -e -h
winget install --id=CodingWondersSoftware.DISMTools.Stable  -e -h
#winget install --id=Microsoft.OneDrive -e -h
winget install --id=Rclone.Rclone -e -h
winget install --id=Upscayl.Upscayl -e -h
winget install --id=Universal-Debloater-Alliance.uad-ng -e -h

Start-Sleep -Seconds 1

# Install HEVC video extension needed for AMD recording
Get-AppXPackage -AllUsers *Microsoft.HEVCVideoExtension* | ForEach-Object {
    Add-AppxPackage -DisableDevelopmentMode -Register -ErrorAction SilentlyContinue "$($_.InstallLocation)\AppXManifest.xml"
}
Start-Sleep -Seconds 2

# Install HEIF image extension needed for some files
Get-AppXPackage -AllUsers *Microsoft.HEIFImageExtension* | ForEach-Object {
    Add-AppxPackage -DisableDevelopmentMode -Register -ErrorAction SilentlyContinue "$($_.InstallLocation)\AppXManifest.xml"
}

Write-Host "Installing Scoop..." -ForegroundColor Cyan
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
irm get.scoop.sh -outfile 'install.ps1'
.\install.ps1 -NoProxy | Out-Null
Start-Sleep -Seconds 1
scoop bucket add extras
Start-Sleep -Seconds 1

Write-Host "Cleaning Firefox..." -ForegroundColor Cyan
$firefoxFiles = @(
    "$env:ProgramFiles\Mozilla Firefox\crashreporter.exe",
    "$env:ProgramFiles\Mozilla Firefox\browser\features\pictureinpicture@mozilla.org.xpi",
    "$env:ProgramFiles\Mozilla Firefox\browser\features\screenshots@mozilla.org.xpi",
    "$env:ProgramFiles\Mozilla Firefox\browser\VisualElements\PrivateBrowsing_150.png",
    "$env:ProgramFiles\Mozilla Firefox\browser\VisualElements\VisualElements_150.png"
)
foreach ($file in $firefoxFiles) {
    Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
}
Start-Sleep -Seconds 1

Write-Host "Cleanup..." -ForegroundColor Cyan
Dism /Cleanup-Mountpoints
DISM /CleanUp-Wim
#Remove event logs.
wevtutil.exe cl Application
wevtutil.exe cl System
#Remove all temporary files.
del /f /s /q %tmp%\*.*
del /f /s /q %temp%\*.*
del /f /s /q %systemdrive%\*.tmp
del /f /s /q %systemdrive%\*._mp
del /f /s /q %windir%\temp\*.*
del /f /s /q %AppData%\temp\*.*
del /f /s /q %HomePath%\AppData\LocalLow\Temp\*.*
# Remove log, trace, old and backup files.
del /f /s /q %systemdrive%\*.log
del /f /s /q %systemdrive%\*.old
del /f /s /q C:\*.old
del /f /s /q %systemdrive%\*.trace
del /f /s /q %windir%\*.bak
# Remove restored files created by an checkdisk utility.
del /f /s /q %systemdrive%\*.chk
#Remove old content from recycle bin.
del /f /s /q %systemdrive%\recycled\*.*
# Remove powercfg energy report.
del /f /s /q %windir%\system32\energy-report.html
#Remove extracted, not needed files of driver installators.
del /f /s /q %systemdrive%\AMD\*.*
del /f /s /q %systemdrive%\NVIDIA\*.*
del /f /s /q %systemdrive%\INTEL\*.*
# Repair
DISM /Online /Cleanup-Image /RestoreHealth
sfc /scannow
ipconfig /release
ipconfig /renew
ipconfig /flushdns
netsh winsock reset
netsh int ip reset
chkdsk /scan

# Clear temp folders
Remove-Item -Path "$env:USERPROFILE\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:WINDIR\TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:SystemDrive\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
# Clear other temporary locations
Remove-Item -Path "$env:WINDIR\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:WINDIR\Logs\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:USERPROFILE\AppData\Local\cache\*" -Recurse -Force -ErrorAction SilentlyContinue

set ODrive=%userprofile%\OneDrive
cd /d %~dp0
del /s /f /q %ODrive%\.bak
del /s /f /q %ODrive%\*LOG
del /s /f /q %ODrive%\*.old
del /s /f /q %ODrive%\*.trace
del /s /f /q %ODrive%\*.tmp
rmdir /s /q "%ODrive%\Backup\Program\Win\Tools\NTLite\Cache"
rmdir /s /q "%ODrive%\Backup\Program\Driver\Updates\Snappy Driver Installer Origin\logs"
del /s /f /q "%ODrive%\Backup\Program\Driver\Updates\Snappy Driver Installer Origin\drivers"
# Remove useless scaling factors
for /r "%ODrive%" %%f in (chrome_200_percent.pak) do del /f /q "%%f"
for /r "%ODrive%" %%f in (chrome_300_percent.pak) do del /f /q "%%f"
for /r "%ODrive%" %%f in (chrome_400_percent.pak) do del /f /q "%%f"

# Open disk cleanup
# Start-Process cleanmgr.exe
start cmd.exe /c Cleanmgr /sageset:65535 & Cleanmgr /sagerun:6553

# Msizap TODO: get msizap binary
msizap G!

# Clear root drive garbage files
$extensions = @('bat', 'cmd', 'txt', 'log', 'jpg', 'jpeg', 'tmp', 'temp', 'bak', 'backup', 'exe')
foreach ($ext in $extensions) {
    Remove-Item -Path "$env:SystemDrive\*.$ext" -Force -ErrorAction SilentlyContinue
}

# Clear additional unneeded files from NVIDIA driver installs
$nvidiaPaths = @(
    "$env:ProgramFiles\Nvidia Corporation\Installer2",
    "$env:ProgramFiles\NVIDIA Corporation\Installer",
    "$env:ProgramFiles\NVIDIA Corporation\Installer2",
    "${env:ProgramFiles(x86)}\NVIDIA Corporation\Installer",
    "${env:ProgramFiles(x86)}\NVIDIA Corporation\Installer2",
    "$env:ProgramData\NVIDIA Corporation\Downloader",
    "$env:ProgramData\NVIDIA\Downloader"
)
foreach ($path in $nvidiaPaths) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}
# Remove NVIDIA NetService executables
if (Test-Path "$env:ALLUSERSPROFILE\NVIDIA Corporation\NetService") {
    Remove-Item -Path "$env:ALLUSERSPROFILE\NVIDIA Corporation\NetService\*.exe" -Force -ErrorAction SilentlyContinue
}
# Remove the Office installation cache (usually around ~1.5 GB)
if (Test-Path "$env:SystemDrive\MSOCache") {
    Remove-Item -Path "$env:SystemDrive\MSOCache" -Recurse -Force -ErrorAction SilentlyContinue
}
# Remove the Windows installation cache (can be up to 1.0 GB)
if (Test-Path "$env:SystemDrive\i386") {
    Remove-Item -Path "$env:SystemDrive\i386" -Recurse -Force -ErrorAction SilentlyContinue
}
# Empty all recycle bins
$recyclePaths = @(
    "$env:SystemDrive\RECYCLER",
    "$env:SystemDrive\`$Recycle.Bin"
)
foreach ($path in $recyclePaths) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}
# Clear MUI cache
reg delete "HKCU\SOFTWARE\Classes\Local Settings\Muicache" /f 2>&1 | Out-Null
# Clear queued and archived Windows Error Reporting (WER) reports
$werPaths = @(
    "$env:ALLUSERSPROFILE\Microsoft\Windows\WER\ReportArchive",
    "$env:ALLUSERSPROFILE\Microsoft\Windows\WER\ReportQueue"
)
foreach ($path in $werPaths) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}
# Clear Windows Defender Scan Results
$defenderPaths = @(
    "$env:ALLUSERSPROFILE\Microsoft\Windows Defender\Scans\History\Results\Quick",
    "$env:ALLUSERSPROFILE\Microsoft\Windows Defender\Scans\History\Results\Resource"
)
foreach ($path in $defenderPaths) {
    if (Test-Path $path) {
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}
# Clear Windows Search Temp Data
if (Test-Path "$env:ALLUSERSPROFILE\Microsoft\Search\Data\Temp") {
    Remove-Item -Path "$env:ALLUSERSPROFILE\Microsoft\Search\Data\Temp" -Recurse -Force -ErrorAction SilentlyContinue
}
# Windows update logs & built-in backgrounds
$winFiles = @('*.log', '*.txt', '*.bmp', '*.tmp')
foreach ($pattern in $winFiles) {
    Remove-Item -Path "$env:WINDIR\$pattern" -Force -ErrorAction SilentlyContinue
}
# Remove Dell wallpapers
if (Test-Path "$env:WINDIR\Web\Wallpaper\Dell") {
    Remove-Item -Path "$env:WINDIR\Web\Wallpaper\Dell" -Recurse -Force -ErrorAction SilentlyContinue
}
# Windows CBS logs
Remove-Item -Path "$env:WINDIR\logs\CBS\*" -Force -ErrorAction SilentlyContinue 

# Configure compression settings
$null = reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\SideBySide\Configuration" /v "DisableResetbase" /t REG_DWORD /d "0" /f 2>&1
$null = reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v "NtfsDisableCompression" /t REG_DWORD /d "0" /f 2>&1
$null = reg add "HKLM\SYSTEM\CurrentControlSet\Policies" /v "NtfsDisableCompression" /t REG_DWORD /d "0" /f 2>&1
fsutil behavior set disablecompression 0
Dism /Online /Cleanup-Image /StartComponentCleanup /ResetBase

# Final updates
winget upgrade -h -r -u --accept-package-agreements --accept-source-agreements  --include-unknown --force --purge --disable-interactivity --nowarn --no-proxy
scoop update -a
choco upgrade all -y
pip freeze > requirements.txt
pip install -r requirements.txt --upgrade

Write-Host "Setup completed successfully!" -ForegroundColor Green
exit 0
