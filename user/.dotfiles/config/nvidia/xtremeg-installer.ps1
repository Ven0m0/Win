#Requires -RunAsAdministrator

<#
.SYNOPSIS
    XtremeG Custom NVIDIA Driver Installer
.DESCRIPTION
    Downloads and installs XtremeG custom NVIDIA drivers from MEGA.nz
    WARNING: These are unofficial/modified drivers - use at your own risk!
.NOTES
    See XTREMEG.md for full documentation and warnings
#>

# Import common functions if available
if (Test-Path "$PSScriptRoot\..\..\..\..\Scripts\Common.ps1") {
  . "$PSScriptRoot\..\..\..\..\Scripts\Common.ps1"
} else {
  # Minimal functions if Common.ps1 not available
  function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
  }
}

# Request admin elevation
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Warning "This script requires Administrator privileges!"
  $arguments = "& '" + $myinvocation.mycommand.definition + "'"
  Start-Process powershell -Verb runAs -ArgumentList $arguments
  exit
}

# Initialize
Clear-Host
$ErrorActionPreference = "Stop"

# Configuration
$downloadPath = "$env:USERPROFILE\Downloads\XtremeG"
$extractPath = "$downloadPath\Extracted"
$logFile = "$downloadPath\install.log"

# Banner
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  XtremeG Custom NVIDIA Driver Installer" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  WARNING: UNOFFICIAL MODIFIED DRIVERS - USE AT YOUR OWN RISK!" -ForegroundColor Red
Write-Host ""

# Show warnings
function Show-Warnings {
  Write-Host "IMPORTANT INFORMATION:" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "  ❌ NOT official NVIDIA drivers" -ForegroundColor Red
  Write-Host "  ❌ NOT supported by NVIDIA" -ForegroundColor Red
  Write-Host "  ❌ May void warranty" -ForegroundColor Red
  Write-Host "  ❌ May cause system instability" -ForegroundColor Red
  Write-Host ""
  Write-Host "  ✅ Community-modified for performance" -ForegroundColor Green
  Write-Host "  ✅ Telemetry completely removed" -ForegroundColor Green
  Write-Host "  ✅ Bloatware stripped out" -ForegroundColor Green
  Write-Host "  ✅ Optimized for gaming" -ForegroundColor Green
  Write-Host ""
  Write-Host "See XTREMEG.md for full documentation" -ForegroundColor Cyan
  Write-Host ""
}

Show-Warnings

# Confirm user wants to proceed
Write-Host "Do you want to continue? (y/N): " -NoNewline -ForegroundColor Yellow
$confirm = Read-Host
if ($confirm -ne "y" -and $confirm -ne "Y") {
  Write-Host "Installation cancelled." -ForegroundColor Yellow
  exit 0
}

Clear-Host

# Create directories
Write-Host "[1/7] Creating directories..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $downloadPath | Out-Null
New-Item -ItemType Directory -Force -Path $extractPath | Out-Null
Write-Host "  ✓ Created: $downloadPath" -ForegroundColor Green
Write-Host ""

# Get MEGA.nz URL
Write-Host "[2/7] MEGA.nz Download URL" -ForegroundColor Cyan
Write-Host ""
Write-Host "Find the latest XtremeG driver at: https://www.reddit.com/r/XtremeG" -ForegroundColor Yellow
Write-Host ""
Write-Host "Example URL format:" -ForegroundColor Gray
Write-Host "  https://mega.nz/file/rkc20QAY#Xp0RksAw2_omqeB98N1WSJnTDvogzaq1UqCX-rcI9N4" -ForegroundColor Gray
Write-Host ""
Write-Host "Enter MEGA.nz URL (or press Enter to download manually): " -NoNewline
$megaUrl = Read-Host

Clear-Host

# Download driver
Write-Host "[3/7] Downloading XtremeG Driver..." -ForegroundColor Cyan
Write-Host ""

if ([string]::IsNullOrWhiteSpace($megaUrl)) {
  # Manual download
  Write-Host "Manual download selected." -ForegroundColor Yellow
  Write-Host ""
  Write-Host "Steps:" -ForegroundColor Cyan
  Write-Host "  1. Visit https://www.reddit.com/r/XtremeG" -ForegroundColor White
  Write-Host "  2. Find the latest driver post" -ForegroundColor White
  Write-Host "  3. Click the MEGA.nz download link" -ForegroundColor White
  Write-Host "  4. Download the driver ZIP/7z file" -ForegroundColor White
  Write-Host "  5. Save it to: $downloadPath" -ForegroundColor White
  Write-Host ""
  Write-Host "Press Enter when download is complete..." -NoNewline
  Read-Host

  # Find downloaded file
  $driverFile = Get-ChildItem -Path $downloadPath -Filter "*.zip" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

  if (-not $driverFile) {
    $driverFile = Get-ChildItem -Path $downloadPath -Filter "*.7z" -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
  }

  if (-not $driverFile) {
    Write-Host "  ❌ No ZIP or 7z file found in $downloadPath" -ForegroundColor Red
    Write-Host "  Please download the driver and try again." -ForegroundColor Yellow
    exit 1
  }

  Write-Host "  ✓ Found: $($driverFile.Name)" -ForegroundColor Green
} else {
  # Automated download (requires MEGAcmd or browser automation)
  Write-Host "Automated download not yet implemented." -ForegroundColor Yellow
  Write-Host ""
  Write-Host "Opening browser to download..." -ForegroundColor Cyan
  Start-Process $megaUrl
  Write-Host ""
  Write-Host "Please download the file and save it to: $downloadPath" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "Press Enter when download is complete..." -NoNewline
  Read-Host

  # Find downloaded file
  $driverFile = Get-ChildItem -Path $downloadPath -Filter "*.zip" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

  if (-not $driverFile) {
    $driverFile = Get-ChildItem -Path $downloadPath -Filter "*.7z" -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
  }

  if (-not $driverFile) {
    Write-Host "  ❌ No file found in $downloadPath" -ForegroundColor Red
    exit 1
  }

  Write-Host "  ✓ Found: $($driverFile.Name)" -ForegroundColor Green
}

Write-Host ""

# Extract driver
Write-Host "[4/7] Extracting driver..." -ForegroundColor Cyan

# Check for 7-Zip or built-in extraction
$use7zip = $false
$7zipPath = "C:\Program Files\7-Zip\7z.exe"
if (Test-Path $7zipPath) {
  $use7zip = $true
}

try {
  if ($use7zip) {
    Write-Host "  Using 7-Zip for extraction..." -ForegroundColor Gray
    & $7zipPath x "$($driverFile.FullName)" -o"$extractPath" -y | Out-Null
  } else {
    Write-Host "  Using built-in extraction..." -ForegroundColor Gray
    Expand-Archive -Path $driverFile.FullName -DestinationPath $extractPath -Force
  }
  Write-Host "  ✓ Extracted to: $extractPath" -ForegroundColor Green
} catch {
  Write-Host "  ❌ Extraction failed: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host ""
  Write-Host "Try installing 7-Zip: https://www.7-zip.org/" -ForegroundColor Yellow
  exit 1
}

Write-Host ""

# Find setup.exe
Write-Host "[5/7] Locating installer..." -ForegroundColor Cyan
$setupExe = Get-ChildItem -Path $extractPath -Filter "setup.exe" -Recurse -ErrorAction SilentlyContinue |
  Select-Object -First 1

if (-not $setupExe) {
  Write-Host "  ❌ setup.exe not found in extracted files" -ForegroundColor Red
  Write-Host "  Extracted path: $extractPath" -ForegroundColor Yellow
  Write-Host ""
  Write-Host "Please check the extraction and run setup.exe manually." -ForegroundColor Yellow
  explorer $extractPath
  exit 1
}

Write-Host "  ✓ Found: $($setupExe.FullName)" -ForegroundColor Green
Write-Host ""

# Optional: Run DDU first
Write-Host "[6/7] Pre-installation cleanup (Optional)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Run Display Driver Uninstaller (DDU) first? (Recommended)" -ForegroundColor Yellow
Write-Host "  y - Yes, open DDU download page (manual process)" -ForegroundColor White
Write-Host "  n - No, skip DDU and install directly" -ForegroundColor White
Write-Host ""
Write-Host "Choice (y/n): " -NoNewline
$dduChoice = Read-Host

if ($dduChoice -eq "y" -or $dduChoice -eq "Y") {
  Write-Host ""
  Write-Host "Opening DDU download page..." -ForegroundColor Cyan
  Start-Process "https://www.guru3d.com/files-details/display-driver-uninstaller-download.html"
  Write-Host ""
  Write-Host "DDU Instructions:" -ForegroundColor Yellow
  Write-Host "  1. Download and extract DDU" -ForegroundColor White
  Write-Host "  2. Boot into Safe Mode (Windows Settings → Update & Security → Recovery)" -ForegroundColor White
  Write-Host "  3. Run DDU, select NVIDIA, click 'Clean and Restart'" -ForegroundColor White
  Write-Host "  4. After reboot, run this script again" -ForegroundColor White
  Write-Host ""
  Write-Host "Do you want to continue without DDU? (y/N): " -NoNewline
  $skipDdu = Read-Host
  if ($skipDdu -ne "y" -and $skipDdu -ne "Y") {
    Write-Host ""
    Write-Host "Installation paused. Run this script again after DDU." -ForegroundColor Yellow
    exit 0
  }
} else {
  Write-Host "  Skipping DDU cleanup" -ForegroundColor Yellow
}

Clear-Host

# Install driver
Write-Host "[7/7] Installing XtremeG Driver..." -ForegroundColor Cyan
Write-Host ""
Write-Host "  Starting NVIDIA installer..." -ForegroundColor Yellow
Write-Host "  Location: $($setupExe.FullName)" -ForegroundColor Gray
Write-Host ""
Write-Host "  ⚠️  Follow the on-screen installer prompts" -ForegroundColor Yellow
Write-Host "  ⚠️  Choose 'Custom' installation if you want to review components" -ForegroundColor Yellow
Write-Host ""

# Log installation
"[$(Get-Date)] Installing XtremeG Driver" | Out-File $logFile -Append
"Driver file: $($driverFile.Name)" | Out-File $logFile -Append
"Setup path: $($setupExe.FullName)" | Out-File $logFile -Append

# Run setup
try {
  Start-Process -FilePath $setupExe.FullName -Wait
  Write-Host ""
  Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
  Write-Host "  Installation Complete!" -ForegroundColor Green
  Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Green
  Write-Host ""
} catch {
  Write-Host ""
  Write-Host "  ❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host ""
  exit 1
}

# Post-installation options
Write-Host "Post-Installation Options:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  1. Reboot now (recommended)" -ForegroundColor White
Write-Host "  2. Apply additional performance tweaks" -ForegroundColor White
Write-Host "  3. Open NVIDIA Control Panel" -ForegroundColor White
Write-Host "  4. Exit" -ForegroundColor White
Write-Host ""
Write-Host "Choice (1-4): " -NoNewline
$postChoice = Read-Host

switch ($postChoice) {
  "1" {
    Write-Host ""
    Write-Host "Rebooting in 10 seconds..." -ForegroundColor Yellow
    Write-Host "Press Ctrl+C to cancel" -ForegroundColor Gray
    Start-Sleep -Seconds 10
    shutdown /r /t 0
  }
  "2" {
    Write-Host ""
    Write-Host "Available tweaks:" -ForegroundColor Cyan
    Write-Host "  • nvidia-performance-tweaks.reg - Comprehensive optimizations" -ForegroundColor White
    Write-Host "  • toggles/disable-mpo.reg - Fix flickering" -ForegroundColor White
    Write-Host "  • toggles/enable-hardware-scheduling.reg - Lower latency" -ForegroundColor White
    Write-Host ""
    Write-Host "Note: XtremeG drivers may already include many tweaks!" -ForegroundColor Yellow
    Write-Host "Check with Scripts/gpu-display-manager.ps1 first" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Opening nvidia config directory..." -ForegroundColor Cyan
    explorer $PSScriptRoot
  }
  "3" {
    Write-Host ""
    Write-Host "Opening NVIDIA Control Panel..." -ForegroundColor Cyan
    Start-Process "control.exe" -ArgumentList "nvcplui.cpl"
  }
  "4" {
    Write-Host ""
    Write-Host "Installation complete. Please reboot when ready." -ForegroundColor Yellow
  }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "Installation log saved to: $logFile" -ForegroundColor Gray
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Cleanup option
Write-Host "Clean up downloaded files? (y/N): " -NoNewline
$cleanup = Read-Host
if ($cleanup -eq "y" -or $cleanup -eq "Y") {
  Write-Host "Cleaning up..." -ForegroundColor Yellow
  Remove-Item -Path $extractPath -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -Path $driverFile.FullName -Force -ErrorAction SilentlyContinue
  Write-Host "  ✓ Cleanup complete" -ForegroundColor Green
} else {
  Write-Host "Files kept at: $downloadPath" -ForegroundColor Gray
}

Write-Host ""
Write-Host "Thank you for using XtremeG Custom Drivers!" -ForegroundColor Cyan
Write-Host "Visit r/XtremeG for support: https://www.reddit.com/r/XtremeG" -ForegroundColor Gray
Write-Host ""

pause
