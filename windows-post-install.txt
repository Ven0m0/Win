@echo off
chcp 65001 >nul
echo ========================================
echo Windows Post-Install Script (.bat)
echo Generated: 12/10/2025, 20:05
echo ========================================
echo.

:: Check for Administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ERROR: This script requires Administrator privileges.
    echo Please right-click and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

echo Starting installation process...
echo.
::============================================
:: SOFTWARE INSTALLATION
::============================================
echo.
echo Installing selected software...
echo This may take a while depending on your internet connection.
echo.

:: Web Browsers
echo Installing Web Browsers...
echo   - Mozilla Firefox
winget install --id Mozilla.Firefox -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo.

:: Media Players
echo Installing Media Players...
echo   - mpv
winget install --id mpv.net -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo.

:: Productivity
echo Installing Productivity...
echo   - LibreOffice
winget install --id TheDocumentFoundation.LibreOffice -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo.

:: Development Tools
echo Installing Development Tools...
echo   - Git
winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - Node.js
winget install --id OpenJS.NodeJS -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - Notepad++
winget install --id Notepad++.Notepad++ -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - PuTTY
winget install --id PuTTY.PuTTY -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - Terminus
winget install --id Eugeny.Terminus -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - Visual Studio Code
winget install --id Microsoft.VisualStudioCode -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo.

:: Media Creation
echo Installing Media Creation...
echo   - Audacity
winget install --id Audacity.Audacity -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - HandBrake
winget install --id HandBrake.HandBrake -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - GIMP
winget install --id GIMP.GIMP -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - Kdenlive
winget install --id KDE.Kdenlive -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - OBS Studio
winget install --id OBSProject.OBSStudio -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo.

:: Gaming
echo Installing Gaming...
echo   - Steam
winget install --id Valve.Steam -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - RetroArch
winget install --id Libretro.RetroArch -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - Epic Games Launcher
winget install --id EpicGames.EpicGamesLauncher -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo.

:: System Utilities
echo Installing System Utilities...
echo   - 7-Zip
winget install --id 7zip.7zip -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - BleachBit
winget install --id BleachBit.BleachBit -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - Everything
winget install --id voidtools.Everything -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - CPU-Z
winget install --id CPUID.CPU-Z -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - PowerToys
winget install --id Microsoft.PowerToys -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - GPU-Z
winget install --id TechPowerUp.GPU-Z -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - Revo Uninstaller
winget install --id RevoUninstaller.RevoUninstaller -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - Rainmeter
winget install --id Rainmeter.Rainmeter -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - ShareX
winget install --id ShareX.ShareX -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo.

:: Antivirus & Protection
echo Installing Antivirus & Protection...
echo   - ClamWin
winget install --id ClamWin.ClamWin -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo.

:: Drivers
echo Installing Drivers...
echo   - Snappy Driver Installer
winget install --id GlennDelahoy.SnappyDriverInstallerOrigin -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo.

:: Runtimes & Libraries
echo Installing Runtimes & Libraries...
echo   - .NET Desktop Runtime 8
winget install --id Microsoft.DotNet.DesktopRuntime.8 -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - .NET Framework 4.8
winget install --id Microsoft.DotNet.Framework.DeveloperPack_4 -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - .NET Runtime 6
winget install --id Microsoft.DotNet.Runtime.6 -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - DirectX End-User Runtime
winget install --id Microsoft.DirectX -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - OpenAL
winget install --id OpenAL.OpenAL -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - Visual C++ Redistributables (All)
winget install --id Microsoft.VCRedist.2015+.x64 -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - Vulkan Runtime
winget install --id KhronosGroup.VulkanSDK -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo   - Java Runtime Environment
winget install --id Oracle.JavaRuntimeEnvironment -e --silent --accept-package-agreements --accept-source-agreements 2>>errors.log
echo.

::============================================
:: SYSTEM CONFIGURATIONS
::============================================
echo.
echo Applying system configurations...
echo.

:: Show hidden files and folders
echo Applying: Show hidden files and folders
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Hidden /t REG_DWORD /d 1 /f
echo.

:: Show file extensions
echo Applying: Show file extensions
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideFileExt /t REG_DWORD /d 0 /f
echo.

:: Show empty drives
echo Applying: Show empty drives
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v HideDrivesWithNoMedia /t REG_DWORD /d 0 /f
echo.

:: Disable Quick Access
echo Applying: Disable Quick Access
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v LaunchTo /t REG_DWORD /d 1 /f
echo.

:: Show full path in title bar
echo Applying: Show full path in title bar
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState" /v FullPath /t REG_DWORD /d 1 /f
echo.

:: Disable folder grouping in search
echo Applying: Disable folder grouping in search
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v FolderContentsInfoTip /t REG_DWORD /d 0 /f
echo.

:: Disable hibernation
echo Applying: Disable hibernation
powercfg -h off
echo.

:: High Performance power plan
echo Applying: High Performance power plan
powercfg /S SCHEME_MIN
echo.

:: Ultimate Performance power plan
echo Applying: Ultimate Performance power plan
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
powercfg /S e9a42b02-d5df-448d-aa00-03f14749eb61
echo.

:: Disable startup delay
echo Applying: Disable startup delay
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize" /v StartupDelayInMSec /t REG_DWORD /d 0 /f
echo.

:: Disable visual effects
echo Applying: Disable visual effects
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" /v VisualFXSetting /t REG_DWORD /d 2 /f
echo.

:: Disable Superfetch/SysMain
echo Applying: Disable Superfetch/SysMain
sc config SysMain start= disabled
sc stop SysMain
echo.

:: Disable Windows Tips
echo Applying: Disable Windows Tips
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SoftLandingEnabled /t REG_DWORD /d 0 /f
echo.

:: Disable transparency effects
echo Applying: Disable transparency effects
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v EnableTransparency /t REG_DWORD /d 0 /f
echo.

:: Disable background apps
echo Applying: Disable background apps
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" /v GlobalUserDisabled /t REG_DWORD /d 1 /f
echo.

:: Set CPU to maximum performance
echo Applying: Set CPU to maximum performance
powercfg -setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 100
powercfg -setactive SCHEME_CURRENT
echo.

:: Disable Game DVR
echo Applying: Disable Game DVR
reg add "HKCU\System\GameConfigStore" /v GameDVR_Enabled /t REG_DWORD /d 0 /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" /v AppCaptureEnabled /t REG_DWORD /d 0 /f
echo.

:: Enable Hardware-accelerated GPU scheduling
echo Applying: Enable Hardware-accelerated GPU scheduling
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" /v HwSchMode /t REG_DWORD /d 2 /f
echo.

:: Disable Nvidia Telemetry
echo Applying: Disable Nvidia Telemetry
sc config NvTelemetryContainer start= disabled
sc stop NvTelemetryContainer
echo.

:: Competitive Gaming Optimizations
echo Applying: Competitive Gaming Optimizations
REM Disable Mouse Acceleration (Enhanced Pointer Precision)
reg add "HKCU\Control Panel\Mouse" /v MouseSpeed /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold1 /t REG_SZ /d 0 /f
reg add "HKCU\Control Panel\Mouse" /v MouseThreshold2 /t REG_SZ /d 0 /f
REM Disable Sticky Keys, Filter Keys, Toggle Keys
reg add "HKCU\Control Panel\Accessibility\StickyKeys" /v Flags /t REG_SZ /d 506 /f
reg add "HKCU\Control Panel\Accessibility\Keyboard Response" /v Flags /t REG_SZ /d 122 /f
reg add "HKCU\Control Panel\Accessibility\ToggleKeys" /v Flags /t REG_SZ /d 58 /f
REM Network optimizations - Reduce latency
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v NetworkThrottlingIndex /t REG_DWORD /d 4294967295 /f
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" /v SystemResponsiveness /t REG_DWORD /d 0 /f
REM Disable Nagle Algorithm (reduces input lag)
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" /v TcpAckFrequency /t REG_DWORD /d 1 /f
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" /v TCPNoDelay /t REG_DWORD /d 1 /f
echo.

:: Disable telemetry
echo Applying: Disable telemetry
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f
echo.

:: Disable activity history
echo Applying: Disable activity history
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v PublishUserActivities /t REG_DWORD /d 0 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v UploadUserActivities /t REG_DWORD /d 0 /f
echo.

:: Disable location tracking
echo Applying: Disable location tracking
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" /v DisableLocation /t REG_DWORD /d 1 /f
echo.

:: Disable advertising ID
echo Applying: Disable advertising ID
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" /v Enabled /t REG_DWORD /d 0 /f
echo.

:: Disable Cortana
echo Applying: Disable Cortana
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search" /v AllowCortana /t REG_DWORD /d 0 /f
echo.

:: Disable Windows feedback requests
echo Applying: Disable Windows feedback requests
reg add "HKCU\Software\Microsoft\Siuf\Rules" /v NumberOfSIUFInPeriod /t REG_DWORD /d 0 /f
echo.

:: Disable tailored experiences
echo Applying: Disable tailored experiences
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Privacy" /v TailoredExperiencesWithDiagnosticDataEnabled /t REG_DWORD /d 0 /f
echo.

:: Disable app suggestions
echo Applying: Disable app suggestions
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338388Enabled /t REG_DWORD /d 0 /f
echo.

:: Disable diagnostic data collection
echo Applying: Disable diagnostic data collection
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" /v AllowTelemetry /t REG_DWORD /d 0 /f
echo.

:: Disable Timeline
echo Applying: Disable Timeline
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\System" /v EnableActivityFeed /t REG_DWORD /d 0 /f
echo.

:: Disable Windows Error Reporting
echo Applying: Disable Windows Error Reporting
reg add "HKLM\SOFTWARE\Microsoft\Windows\Windows Error Reporting" /v Disabled /t REG_DWORD /d 1 /f
echo.

:: Disable Customer Experience Program
echo Applying: Disable Customer Experience Program
reg add "HKLM\SOFTWARE\Policies\Microsoft\SQMClient\Windows" /v CEIPEnable /t REG_DWORD /d 0 /f
echo.

:: Enable Dark Mode
echo Applying: Enable Dark Mode
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v AppsUseLightTheme /t REG_DWORD /d 0 /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /v SystemUsesLightTheme /t REG_DWORD /d 0 /f
echo.

:: Hide Task View button
echo Applying: Hide Task View button
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ShowTaskViewButton /t REG_DWORD /d 0 /f
echo.

:: Disable taskbar thumbnail previews
echo Applying: Disable taskbar thumbnail previews
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v ExtendedUIHoverTime /t REG_DWORD /d 10000 /f
echo.

:: Classic right-click menu (Win11)
echo Applying: Classic right-click menu (Win11)
reg add "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" /ve /f
echo.

:: Remove OneDrive
echo Applying: Remove OneDrive
taskkill /f /im OneDrive.exe
%SystemRoot%\System32\OneDriveSetup.exe /uninstall
%SystemRoot%\SysWOW64\OneDriveSetup.exe /uninstall
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive" /v DisableFileSyncNGSC /t REG_DWORD /d 1 /f
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v OneDrive /f
echo.

:: Disable automatic restart after updates
echo Applying: Disable automatic restart after updates
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU" /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f
echo.

:: Disable Bing search in Start Menu
echo Applying: Disable Bing search in Start Menu
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Search" /v BingSearchEnabled /t REG_DWORD /d 0 /f
echo.

:: Remove recent items from Start Menu
echo Applying: Remove recent items from Start Menu
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_TrackDocs /t REG_DWORD /d 0 /f
echo.

:: Left align taskbar (Win11)
echo Applying: Left align taskbar (Win11)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarAl /t REG_DWORD /d 0 /f
echo.

:: Disable WiFi Sense
echo Applying: Disable WiFi Sense
reg add "HKLM\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config" /v AutoConnectAllowedOEM /t REG_DWORD /d 0 /f
echo.

:: Set DNS to Cloudflare 1.1.1.1
echo Applying: Set DNS to Cloudflare 1.1.1.1
netsh interface ip set dns "Ethernet" static 1.1.1.1 primary
netsh interface ip add dns "Ethernet" 1.0.0.1 index=2
netsh interface ip set dns "Wi-Fi" static 1.1.1.1 primary
netsh interface ip add dns "Wi-Fi" 1.0.0.1 index=2
echo.

:: Remove Xbox Game Bar
echo Applying: Remove Xbox Game Bar
powershell -Command "Get-AppxPackage Microsoft.XboxGamingOverlay | Remove-AppxPackage"
powershell -Command "Get-AppxPackage Microsoft.XboxGameCallableUI | Remove-AppxPackage"
echo.

:: Remove 3D Viewer
echo Applying: Remove 3D Viewer
powershell -Command "Get-AppxPackage *3DViewer* | Remove-AppxPackage"
powershell -Command "Get-AppxPackage Microsoft.Microsoft3DViewer | Remove-AppxPackage"
echo.

:: Remove Office Hub
echo Applying: Remove Office Hub
powershell -Command "Get-AppxPackage Microsoft.MicrosoftOfficeHub | Remove-AppxPackage"
echo.

:: Remove Widgets
echo Applying: Remove Widgets
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f
powershell -Command "Get-AppxPackage *WebExperience* | Remove-AppxPackage"
powershell -Command "Get-AppxPackage MicrosoftWindows.Client.WebExperience | Remove-AppxPackage"
echo.

:: Remove Teams Chat
echo Applying: Remove Teams Chat
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarMn /t REG_DWORD /d 0 /f
powershell -Command "Get-AppxPackage MicrosoftTeams* | Remove-AppxPackage"
echo.

:: Remove Clipchamp
echo Applying: Remove Clipchamp
powershell -Command "Get-AppxPackage *Clipchamp* | Remove-AppxPackage"
echo.

:: Remove Bing Weather
echo Applying: Remove Bing Weather
powershell -Command "Get-AppxPackage Microsoft.BingWeather | Remove-AppxPackage"
echo.

:: Remove Bing News
echo Applying: Remove Bing News
powershell -Command "Get-AppxPackage Microsoft.BingNews | Remove-AppxPackage"
echo.

:: Remove casual games
echo Applying: Remove casual games
powershell -Command "Get-AppxPackage *CandyCrush* | Remove-AppxPackage"
powershell -Command "Get-AppxPackage *BubbleWitch* | Remove-AppxPackage"
powershell -Command "Get-AppxPackage king.com* | Remove-AppxPackage"
powershell -Command "Get-AppxPackage *MarchofEmpires* | Remove-AppxPackage"
echo.

:: Remove all Xbox apps
echo Applying: Remove all Xbox apps
powershell -Command "Get-AppxPackage Microsoft.XboxIdentityProvider | Remove-AppxPackage"
powershell -Command "Get-AppxPackage Microsoft.XboxSpeechToTextOverlay | Remove-AppxPackage"
powershell -Command "Get-AppxPackage Microsoft.Xbox.TCUI | Remove-AppxPackage"
echo.

:: Remove Microsoft Solitaire
echo Applying: Remove Microsoft Solitaire
powershell -Command "Get-AppxPackage Microsoft.MicrosoftSolitaireCollection | Remove-AppxPackage"
echo.

:: Remove Mixed Reality Portal
echo Applying: Remove Mixed Reality Portal
powershell -Command "Get-AppxPackage Microsoft.MixedReality.Portal | Remove-AppxPackage"
powershell -Command "Get-AppxPackage *HolographicFirstRun* | Remove-AppxPackage"
echo.

:: Remove Skype (pre-installed)
echo Applying: Remove Skype (pre-installed)
powershell -Command "Get-AppxPackage Microsoft.SkypeApp | Remove-AppxPackage"
echo.

:: Remove Get Help app
echo Applying: Remove Get Help app
powershell -Command "Get-AppxPackage Microsoft.GetHelp | Remove-AppxPackage"
echo.

:: Remove Your Phone/Phone Link
echo Applying: Remove Your Phone/Phone Link
powershell -Command "Get-AppxPackage Microsoft.YourPhone | Remove-AppxPackage"
powershell -Command "Get-AppxPackage *WindowsPhone* | Remove-AppxPackage"
echo.

:: Remove Microsoft Tips
echo Applying: Remove Microsoft Tips
powershell -Command "Get-AppxPackage Microsoft.Getstarted | Remove-AppxPackage"
echo.

:: Remove Paint 3D
echo Applying: Remove Paint 3D
powershell -Command "Get-AppxPackage Microsoft.MSPaint | Remove-AppxPackage"
echo.

:: Remove OneNote (UWP)
echo Applying: Remove OneNote (UWP)
powershell -Command "Get-AppxPackage Microsoft.Office.OneNote | Remove-AppxPackage"
echo.

:: Remove Mail & Calendar
echo Applying: Remove Mail & Calendar
powershell -Command "Get-AppxPackage microsoft.windowscommunicationsapps | Remove-AppxPackage"
echo.

:: Remove Windows Maps
echo Applying: Remove Windows Maps
powershell -Command "Get-AppxPackage Microsoft.WindowsMaps | Remove-AppxPackage"
echo.

:: Remove Windows Camera
echo Applying: Remove Windows Camera
powershell -Command "Get-AppxPackage Microsoft.WindowsCamera | Remove-AppxPackage"
echo.

:: Remove Voice Recorder
echo Applying: Remove Voice Recorder
powershell -Command "Get-AppxPackage Microsoft.WindowsSoundRecorder | Remove-AppxPackage"
echo.

:: Disable Mobile Hotspot service
echo Applying: Disable Mobile Hotspot service
sc config icssvc start= disabled
sc stop icssvc
echo.

:: Disable Fax service
echo Applying: Disable Fax service
sc config Fax start= disabled
sc stop Fax
echo.

::============================================
:: INSTALLATION COMPLETE
::============================================
echo.
echo ========================================
echo Installation Complete!
echo ========================================
echo.
echo If any installations failed, check errors.log
echo.
echo Next steps:
echo   1. Restart your computer if required
echo   2. Log into your installed applications
echo   3. Customize your settings as needed
echo.
echo Generated by Windows Post-Install Generator
echo https://github.com/kaic/win-post-install
echo.
pause
