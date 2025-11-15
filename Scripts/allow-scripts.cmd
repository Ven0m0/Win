@echo off
setlocal enabledelayedexpansion

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
echo ================================
echo   PowerShell Script Manager
echo ================================
echo.
echo 1. Scripts: On (Recommended)
echo 2. Scripts: Off
echo.
set /p choice=Select option (1-2):

if "%choice%"=="1" goto EnableScripts
if "%choice%"=="2" goto DisableScripts
echo Invalid choice. Please try again.
timeout /t 2 >nul
goto menu

:EnableScripts
cls
echo Enabling PowerShell scripts...
echo.

REM Allow double-click PowerShell scripts
reg add "HKCR\Applications\powershell.exe\shell\open\command" /ve /t REG_SZ /d "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoLogo -ExecutionPolicy unrestricted -File \"%%1\"" /f >nul 2>&1

REM Allow PowerShell scripts execution
reg add "HKCU\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" /v "ExecutionPolicy" /t REG_SZ /d "Unrestricted" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" /v "ExecutionPolicy" /t REG_SZ /d "Unrestricted" /f >nul 2>&1

REM Unblock all files in current directory
echo Unblocking files in current directory...
cd /d "%~dp0"
powershell -NoProfile -Command "Get-ChildItem -Path '%~dp0' -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue"

echo.
echo PowerShell scripts enabled successfully!
echo Files in current directory have been unblocked.
echo.
pause
exit

:DisableScripts
cls
echo Disabling PowerShell scripts...
echo.

REM Disallow double-click PowerShell scripts
reg delete "HKCR\Applications\powershell.exe" /f >nul 2>&1
reg delete "HKCR\ps1_auto_file" /f >nul 2>&1

REM Disallow PowerShell scripts execution
reg add "HKCU\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" /v "ExecutionPolicy" /t REG_SZ /d "Restricted" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell" /v "ExecutionPolicy" /t REG_SZ /d "Restricted" /f >nul 2>&1

echo.
echo PowerShell scripts disabled successfully!
echo.
pause
exit
