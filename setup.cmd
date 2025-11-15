@echo off
cls
setlocal EnableExtensions DisableDelayedExpansion

:: Enable ANSI Escape Sequences
reg add "HKCU\CONSOLE" /v "VirtualTerminalLevel" /t REG_DWORD /d "1" /f

echo Installing VCRedist...
winget install --id=Microsoft.VCRedist.2015+.x64  -e && winget install --id=Microsoft.VCRedist.2013.x64  -e
echo Installing DotNet runtimes...
winget install --id=Microsoft.DotNet.DesktopRuntime.9 -h && winget install --id=Microsoft.DotNet.DesktopRuntime.8 -h && winget install --id=Microsoft.DotNet.DesktopRuntime.7 -h
echo Installing DirectX...
winget install --id=Microsoft.DirectX  -e
echo Installing Vulkan runtime...
winget install --id=KhronosGroup.VulkanRT  -e && winget install --id=Microsoft.XNARedist  -e
echo Installing Java...
winget install --id=Oracle.JavaRuntimeEnvironment -e
echo Installing Media codecs...
winget install --id=CodecGuide.K-LiteCodecPack.Standard  -h
echo Installing Software...
winget install --id=AutoHotkey.AutoHotkey -e
winget install --id=VideoLAN.VLC -e
winget install --id=GIMP.GIMP -e
winget install --id=Greenshot.Greenshot -e
winget install --id=7zip.7zip -e
winget install --id=Notepad++.Notepad++ -e
winget install --id=Mozilla.Firefox -e
winget install --id=EpicGames.EpicGamesLauncher -e && winget install --id=Valve.Steam -e
winget install --id=Discord.Discord -e
winget install --id=Guru3D.Afterburner.Beta -e

echo Installing chocolatey...
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

exit /b 0
