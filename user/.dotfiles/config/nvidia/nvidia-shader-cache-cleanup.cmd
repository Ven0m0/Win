@echo off
:: ============================================================
:: NVIDIA Shader Cache Cleanup Script
:: ============================================================
:: Clears NVIDIA shader caches, compute cache, and temp files
:: Based on shader-cache.ps1 from Scripts directory
:: Safe to run - only clears cache files that will be regenerated
:: ============================================================

echo ============================================================
echo NVIDIA Shader Cache Cleanup
echo ============================================================
echo.

:: ============================================================
:: 1. Clear NVIDIA Compute Cache
:: ============================================================
echo [1/5] Clearing NVIDIA Compute Cache...
if exist "%APPDATA%\NVIDIA\ComputeCache" (
    rmdir /s /q "%APPDATA%\NVIDIA\ComputeCache" 2>nul
    echo    - Compute cache cleared
) else (
    echo    - No compute cache found
)
echo.

:: ============================================================
:: 2. Clear NV_Cache (ProgramData)
:: ============================================================
echo [2/5] Clearing NVIDIA NV_Cache...
if exist "%ProgramData%\NVIDIA Corporation\NV_Cache" (
    rmdir /s /q "%ProgramData%\NVIDIA Corporation\NV_Cache" 2>nul
    echo    - NV_Cache cleared
) else (
    echo    - No NV_Cache found
)
echo.

:: ============================================================
:: 3. Clear Local Shader Caches
:: ============================================================
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

:: ============================================================
:: 4. Clear LocalLow Shader Caches
:: ============================================================
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

:: ============================================================
:: 5. Clear Driver Temp Directory
:: ============================================================
echo [5/5] Clearing NVIDIA driver temp directory...
if exist "%SystemDrive%\NVIDIA" (
    rmdir /s /q "%SystemDrive%\NVIDIA" 2>nul
    echo    - Driver temp directory cleared
) else (
    echo    - No driver temp directory found
)
echo.

:: ============================================================
:: Summary
:: ============================================================
echo ============================================================
echo Cleanup Complete!
echo ============================================================
echo.
echo All NVIDIA shader caches have been cleared.
echo These will be regenerated automatically when you run games.
echo.
echo NOTE: First launch of games may take slightly longer as
echo       shaders are recompiled and cached again.
echo ============================================================
echo.

pause
exit /b 0
