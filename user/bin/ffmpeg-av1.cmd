@echo off
setlocal enabledelayedexpansion
cd /d %~dp0

REM Check if ffmpeg is available
where ffmpeg >nul 2>&1
if %errorlevel% neq 0 (
    echo Error: ffmpeg not found in PATH
    echo Please install ffmpeg or add it to your PATH
    pause
    exit /b 1
)

REM Check if any MP4 files exist
set "found=0"
for %%a in (*.mp4) do set "found=1"
if "!found!"=="0" (
    echo No MP4 files found in current directory
    pause
    exit /b 0
)

echo Processing MP4 files...
for %%a in (*.mp4) do (
  echo Processing: %%a
  ffmpeg -i "%%a" -c:v libsvtav1 -preset 1 -b:v 4000k ^
    -svtav1-params "tbr=4000:tune=0:film-grain=8:enable-variance-boost=1:tile-columns=0:tile-rows=0:scd=1:film-grain=8" ^
    -c:a libopus -compression_level 10 -b:a 64k -vbr on ^
    "%%~na.mkv"
  if !errorlevel! neq 0 (
    echo Error processing: %%a
  ) else (
    echo Successfully processed: %%a
  )
)
echo.
echo Processing complete!
pause
