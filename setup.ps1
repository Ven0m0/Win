If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
}

# Enable ANSI Escape Sequences
$null = reg add "HKCU\CONSOLE" /v "VirtualTerminalLevel" /t REG_DWORD /d "1" /f 2>&1

# Set location to user profile
Set-Location -Path $env:USERPROFILE -ErrorAction SilentlyContinue

Write-Host "Winget updates..." -ForegroundColor Cyan
winget upgrade -r -u -h --accept-package-agreements --accept-source-agreements --force --purge --disable-interactivity --nowarn --no-proxy

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

Write-Host "Installing Media codecs..." -ForegroundColor Cyan
winget install --id=CodecGuide.K-LiteCodecPack.Standard -h

Write-Host "Installing Software..." -ForegroundColor Cyan
winget install --id=AutoHotkey.AutoHotkey -e -h
winget install --id=VideoLAN.VLC -e -h
winget install --id=GIMP.GIMP -e -h
winget install --id=Greenshot.Greenshot -e -h
winget install --id=7zip.7zip -e -h

Write-Host "Installing Code environment..." -ForegroundColor Cyan
winget install --id=Notepad++.Notepad++ -e -h
winget install --id=VSCodium.VSCodium -e -h
winget install Microsoft.Edit -h
winget install Git.Git -h
winget install yadm -h
winget install Microsoft.PowerShell -h
winget install Microsoft.WindowsTerminal -h
winget install --id=Rustlang.Rust.MSVC -e -h

Write-Host "Installing Browser..." -ForegroundColor Cyan
winget install --id=Ablaze.Floorp -e -h

Write-Host "Game setup..." -ForegroundColor Cyan
winget install --id=HeroicGamesLauncher.HeroicGamesLauncher -e -h
winget install --id=Valve.Steam -e -h
winget install --id=smartfrigde.Legcord -e -h

Write-Host "Tuning..." -ForegroundColor Cyan
winget install --id=Guru3D.Afterburner.Beta -e -h
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

Write-Host "Installing Chocolatey..." -ForegroundColor Cyan
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
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

# Open disk cleanup
Start-Process cleanmgr.exe

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

Write-Host "Setup completed successfully!" -ForegroundColor Green
exit 0
