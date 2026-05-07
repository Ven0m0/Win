#Requires -Version 5.1

<#
.SYNOPSIS
    Steam Optimization Script
.DESCRIPTION
    Cleans Steam redistributable installer caches and integrates NoSteamWebHelper (umpdc.dll)
    to reduce Steam's resource usage. Run with Steam closed.
.PARAMETER Action
    Action to perform: CleanRedist, InstallNoSteamWebHelper, RestoreNoSteamWebHelper, All
.PARAMETER SteamPath
    Custom Steam installation path. If not provided, auto-detected from registry.
.PARAMETER DryRun
    Show what would be done without making changes
.EXAMPLE
    .\Optimize-Steam.ps1 -Action CleanRedist
.EXAMPLE
    .\Optimize-Steam.ps1 -Action InstallNoSteamWebHelper
.EXAMPLE
    .\Optimize-Steam.ps1 -Action All -DryRun
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('CleanRedist', 'InstallNoSteamWebHelper', 'RestoreNoSteamWebHelper', 'All')]
    [string]$Action = 'All',
    [string]$SteamPath,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Import common functions
. "$PSScriptRoot\Common.ps1"

function Get-SteamPath {
    if ($SteamPath) { return $SteamPath }
    try {
        $regPath = Get-ItemProperty 'HKLM:\Software\Wow6432Node\Valve\Steam' -Name InstallPath -ErrorAction SilentlyContinue
        if ($regPath) { return $regPath.InstallPath }
    } catch { }
    try {
        $regPath = Get-ItemProperty 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction SilentlyContinue
        if ($regPath) { return $regPath.SteamPath }
    } catch { }
    return "${env:ProgramFiles(x86)}\Steam"
}

function Invoke-CleanRedist {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$SteamPath)

    $steamPath = Get-SteamPath
    if (-not (Test-Path "$steamPath\Steam.exe")) {
        Write-Warning "Steam not found at: $steamPath"
        return
    }

    Write-Host "Cleaning Steam redistributable installer caches..." -ForegroundColor Cyan

    $redistPaths = @(
        "$steamPath\steamapps\common\Steamworks Shared\_CommonRedist\DirectX",
        "$steamPath\steamapps\common\Steamworks Shared\_CommonRedist\vcredist"
    )

    $totalFreed = 0
    foreach ($path in $redistPaths) {
        if (Test-Path $path) {
            $beforeSize = (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $filesRemoved = 0

            Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                if ($PSCmdlet.ShouldProcess($_.FullName, "Remove installer file")) {
                    Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                    $filesRemoved++
                }
            }

            $afterSize = (Get-ChildItem -Path $path -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            $freed = $beforeSize - ($afterSize -or 0)
            $totalFreed += $freed

            if ($filesRemoved -gt 0) {
                Write-Host "  Removed $filesRemoved file(s) from $($path.Split('\')[-2,-1] -join '\')" -ForegroundColor Green
                if ($freed -gt 1MB) {
                    Write-Host "    Freed $([math]::Round($freed/1MB, 2)) MB" -ForegroundColor Gray
                }
            }
        }
    }

    if ($totalFreed -gt 0) {
        Write-Host "Total space freed: $([math]::Round($totalFreed/1MB, 2)) MB" -ForegroundColor Green
    } else {
        Write-Host "No installer files found to clean" -ForegroundColor Yellow
    }
}

function Invoke-InstallNoSteamWebHelper {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$SteamPath)

    $steamPath = Get-SteamPath
    $targetDll = Join-Path $steamPath "umpdc.dll"
    $backupDll = "$targetDll.bak"

    if ($PSCmdlet.ShouldProcess("Download NoSteamWebHelper DLL")) {
        Write-Host "Downloading NoSteamWebHelper DLL..." -ForegroundColor Cyan
        Write-Warning "This modifies Steam's Web Helper DLL. Steam features (Store, Community) may not work afterward."
        $ProgressPreference = 'SilentlyContinue'

        try {
            $url = "https://github.com/Aetopia/NoSteamWebHelper/releases/latest/download/umpdc.dll"
            $tempDll = Join-Path $env:TEMP "umpdc.dll"

            # Download the DLL with TLS 1.2+ enforced
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri $url -OutFile $tempDll -UseBasicParsing -ErrorAction Stop

            # Validate file was downloaded (not empty)
            $fileSize = (Get-Item $tempDll).Length
            if ($fileSize -lt 100kb) {
                Remove-Item $tempDll -Force -ErrorAction SilentlyContinue
                throw "Downloaded file is too small ($fileSize bytes) - download may have failed"
            }

            # Backup existing DLL if present
            if ((Test-Path $targetDll) -and -not (Test-Path $backupDll)) {
                Copy-Item $targetDll $backupDll -Force
                Write-Host "  Backed up original DLL to umpdc.dll.bak" -ForegroundColor Yellow
            }

            # Replace the DLL
            Copy-Item $tempDll $targetDll -Force
            Remove-Item $tempDll -Force -ErrorAction SilentlyContinue

            Write-Host "NoSteamWebHelper installed successfully" -ForegroundColor Green
            Write-Warning "Steam Web Helper has been disabled. Some features (Store, Community) may not work."
        } catch {
            Write-Warning "Failed to download NoSteamWebHelper: $_"
        }
    }
}

function Invoke-RestoreNoSteamWebHelper {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$SteamPath)

    $steamPath = Get-SteamPath
    $targetDll = Join-Path $steamPath "umpdc.dll"
    $backupDll = "$targetDll.bak"

    if (Test-Path $backupDll) {
        if ($PSCmdlet.ShouldProcess("Restore original DLL")) {
            Copy-Item $backupDll $targetDll -Force
            Remove-Item $backupDll -Force -ErrorAction SilentlyContinue
            Write-Host "NoSteamWebHelper removed, original DLL restored" -ForegroundColor Green
        }
    } else {
        if (Test-Path $targetDll) {
            if ($PSCmdlet.ShouldProcess("Remove NoSteamWebHelper DLL")) {
                Remove-Item $targetDll -Force -ErrorAction SilentlyContinue
                Write-Host "NoSteamWebHelper DLL removed" -ForegroundColor Green
            }
        } else {
            Write-Host "NoSteamWebHelper DLL not found" -ForegroundColor Yellow
        }
    }
}

# Main execution
Write-Host "Steam Optimization Script" -ForegroundColor Cyan
Write-Host ""

$steamPath = Get-SteamPath
Write-Host "Steam path: $steamPath"
if (-not (Test-Path "$steamPath\Steam.exe")) {
    Write-Warning "Steam not found at: $steamPath"
    Write-Warning "Please verify the path or specify manually with -SteamPath"
    exit 1
}

if ($DryRun) {
    Write-Host "[DRY RUN] No changes will be made" -ForegroundColor Yellow
    Write-Host ""
}

switch ($Action) {
    'CleanRedist' { Invoke-CleanRedist -SteamPath $steamPath }
    'InstallNoSteamWebHelper' { Invoke-InstallNoSteamWebHelper -SteamPath $steamPath }
    'RestoreNoSteamWebHelper' { Invoke-RestoreNoSteamWebHelper -SteamPath $steamPath }
    'All' {
        Invoke-CleanRedist -SteamPath $steamPath
        Write-Host ""
        Invoke-InstallNoSteamWebHelper -SteamPath $steamPath
    }
}

Write-Host ""
Write-Host "Optimization complete!" -ForegroundColor Green
