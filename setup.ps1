If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit	
}
# Enable ANSI Escape Sequences
reg add "HKCU\CONSOLE" /v "VirtualTerminalLevel" /t REG_DWORD /d "1" /f

cd /d %userprofile%

echo Winget updates...
winget upgrade -r -u -h --accept-package-agreements --accept-source-agreements --force --purge --disable-interactivity --nowarn --no-proxy

echo Installing VCRedist...
winget install --id=Microsoft.VCRedist.2015+.x64 -e -h && winget install --id=Microsoft.VCRedist.2013.x64 -e -h
echo Installing DotNet runtimes...
winget install --id=Microsoft.DotNet.DesktopRuntime.9 -h && winget install --id=Microsoft.DotNet.DesktopRuntime.8 -h && winget install --id=Microsoft.DotNet.DesktopRuntime.7 -h
echo Installing DirectX...
winget install --id=Microsoft.DirectX -e -h
echo Installing Vulkan runtime...
winget install --id=KhronosGroup.VulkanRT -e -h && winget install --id=Microsoft.XNARedist -e -h
echo Installing Java...
winget install --id=Oracle.JavaRuntimeEnvironment -e -h
echo Installing Media codecs...
winget install --id=CodecGuide.K-LiteCodecPack.Standard -h
echo Installing Software...
winget install --id=AutoHotkey.AutoHotkey -e -h
winget install --id=VideoLAN.VLC -e -h
winget install --id=GIMP.GIMP -e -h
winget install --id=Greenshot.Greenshot -e -h
winget install --id=7zip.7zip -e -h

echo Installing editors...
winget install --id=Notepad++.Notepad++ -e -h
winget install Microsoft.VisualStudioCode -h
winget install Microsoft.Edit -h

echo Installing Browser...
winget install --id=Mozilla.Firefox -e -h

echo Game setup...
winget install --id=EpicGames.EpicGamesLauncher -e -h && winget install --id=Valve.Steam -e -h
winget install --id=Discord.Discord -e -h

echo Tuning...
winget install --id=Guru3D.Afterburner.Beta -e -h
timeout 1

# install hevc video extension needed for amd recording
Get-AppXPackage -AllUsers *Microsoft.HEVCVideoExtension* | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register -ErrorAction SilentlyContinue "$($_.InstallLocation)\AppXManifest.xml"}
Timeout /T 2 | Out-Null
# install heif image extension needed for some files
Get-AppXPackage -AllUsers *Microsoft.HEIFImageExtension* | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register -ErrorAction SilentlyContinue "$($_.InstallLocation)\AppXManifest.xml"}

echo Installing Chocolatey...
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]#SecurityProtocol = [System.Net.ServicePointManager]#SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
timeout 1

echo Cleaning firefox...
del /f /q "%ProgramFiles%\Mozilla Firefox\crashreporter.exe" 
del /f /q "%ProgramFiles%\Mozilla Firefox\browser\features\pictureinpicture@mozilla.org.xpi"
del /f /q "%ProgramFiles%\Mozilla Firefox\browser\features\screenshots@mozilla.org.xpi"
del /f /q "%ProgramFiles%\Mozilla Firefox\browser\VisualElements\PrivateBrowsing_150.png"
del /f /q "%ProgramFiles%\Mozilla Firefox\browser\VisualElements\VisualElements_150.png"
timeout 1

echo Cleanup...
Dism /Cleanup-Mountpoints
DISM /CleanUp-Wim
DISM Online /Cleanup-Image /RestoreHealth
sfc /scannow
ipconfig /release                          
ipconfig /renew                           
ipconfig /flushdns                        
netsh winsock reset                        
netsh int ip reset 
chkdsk /scan

# clear %temp% folder
Remove-Item -Path "$env:USERPROFILE\AppData\Local\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item -Path "$env:WINDIR\TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item -Path "$env:SystemDrive\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
# Other
Remove-Item -Path "$env:WINDIR\Prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item -Path "$env:WINDIR\Logs\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
Remove-Item -Path "$env:USERPROFILE\AppData\Local\cache\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
# open disk cleanup
Start-Process cleanmgr.exe

# Root drive garbage
for %%i in (bat,cmd,txt,log,jpg,jpeg,tmp,temp,bak,backup,exe) do (
	del /F /Q "%SystemDrive%\*.%%i" 
)
# JOB: Clear additional unneeded files from NVIDIA driver installs
if exist "%ProgramFiles%\Nvidia Corporation\Installer2" rmdir /s /q "%ProgramFiles%\Nvidia Corporation\Installer2"
if exist "%ALLUSERSPROFILE%\NVIDIA Corporation\NetService" del /f /q "%ALLUSERSPROFILE%\NVIDIA Corporation\NetService\*.exe"
# JOB: Remove the Office installation cache. Usually around ~1.5 GB
if exist %SystemDrive%\MSOCache rmdir /S /Q %SystemDrive%\MSOCache
# JOB: Remove the Windows installation cache. Can be up to 1.0 GB
if exist %SystemDrive%\i386 rmdir /S /Q %SystemDrive%\i386
# JOB: Empty all recycle bins on Windows 5.1 (XP/2k3) and 6.x (Vista and up) systems
if exist %SystemDrive%\RECYCLER rmdir /s /q %SystemDrive%\RECYCLER
if exist %SystemDrive%\$Recycle.Bin rmdir /s /q %SystemDrive%\$Recycle.Bin
# JOB: Clear MUI cache
%REG% delete "HKCU\SOFTWARE\Classes\Local Settings\Muicache" /f
# JOB: Clear queued and archived Windows Error Reporting (WER) reports
echo. >> %LOGPATH%\%LOGFILE%
if exist "%ALLUSERSPROFILE%\Microsoft\Windows\WER\ReportArchive" rmdir /s /q "%ALLUSERSPROFILE%\Microsoft\Windows\WER\ReportArchive"
if exist "%ALLUSERSPROFILE%\Microsoft\Windows\WER\ReportQueue" rmdir /s /q "%ALLUSERSPROFILE%\Microsoft\Windows\WER\ReportQueue"
# JOB: Clear Windows Defender Scan Results
if exist "%ALLUSERSPROFILE%\Microsoft\Windows Defender\Scans\History\Results\Quick" rmdir /s /q "%ALLUSERSPROFILE%\Microsoft\Windows Defender\Scans\History\Results\Quick"
if exist "%ALLUSERSPROFILE%\Microsoft\Windows Defender\Scans\History\Results\Resource" rmdir /s /q "%ALLUSERSPROFILE%\Microsoft\Windows Defender\Scans\History\Results\Resource"
# JOB: Clear Windows Search Temp Data
if exist "%ALLUSERSPROFILE%\Microsoft\Search\Data\Temp" rmdir /s /q "%ALLUSERSPROFILE%\Microsoft\Search\Data\Temp"
# JOB: Windows update logs & built-in backgrounds (space waste)
del /F /Q %WINDIR%\*.log 
del /F /Q %WINDIR%\*.txt 
del /F /Q %WINDIR%\*.bmp 
del /F /Q %WINDIR%\*.tmp 
rmdir /S /Q %WINDIR%\Web\Wallpaper\Dell 
# JOB: Clear cached NVIDIA driver updates
if exist "%ProgramFiles%\NVIDIA Corporation\Installer" rmdir /s /q "%ProgramFiles%\NVIDIA Corporation\Installer" 
if exist "%ProgramFiles%\NVIDIA Corporation\Installer2" rmdir /s /q "%ProgramFiles%\NVIDIA Corporation\Installer2" 
if exist "%ProgramFiles(x86)%\NVIDIA Corporation\Installer" rmdir /s /q "%ProgramFiles(x86)%\NVIDIA Corporation\Installer" 
if exist "%ProgramFiles(x86)%\NVIDIA Corporation\Installer2" rmdir /s /q "%ProgramFiles(x86)%\NVIDIA Corporation\Installer2" 
if exist "%ProgramData%\NVIDIA Corporation\Downloader" rmdir /s /q "%ProgramData%\NVIDIA Corporation\Downloader" 
if exist "%ProgramData%\NVIDIA\Downloader" rmdir /s /q "%ProgramData%\NVIDIA\Downloader" 
# JOB: Windows CBS logs
echo %WIN_VER% | findstr /v /i /c:"Microsoft" >NUL && del /F /Q %WINDIR%\logs\CBS\* 

Reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\SideBySide\Configuration" /v "DisableResetbase" /t REG_DWORD /d "0" /f
Reg add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v "NtfsDisableCompression" /t REG_DWORD /d "0" /f
Reg add "HKLM\SYSTEM\CurrentControlSet\Policies" /v "NtfsDisableCompression" /t REG_DWORD /d "0" /f
fsutil behavior set disablecompression 0
Dism Online /Cleanup-Image /StartComponentCleanup /ResetBase

exit /b 0
