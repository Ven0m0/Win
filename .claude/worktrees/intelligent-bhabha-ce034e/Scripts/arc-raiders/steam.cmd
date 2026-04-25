@echo off
setlocal
:: Ensure it runs as Administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Administrative permissions confirmed.
) else (
    echo Requesting administrative privileges...
    set "ELEVATE_CMD=%~f0"
    powershell -NoProfile -Command "Start-Process -FilePath $env:ELEVATE_CMD -Verb RunAs"
    exit /b
)

:: Find and run pwsh or powershell
where pwsh >nul 2>&1
if %ERRORLEVEL% equ 0 (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0steam.ps1"
) else (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0steam.ps1"
)
exit /b