<#
.SYNOPSIS
    Downloads large configuration files that are not stored in the repository.
.DESCRIPTION
    This script downloads large binary/configuration files that have been
    externalized from the repository to reduce its size.
    Files downloaded:
    - MSI Afterburner skin (defaultX.uxf) - 3.7MB
    - BleachBit winapp2.ini configuration - 1.1MB
.NOTES
    Author: Repository Optimization
    Version: 1.0
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# URLs for large assets (using a common hosting solution)
# Note: These URLs should be updated with actual hosting locations
$assets = @(
    @{
        Name = "MSI Afterburner Skin (defaultX)"
        Url = "https://github.com/Ven0m0/Win-Assets/raw/main/defaultX.uxf"
        Destination = "$env:USERPROFILE\.dotfiles\config\msi-afterburner\Skins\defaultX.uxf"
        Size = "3.7MB"
    },
    @{
        Name = "BleachBit winapp2.ini"
        Url = "https://raw.githubusercontent.com/bleachbit/winapp2.ini/master/winapp2.ini"
        Destination = "$env:USERPROFILE\.dotfiles\config\bleachbit\winapp2.ini"
        Size = "1.1MB"
    }
)

Write-Host "Downloading large configuration assets..." -ForegroundColor Cyan
Write-Host "This reduces repository size by ~5MB" -ForegroundColor Gray
Write-Host ""

foreach ($asset in $assets) {
    $destDir = Split-Path -Parent $asset.Destination

    # Create destination directory if it doesn't exist
    if (-not (Test-Path $destDir)) {
        Write-Host "Creating directory: $destDir" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    # Skip if file already exists
    if (Test-Path $asset.Destination) {
        Write-Host "[SKIP] $($asset.Name) already exists" -ForegroundColor Green
        continue
    }

    Write-Host "Downloading: $($asset.Name) ($($asset.Size))..." -ForegroundColor Cyan

    try {
        # Try using aria2c first (faster, multi-connection downloads)
        if (Get-Command aria2c -ErrorAction SilentlyContinue) {
            aria2c --console-log-level=error --summary-interval=0 `
                   -x 16 -s 16 -k 1M `
                   -d (Split-Path -Parent $asset.Destination) `
                   -o (Split-Path -Leaf $asset.Destination) `
                   $asset.Url
        }
        # Fallback to Invoke-WebRequest
        else {
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $asset.Url -OutFile $asset.Destination -UseBasicParsing
            $ProgressPreference = 'Continue'
        }

        Write-Host "[OK] Downloaded $($asset.Name)" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to download $($asset.Name): $_"
        Write-Host "You can manually download from: $($asset.Url)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Asset download complete!" -ForegroundColor Green
