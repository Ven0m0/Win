@echo off
:: ============================================================
:: NVIDIA Telemetry & Bloat Removal Script
:: ============================================================
:: Consolidated from multiple telemetry removal scripts
:: Disables telemetry, removes bloat, and optimizes NVIDIA installation
:: Run as Administrator
:: ============================================================

setlocal enabledelayedexpansion

echo ============================================================
echo NVIDIA Telemetry and Bloat Removal
echo ============================================================
echo.

:: ============================================================
:: 1. Disable NVIDIA Telemetry via Registry
:: ============================================================
echo [1/6] Disabling NVIDIA telemetry via registry...

reg add "HKLM\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client" /v "OptInOrOutPreference" /t REG_DWORD /d "0" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\Startup" /v "SendTelemetryData" /t REG_DWORD /d "0" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\FTS" /v "EnableRID61684" /t REG_DWORD /d "1" /f >nul 2>&1
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "NvBackend" /f >nul 2>&1

:: FTS telemetry settings
reg add "HKLM\SOFTWARE\NVIDIA Corporation\Global\FTS" /v "EnableRID66610" /t REG_DWORD /d "0" /f >nul 2>&1
reg add "HKLM\SOFTWARE\NVIDIA Corporation\Global\FTS" /v "EnableRID64640" /t REG_DWORD /d "0" /f >nul 2>&1
reg add "HKLM\SOFTWARE\NVIDIA Corporation\Global\FTS" /v "EnableRID44231" /t REG_DWORD /d "0" /f >nul 2>&1

:: Disable logging
reg add "HKLM\SYSTEM\ControlSet001\Services\NVDisplay.ContainerLocalSystem\LocalSystem\NvcDispCorePlugin" /v "LogLevel" /t REG_DWORD /d "0" /f >nul 2>&1

echo    - Registry tweaks applied
echo.

:: ============================================================
:: 2. Disable NVIDIA Telemetry Scheduled Tasks
:: ============================================================
echo [2/6] Disabling NVIDIA telemetry scheduled tasks...

:: Disable telemetry report tasks
schtasks /change /disable /tn "NvTmRep_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}" >nul 2>&1
schtasks /change /disable /tn "NvTmRepOnLogon_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}" >nul 2>&1
schtasks /change /disable /tn "NvTmMon_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}" >nul 2>&1

:: Disable crash report tasks
schtasks /change /disable /tn "NvTmRep_CrashReport1_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}" >nul 2>&1
schtasks /change /disable /tn "NvTmRep_CrashReport2_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}" >nul 2>&1
schtasks /change /disable /tn "NvTmRep_CrashReport3_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}" >nul 2>&1
schtasks /change /disable /tn "NvTmRep_CrashReport4_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}" >nul 2>&1

:: Disable update check and GeForce Experience tasks
schtasks /change /disable /tn "NvDriverUpdateCheckDaily_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}" >nul 2>&1
schtasks /change /disable /tn "NVIDIA GeForce Experience SelfUpdate_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}" >nul 2>&1

echo    - Scheduled tasks disabled
echo.

:: ============================================================
:: 3. Uninstall NVIDIA Telemetry Packages
:: ============================================================
echo [3/6] Uninstalling NVIDIA telemetry packages...

if exist "%ProgramFiles%\NVIDIA Corporation\Installer2\InstallerCore\NVI2.DLL" (
    rundll32 "%PROGRAMFILES%\NVIDIA Corporation\Installer2\InstallerCore\NVI2.DLL",UninstallPackage NvTelemetryContainer >nul 2>&1
    rundll32 "%PROGRAMFILES%\NVIDIA Corporation\Installer2\InstallerCore\NVI2.DLL",UninstallPackage NvTelemetry >nul 2>&1
    echo    - Telemetry packages uninstalled
) else (
    echo    - Installer DLL not found, skipping package uninstall
)
echo.

:: ============================================================
:: 4. Remove NVIDIA Telemetry Files
:: ============================================================
echo [4/6] Removing NVIDIA telemetry files...

PowerShell -ExecutionPolicy Unrestricted -NoProfile -Command ^
"$paths = @('%PROGRAMFILES(X86)%\NVIDIA Corporation\NvTelemetry\*', '%PROGRAMFILES%\NVIDIA Corporation\NvTelemetry\*', '%SYSTEMROOT%\System32\DriverStore\FileRepository\NvTelemetry*.dll'); " ^
"foreach ($pathPattern in $paths) { " ^
"  $expandedPath = [System.Environment]::ExpandEnvironmentVariables($pathPattern); " ^
"  try { " ^
"    Get-Item -Path $expandedPath -ErrorAction SilentlyContinue | ForEach-Object { " ^
"      Move-Item -LiteralPath $_.FullName -Destination ($_.FullName + '.OLD') -Force -ErrorAction SilentlyContinue; " ^
"    }; " ^
"  } catch {} " ^
"}" >nul 2>&1

echo    - Telemetry files disabled
echo.

:: ============================================================
:: 5. Remove NVIDIA Bloat from Driver Installation
:: ============================================================
echo [5/6] Removing NVIDIA bloatware components...

:: Note: Only run this on extracted driver folders
:: This is meant to be used BEFORE installing a driver
set "DRIVER_PATH=%~dp0"

if exist "%DRIVER_PATH%Display.Driver" (
    echo    - Removing bloat from driver folder: %DRIVER_PATH%

    rmdir /s /q "%DRIVER_PATH%Display.Nview" 2>nul
    rmdir /s /q "%DRIVER_PATH%FrameViewSDK" 2>nul
    rmdir /s /q "%DRIVER_PATH%HDAudio" 2>nul
    rmdir /s /q "%DRIVER_PATH%MSVCRT" 2>nul
    rmdir /s /q "%DRIVER_PATH%NvApp" 2>nul
    rmdir /s /q "%DRIVER_PATH%NvApp.MessageBus" 2>nul
    rmdir /s /q "%DRIVER_PATH%NvBackend" 2>nul
    rmdir /s /q "%DRIVER_PATH%NvContainer" 2>nul
    rmdir /s /q "%DRIVER_PATH%NvDLISR" 2>nul
    rmdir /s /q "%DRIVER_PATH%NVPCF" 2>nul
    rmdir /s /q "%DRIVER_PATH%NvTelemetry" 2>nul
    rmdir /s /q "%DRIVER_PATH%NvVAD" 2>nul
    rmdir /s /q "%DRIVER_PATH%PPC" 2>nul
    rmdir /s /q "%DRIVER_PATH%ShadowPlay" 2>nul

    echo    - Bloat removed from driver folder
) else (
    echo    - Not in driver folder, skipping driver debloat
    echo    - To debloat a driver: Extract the driver, run this script from that folder
)
echo.

:: ============================================================
:: 6. Summary
:: ============================================================
echo [6/6] Cleanup complete!
echo.
echo ============================================================
echo Summary:
echo ============================================================
echo - Telemetry registry keys set
echo - Telemetry scheduled tasks disabled
echo - Telemetry packages uninstalled
echo - Telemetry files renamed to .OLD
echo - Driver bloat removed (if in driver folder)
echo.
echo NOTE: Some changes may require a system reboot to take effect
echo ============================================================
echo.

endlocal
pause
exit /b 0
