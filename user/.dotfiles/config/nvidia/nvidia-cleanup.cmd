@echo off
:: ============================================================
:: NVIDIA Cleanup (unified)
:: ============================================================
:: Combines shader-cache cleanup and telemetry/bloat removal.
:: Usage: nvidia-cleanup.cmd [shader^|telemetry^|all]
::   shader     - clear NVIDIA shader/compute/temp caches (safe, regenerates)
::   telemetry  - disable telemetry, remove bloat (run as Administrator)
::   all        - run both
:: With no argument, an interactive menu is shown.
:: ============================================================

setlocal enabledelayedexpansion

set "MODE=%~1"
if /i "%MODE%"=="shader"    goto :run_shader
if /i "%MODE%"=="telemetry" goto :run_telemetry
if /i "%MODE%"=="all"       goto :run_all
if not "%MODE%"=="" (
    echo Unknown option: %MODE%
    echo Usage: nvidia-cleanup.cmd [shader^|telemetry^|all]
    endlocal
    exit /b 1
)

:menu
echo ============================================================
echo NVIDIA Cleanup
echo ============================================================
echo   1. Shader cache cleanup (safe)
echo   2. Telemetry and bloat removal (Administrator)
echo   3. Both
echo   0. Exit
echo ============================================================
set /p "CHOICE=Select an option: "
if "%CHOICE%"=="1" goto :run_shader
if "%CHOICE%"=="2" goto :run_telemetry
if "%CHOICE%"=="3" goto :run_all
if "%CHOICE%"=="0" ( endlocal & exit /b 0 )
echo Invalid choice.
echo.
goto :menu

:run_all
call :do_shader
call :do_telemetry
goto :done

:run_shader
call :do_shader
goto :done

:run_telemetry
call :do_telemetry
goto :done

:: ============================================================
:: Shader cache cleanup
:: ============================================================
:do_shader
echo ============================================================
echo NVIDIA Shader Cache Cleanup
echo ============================================================
echo.

echo [1/5] Clearing NVIDIA Compute Cache...
if exist "%APPDATA%\NVIDIA\ComputeCache" (
    rmdir /s /q "%APPDATA%\NVIDIA\ComputeCache" 2>nul
    echo    - Compute cache cleared
) else (
    echo    - No compute cache found
)
echo.

echo [2/5] Clearing NVIDIA NV_Cache...
if exist "%ProgramData%\NVIDIA Corporation\NV_Cache" (
    rmdir /s /q "%ProgramData%\NVIDIA Corporation\NV_Cache" 2>nul
    echo    - NV_Cache cleared
) else (
    echo    - No NV_Cache found
)
echo.

echo [3/5] Clearing Local NVIDIA shader caches...

if exist "%LOCALAPPDATA%\NVIDIA\GLCache" (
    rmdir /s /q "%LOCALAPPDATA%\NVIDIA\GLCache" 2>nul
    echo    - GLCache cleared
)

if exist "%LOCALAPPDATA%\NVIDIA\DXCache" (
    rmdir /s /q "%LOCALAPPDATA%\NVIDIA\DXCache" 2>nul
    echo    - DXCache cleared
)

if exist "%LOCALAPPDATA%\NVIDIA\OptixCache" (
    rmdir /s /q "%LOCALAPPDATA%\NVIDIA\OptixCache" 2>nul
    echo    - OptixCache cleared
)

if exist "%LOCALAPPDATA%\NVIDIA Corporation\NV_Cache" (
    rmdir /s /q "%LOCALAPPDATA%\NVIDIA Corporation\NV_Cache" 2>nul
    echo    - NV_Cache (local) cleared
)

echo    - Local caches processed
echo.

echo [4/5] Clearing LocalLow NVIDIA shader caches...

if exist "%LOCALAPPDATA%\..\LocalLow\NVIDIA\PerDriverVersion\DXCache" (
    rmdir /s /q "%LOCALAPPDATA%\..\LocalLow\NVIDIA\PerDriverVersion\DXCache" 2>nul
    echo    - DXCache (per-driver) cleared
)

if exist "%LOCALAPPDATA%\..\LocalLow\NVIDIA\PerDriverVersion\GLCache" (
    rmdir /s /q "%LOCALAPPDATA%\..\LocalLow\NVIDIA\PerDriverVersion\GLCache" 2>nul
    echo    - GLCache (per-driver) cleared
)

echo    - LocalLow caches processed
echo.

echo [5/5] Clearing NVIDIA driver temp directory...
if exist "%SystemDrive%\NVIDIA" (
    rmdir /s /q "%SystemDrive%\NVIDIA" 2>nul
    echo    - Driver temp directory cleared
) else (
    echo    - No driver temp directory found
)
echo.

echo All NVIDIA shader caches have been cleared.
echo These will be regenerated automatically when you run games.
echo NOTE: First launch of games may take slightly longer as
echo       shaders are recompiled and cached again.
echo.
exit /b 0

:: ============================================================
:: Telemetry and bloat removal
:: ============================================================
:do_telemetry
echo ============================================================
echo NVIDIA Telemetry and Bloat Removal
echo ============================================================
echo.

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

echo [3/6] Uninstalling NVIDIA telemetry packages...

if exist "%ProgramFiles%\NVIDIA Corporation\Installer2\InstallerCore\NVI2.DLL" (
    rundll32 "%PROGRAMFILES%\NVIDIA Corporation\Installer2\InstallerCore\NVI2.DLL",UninstallPackage NvTelemetryContainer >nul 2>&1
    rundll32 "%PROGRAMFILES%\NVIDIA Corporation\Installer2\InstallerCore\NVI2.DLL",UninstallPackage NvTelemetry >nul 2>&1
    echo    - Telemetry packages uninstalled
) else (
    echo    - Installer DLL not found, skipping package uninstall
)
echo.

echo [4/5] Removing NVIDIA telemetry files...

PowerShell -ExecutionPolicy RemoteSigned -NoProfile -Command ^
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

echo [5/5] Cleanup complete!
echo.
echo Summary:
echo - Telemetry registry keys set
echo - Telemetry scheduled tasks disabled
echo - Telemetry packages uninstalled
echo - Telemetry files renamed to .OLD
echo.
echo NOTE: Some changes may require a system reboot to take effect
echo.
exit /b 0

:done
echo ============================================================
echo Done.
echo ============================================================
echo.
pause
endlocal
exit /b 0
