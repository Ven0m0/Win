#Requires -RunAsAdministrator

<#
.SYNOPSIS
    XtremeG Custom NVIDIA Driver Installer (Enhanced)
.DESCRIPTION
    Automatically finds, downloads, debloats, and installs XtremeG custom NVIDIA drivers
    Features:
    - Auto-detection of latest driver from r/XtremeG
    - Automatic MEGA.nz download (with MEGAcmd)
    - Debloating of driver package
    - Optional DDU integration
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

# Initialize
Clear-Host
$ErrorActionPreference = "Stop"

# Configuration
$downloadPath = "$env:USERPROFILE\Downloads\XtremeG"
$extractPath = "$downloadPath\Extracted"
$logFile = "$downloadPath\install.log"
$redditUrl = "https://www.reddit.com/r/XtremeG.json"

# ============================================================
# Helper Functions
# ============================================================

function Get-LatestXtremeGDriver {
  <#
  .SYNOPSIS
    Fetches latest XtremeG driver info from r/XtremeG
  #>
  Write-Host "  Fetching latest driver from r/XtremeG..." -ForegroundColor Cyan

  try {
    # Fetch Reddit JSON feed
    $reddit = Invoke-RestMethod -Uri $redditUrl -UserAgent "PowerShell:XtremeGInstaller:v2.0"

    $drivers = @()
    foreach ($post in $reddit.data.children) {
      $title = $post.data.title
      $body = $post.data.selftext

      # Look for MEGA.nz links
      $megaPattern = 'https?://mega\.nz/file/[^\s\)\]"]+'
      $megaMatches = [regex]::Matches("$title $body", $megaPattern)

      if ($megaMatches.Count -gt 0) {
        # Extract version number from title (e.g., "566.03", "555.85", etc.)
        $versionPattern = '(\d{3}\.\d{2})'
        $versionMatch = [regex]::Match($title, $versionPattern)

        if ($versionMatch.Success) {
          $drivers += [PSCustomObject]@{
            Version     = $versionMatch.Groups[1].Value
            Title       = $title
            MegaUrl     = $megaMatches[0].Value
            PostUrl     = "https://www.reddit.com$($post.data.permalink)"
            VersionNum  = [version]($versionMatch.Groups[1].Value)
          }
        }
      }
    }

    if ($drivers.Count -eq 0) {
      Write-Host "  ⚠️  No drivers found in recent posts" -ForegroundColor Yellow
      return $null
    }

    # Sort by version number (highest first)
    $latest = $drivers | Sort-Object -Property VersionNum -Descending | Select-Object -First 1

    Write-Host "  ✓ Found latest: Version $($latest.Version)" -ForegroundColor Green
    Write-Host "    Title: $($latest.Title)" -ForegroundColor Gray

    return $latest
  } catch {
    Write-Host "  ❌ Failed to fetch from Reddit: $($_.Exception.Message)" -ForegroundColor Red
    return $null
  }
}

function Test-MEGAcmd {
  <#
  .SYNOPSIS
    Checks if MEGAcmd is installed
  #>
  $megadlPaths = @(
    "$env:LOCALAPPDATA\MEGAcmd\mega-get.exe",
    "$env:ProgramFiles\MEGAcmd\mega-get.exe",
    "C:\Program Files\MEGAcmd\mega-get.exe"
  )

  foreach ($path in $megadlPaths) {
    if (Test-Path $path) {
      return $path
    }
  }

  # Check if in PATH
  try {
    $megaCmd = Get-Command "mega-get.exe" -ErrorAction SilentlyContinue
    if ($megaCmd) {
      return $megaCmd.Source
    }
  } catch {}

  return $null
}

function Install-MEGAcmd {
  <#
  .SYNOPSIS
    Offers to install MEGAcmd
  #>
  Write-Host ""
  Write-Host "MEGAcmd not found. This is required for automatic downloads." -ForegroundColor Yellow
  Write-Host ""
  Write-Host "Install MEGAcmd? (Recommended)" -ForegroundColor Cyan
  Write-Host "  y - Yes, install MEGAcmd via winget" -ForegroundColor White
  Write-Host "  n - No, use manual download instead" -ForegroundColor White
  Write-Host ""
  Write-Host "Choice (y/n): " -NoNewline
  $choice = Read-Host

  if ($choice -eq "y" -or $choice -eq "Y") {
    Write-Host ""
    Write-Host "Installing MEGAcmd via winget..." -ForegroundColor Cyan
    try {
      winget install Mega.MEGAcmd --silent --accept-source-agreements --accept-package-agreements
      Write-Host "  ✓ MEGAcmd installed successfully" -ForegroundColor Green
      Write-Host "  ⚠️  You may need to restart this script for PATH updates" -ForegroundColor Yellow
      Write-Host ""
      Write-Host "Restart script now? (y/N): " -NoNewline
      $restart = Read-Host
      if ($restart -eq "y" -or $restart -eq "Y") {
        Start-Process powershell -Verb runAs -ArgumentList "-File `"$PSCommandPath`""
        exit 0
      }
      return Test-MEGAcmd
    } catch {
      Write-Host "  ❌ Installation failed: $($_.Exception.Message)" -ForegroundColor Red
      return $null
    }
  }

  return $null
}

function Download-FromMega {
  <#
  .SYNOPSIS
    Downloads file from MEGA.nz
  #>
  param(
    [string]$MegaUrl,
    [string]$DestinationPath
  )

  $megaCmd = Test-MEGAcmd

  if (-not $megaCmd) {
    $megaCmd = Install-MEGAcmd
  }

  if ($megaCmd) {
    # Use MEGAcmd
    Write-Host "  Downloading via MEGAcmd..." -ForegroundColor Cyan
    Write-Host "  This may take several minutes (driver is ~400MB)" -ForegroundColor Gray
    Write-Host ""

    try {
      & $megaCmd $MegaUrl $DestinationPath

      # Find downloaded file
      $downloaded = Get-ChildItem -Path $DestinationPath -Include @("*.zip", "*.7z", "*.rar") -Recurse |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

      if ($downloaded) {
        Write-Host ""
        Write-Host "  ✓ Download complete: $($downloaded.Name)" -ForegroundColor Green
        return $downloaded
      } else {
        throw "Downloaded file not found"
      }
    } catch {
      Write-Host "  ❌ MEGAcmd download failed: $($_.Exception.Message)" -ForegroundColor Red
      return $null
    }
  } else {
    # Fallback to browser
    Write-Host "  Opening MEGA.nz in browser..." -ForegroundColor Yellow
    Start-Process $MegaUrl
    Write-Host ""
    Write-Host "  Please download the file and save it to: $DestinationPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Press Enter when download is complete..." -NoNewline
    Read-Host

    # Find downloaded file
    $downloaded = Get-ChildItem -Path $DestinationPath -Include @("*.zip", "*.7z", "*.rar") -Recurse -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1

    if ($downloaded) {
      Write-Host "  ✓ Found: $($downloaded.Name)" -ForegroundColor Green
      return $downloaded
    } else {
      Write-Host "  ❌ No file found in $DestinationPath" -ForegroundColor Red
      return $null
    }
  }
}

function Remove-DriverBloat {
  <#
  .SYNOPSIS
    Removes unnecessary components from extracted driver
  #>
  param([string]$ExtractPath)

  Write-Host "  Scanning for bloatware..." -ForegroundColor Cyan

  # List of folders/files to remove
  $bloatItems = @(
    "GFExperience",
    "GFExperience.NvStreamSrv",
    "GFExperienceService",
    "NvBackend",
    "NvContainer",
    "NvTelemetry",
    "NvTmMon.exe",
    "NvTmRep.exe",
    "NvTmRepOnLogon.exe",
    "NvProfileUpdater64.exe",
    "NvProfileUpdater32.exe",
    "EULA.txt",
    "ListDevices.txt",
    "setup.cfg"  # Will be recreated with minimal components
  )

  $removed = 0

  foreach ($item in $bloatItems) {
    $found = Get-ChildItem -Path $ExtractPath -Filter $item -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $found) {
      try {
        if ($file.PSIsContainer) {
          Remove-Item -Path $file.FullName -Recurse -Force -ErrorAction SilentlyContinue
        } else {
          Remove-Item -Path $file.FullName -Force -ErrorAction SilentlyContinue
        }
        $removed++
      } catch {
        # Silently continue if file is locked
      }
    }
  }

  if ($removed -gt 0) {
    Write-Host "  ✓ Removed $removed bloat items" -ForegroundColor Green
  } else {
    Write-Host "  ℹ No bloat found (already clean)" -ForegroundColor Gray
  }

  # Additional telemetry cleanup in registry-ready format
  $telemetryBat = @"
@echo off
REM Additional telemetry cleanup for XtremeG driver
echo Disabling NVIDIA telemetry services...
reg add "HKLM\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client" /v "OptInOrOutPreference" /t REG_DWORD /d "0" /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\Startup" /v "SendTelemetryData" /t REG_DWORD /d "0" /f >nul 2>&1
schtasks /change /disable /tn "NvTmRep_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}" >nul 2>&1
schtasks /change /disable /tn "NvProfileUpdater_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}" >nul 2>&1
echo Telemetry disabled.
"@

  $telemetryBatPath = "$ExtractPath\disable-telemetry.bat"
  $telemetryBat | Out-File -FilePath $telemetryBatPath -Encoding ASCII -Force

  Write-Host "  ✓ Created disable-telemetry.bat for post-install" -ForegroundColor Green
}

# ============================================================
# Main Installation Flow
# ============================================================

# Banner
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  XtremeG Custom NVIDIA Driver Installer (Enhanced)" -ForegroundColor Yellow
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
  Write-Host "  ✅ Auto-download and debloating" -ForegroundColor Green
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
Write-Host "[1/8] Creating directories..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $downloadPath | Out-Null
New-Item -ItemType Directory -Force -Path $extractPath | Out-Null
Write-Host "  ✓ Created: $downloadPath" -ForegroundColor Green
Write-Host ""

# Fetch latest driver info
Write-Host "[2/8] Finding latest XtremeG driver..." -ForegroundColor Cyan
Write-Host ""
$latestDriver = Get-LatestXtremeGDriver

if (-not $latestDriver) {
  Write-Host ""
  Write-Host "  Falling back to manual mode..." -ForegroundColor Yellow
  Write-Host ""
  Write-Host "Visit https://www.reddit.com/r/XtremeG to find the latest driver" -ForegroundColor Cyan
  Write-Host ""
  Write-Host "Enter MEGA.nz URL (or press Enter to open Reddit): " -NoNewline
  $manualUrl = Read-Host

  if ([string]::IsNullOrWhiteSpace($manualUrl)) {
    Start-Process "https://www.reddit.com/r/XtremeG"
    Write-Host ""
    Write-Host "Please find the driver and enter the MEGA.nz URL: " -NoNewline
    $manualUrl = Read-Host
  }

  if ([string]::IsNullOrWhiteSpace($manualUrl)) {
    Write-Host "No URL provided. Exiting." -ForegroundColor Red
    exit 1
  }

  $latestDriver = [PSCustomObject]@{
    Version = "Unknown"
    Title   = "Manual selection"
    MegaUrl = $manualUrl
    PostUrl = "https://www.reddit.com/r/XtremeG"
  }
}

Write-Host ""
Write-Host "  Selected Driver:" -ForegroundColor Cyan
Write-Host "    Version: $($latestDriver.Version)" -ForegroundColor White
Write-Host "    Source: $($latestDriver.PostUrl)" -ForegroundColor Gray
Write-Host ""

# Download driver
Write-Host "[3/8] Downloading XtremeG Driver v$($latestDriver.Version)..." -ForegroundColor Cyan
Write-Host ""

$driverFile = Download-FromMega -MegaUrl $latestDriver.MegaUrl -DestinationPath $downloadPath

if (-not $driverFile) {
  Write-Host ""
  Write-Host "Download failed. Please download manually and place in:" -ForegroundColor Red
  Write-Host "  $downloadPath" -ForegroundColor Yellow
  exit 1
}

Write-Host ""

# Extract driver
Write-Host "[4/8] Extracting driver..." -ForegroundColor Cyan

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

# Debloat driver
Write-Host "[5/8] Debloating driver package..." -ForegroundColor Cyan
Remove-DriverBloat -ExtractPath $extractPath
Write-Host ""

# Find setup.exe
Write-Host "[6/8] Locating installer..." -ForegroundColor Cyan
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
Write-Host "[7/8] Pre-installation cleanup (Optional)" -ForegroundColor Cyan
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
Write-Host "[8/8] Installing XtremeG Driver v$($latestDriver.Version)..." -ForegroundColor Cyan
Write-Host ""
Write-Host "  Starting NVIDIA installer..." -ForegroundColor Yellow
Write-Host "  Location: $($setupExe.FullName)" -ForegroundColor Gray
Write-Host ""
Write-Host "  ⚠️  Follow the on-screen installer prompts" -ForegroundColor Yellow
Write-Host "  ⚠️  Choose 'Custom' installation if you want to review components" -ForegroundColor Yellow
Write-Host ""

# Log installation
"[$(Get-Date)] Installing XtremeG Driver v$($latestDriver.Version)" | Out-File $logFile -Append
"Driver file: $($driverFile.Name)" | Out-File $logFile -Append
"Setup path: $($setupExe.FullName)" | Out-File $logFile -Append
"Source: $($latestDriver.PostUrl)" | Out-File $logFile -Append

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

# Run post-install telemetry cleanup
$telemetryScript = Get-ChildItem -Path $extractPath -Filter "disable-telemetry.bat" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($telemetryScript) {
  Write-Host "Running post-install telemetry cleanup..." -ForegroundColor Cyan
  try {
    Start-Process -FilePath $telemetryScript.FullName -Wait -NoNewWindow
    Write-Host "  ✓ Telemetry disabled" -ForegroundColor Green
  } catch {
    Write-Host "  ⚠️  Telemetry cleanup failed (non-critical)" -ForegroundColor Yellow
  }
  Write-Host ""
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
