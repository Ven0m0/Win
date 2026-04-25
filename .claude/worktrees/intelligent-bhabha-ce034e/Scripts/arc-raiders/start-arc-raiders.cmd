@echo off
setlocal
:: Ensure it runs as Administrator
net session >nul 2>&1
if %errorLevel% == 0 (
    echo Administrative permissions confirmed.
) else (
    echo Requesting administrative privileges...
    set "ELEVATE_CMD=%~f0"
    pwsh -NoProfile -Command "Start-Process -FilePath $env:ELEVATE_CMD -Verb RunAs"
    exit /b
)

:: Find and run pwsh
where pwsh >nul 2>&1
if %ERRORLEVEL% equ 0 (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-arc-raiders.ps1"
) else (
    echo pwsh.exe (PowerShell 7) not found in PATH!
    echo Please install PowerShell 7 or ensure it is in your PATH.
    pause
)
exit /b