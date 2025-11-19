@echo off
cd /d %~dp0

REM Check if ect.exe exists
if not exist "ect.exe" (
    echo Error: ect.exe not found in current directory
    echo Please ensure ect.exe is in the same folder as this script
    pause
    exit /b 1
)

REM Check if Pictures directory exists
if not exist "%userprofile%\Pictures" (
    echo Error: Pictures directory not found
    pause
    exit /b 1
)

echo Optimizing images in Pictures folder...
echo This may take a while depending on the number of images...
echo.

ect.exe -9 -strip -progressive --strict --allfilters-c -recurse --pal_sort=30 "%userprofile%\Pictures"

if %errorlevel% neq 0 (
    echo.
    echo Error: Image optimization failed
) else (
    echo.
    echo Image optimization complete!
)
pause
