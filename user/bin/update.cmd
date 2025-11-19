@echo off
cd /d %~dp0

echo ============================================
echo System Update Script
echo ============================================
echo.

REM Update Winget
echo [1/4] Updating Winget packages...
where winget >nul 2>&1
if %errorlevel% equ 0 (
    winget upgrade -h -r -u --accept-package-agreements --accept-source-agreements --include-unknown --force --purge --disable-interactivity --nowarn --no-proxy
    echo Winget update complete
) else (
    echo Winget not found, skipping...
)
echo.

REM Update Scoop
echo [2/4] Updating Scoop packages...
where scoop >nul 2>&1
if %errorlevel% equ 0 (
    scoop update -a
    echo Scoop update complete
) else (
    echo Scoop not found, skipping...
)
echo.

REM Update Chocolatey
echo [3/4] Updating Chocolatey packages...
where choco >nul 2>&1
if %errorlevel% equ 0 (
    choco upgrade all -y
    echo Chocolatey update complete
) else (
    echo Chocolatey not found, skipping...
)
echo.

REM Update Python packages
echo [4/4] Updating Python packages...
where pip >nul 2>&1
if %errorlevel% equ 0 (
    pip freeze > requirements.txt
    if exist requirements.txt (
        pip install -r requirements.txt --upgrade
        del requirements.txt
        echo Python packages updated
    )
) else (
    echo Python/pip not found, skipping...
)
echo.

where rustup >nul 2>&1
if %errorlevel% equ 0 (
  rustup update
  )
)
where cargo-install-update >nul 2>&1
if %errorlevel% equ 0 (
  cargo install-update -a
  )
)
where bun >nul 2>&1
if %errorlevel% equ 0 (
  bun update -g
  )
)
echo ============================================
echo All updates complete!
echo ============================================
pause
exit
