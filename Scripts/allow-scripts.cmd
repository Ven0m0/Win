@echo off
setlocal enabledelayedexpansion

:: PowerShell Script Manager - Enable or disable PowerShell script execution
:: This script provides a user-friendly menu to manage PowerShell execution policies

REM Check for administrator privileges
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' NEQ '0' (
    goto uacprompt
) else (
    goto gotadmin
)

:uacprompt
REM Create VBScript to elevate privileges
echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
"%temp%\getadmin.vbs"
exit /B

:gotadmin
REM Clean up VBScript file
if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs"
pushd "%CD%"
CD /D "%~dp0"

:menu
cls
echo.
echo =====================================
echo   PowerShell Script Manager
echo =====================================
echo.
echo   Allows you to enable or disable
echo   PowerShell script execution
echo.
echo =====================================
echo.
echo 1. Scripts: Enable (Recommended)
echo 2. Scripts: Disable
echo 3. Exit
echo.
set /p choice=Select option (1-3):

if "%choice%"=="1" goto EnableScripts
if "%choice%"=="2" goto DisableScripts
if "%choice%"=="3" exit
echo Invalid choice. Please try again.
timeout /t 2 >nul
goto menu

:EnableScripts
cls
echo Enabling PowerShell scripts...
echo.

REM Configure PowerShell to allow double-click execution
echo [1/3] Configuring PowerShell file associations...
reg add "HKCR\Applications\powershell.exe\shell\open\command" /ve /t REG_SZ /d "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -ExecutionPolicy Unrestricted -File \"%%1\"" /f >nul 2>&1

REM Set execution policy to Unrestricted for current user and local machine
echo [2/3] Setting execution policy to Unrestricted...
reg add "HKCU\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" /v "ExecutionPolicy" /t REG_SZ /d "Unrestricted" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" /v "ExecutionPolicy" /t REG_SZ /d "Unrestricted" /f >nul 2>&1

REM Unblock all PowerShell files in the current directory and subdirectories
echo [3/3] Unblocking all scripts in current directory...
cd /d "%~dp0"
powershell -NoProfile -Command "Get-ChildItem -Path '%~dp0' -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue"

echo.
echo =====================================
echo   PowerShell Scripts Enabled!
echo =====================================
echo.
echo - Scripts can now be run by double-clicking
echo - Execution policy set to Unrestricted
echo - All files in this directory unblocked
echo.
pause
exit

:DisableScripts
cls
echo Disabling PowerShell scripts...
echo.

REM Remove PowerShell file associations
echo [1/2] Removing PowerShell file associations...
reg delete "HKCR\Applications\powershell.exe" /f >nul 2>&1
reg delete "HKCR\ps1_auto_file" /f >nul 2>&1

REM Set execution policy to Restricted
echo [2/2] Setting execution policy to Restricted...
reg add "HKCU\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" /v "ExecutionPolicy" /t REG_SZ /d "Restricted" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" /v "ExecutionPolicy" /t REG_SZ /d "Restricted" /f >nul 2>&1

echo.
echo =====================================
echo   PowerShell Scripts Disabled!
echo =====================================
echo.
echo - Script execution has been restricted
echo - Double-click execution disabled
echo.
pause
exit
