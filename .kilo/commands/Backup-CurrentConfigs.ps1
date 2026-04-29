#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Backup current system configurations before making changes.
.DESCRIPTION
    Creates snapshots of current system state: registry exports (key areas),
    installed package lists (winget, Appx), service states, and PowerShell profile.
    Useful for rollback documentation or pre-change safety nets.
.PARAMETER ExportRegistry
    Export registry keys (HKCU\Software, HKLM\SOFTWARE\Ven0m0* pattern) to .reg files.
.PARAMETER ListPackages
    Save winget list and Appx package lists to JSON.
.PARAMETER ListServices
    Capture service states (running/stopped/startType) to CSV.
.PARAMETER All
    Perform all backup operations (default if no switches).
.PARAMETER OutputDir
    Directory for backup files. Default: ./backups/$(Get-Date -Format 'yyyy-MM-dd_HHmm')
.PARAMETER Compress
    Bundle all backups into a ZIP archive.
.PARAMETER KeepLocal
    Keep uncompressed backup files alongside ZIP (if -Compress used).
.EXAMPLE
    .\Backup-CurrentConfigs.ps1 -All
.EXAMPLE
    .\Backup-CurrentConfigs.ps1 -ExportRegistry -ListPackages -OutputDir C:\Backups\PreChange
.EXAMPLE
    .\Backup-CurrentConfigs.ps1 -Compress
    # Creates timestamped ZIP of all backups
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(ParameterSetName = 'Registry')]
    [switch]$ExportRegistry,

    [Parameter(ParameterSetName = 'Packages')]
    [switch]$ListPackages,

    [Parameter(ParameterSetName = 'Services')]
    [switch]$ListServices,

    [Parameter(ParameterSetName = 'All')]
    [switch]$All,

    [string]$OutputDir,
    [switch]$Compress,
    [switch]$KeepLocal
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSScriptRoot -like "*.kilo/commands/*") {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $scriptDir = $PSScriptRoot
} else {
    $repoRoot = $PWD
    $scriptDir = $PWD
}

$timestamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
$backupRoot = if ($OutputDir) { $OutputDir } else { Join-Path $scriptDir "backups\$timestamp" }

# Ensure output directory
if (-not (Test-Path $backupRoot)) {
    New-Item -Path $backupRoot -ItemType Directory -Force | Out-Null
}

Write-Host '=== Backup Current Configurations ===' -ForegroundColor Cyan
Write-Host "  Output: $backupRoot" -ForegroundColor Gray

$filesCreated = @()

# --- Registry Export ---
if ($All -or $ExportRegistry) {
    Write-Host '`n[1/3] Exporting registry...' -ForegroundColor Cyan
    $regDir = Join-Path $backupRoot 'registry'
    New-Item -Path $regDir -ItemType Directory -Force | Out-Null

    $registryKeys = @(
        'HKCU:\Software',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies',
        'HKCU:\System\GameConfig',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'
    )

    foreach ($key in $registryKeys) {
        if (Test-Path $key) {
            $safeName = ($key -replace '[:\\]', '_').TrimStart('_')
            $regFile = Join-Path $regDir "$safeName.reg"
            Write-Host "  Exporting $key" -ForegroundColor Gray
            try {
                reg export $key $regFile /y | Out-Null
                $filesCreated += $regFile
            } catch {
                Write-Warning "  Failed to export $key: $_"
            }
        }
    }
    Write-Host "  Registry backup: $($filesCreated.Count) files" -ForegroundColor Green
}

# --- Package Lists ---
if ($All -or $ListPackages) {
    Write-Host '`n[2/3] Capturing package lists...' -ForegroundColor Cyan
    $pkgDir = Join-Path $backupRoot 'packages'
    New-Item -Path $pkgDir -ItemType Directory -Force | Out-Null

    # winget list
    $wingetFile = Join-Path $pkgDir 'winget-list.json'
    try {
        $wingetList = winget list --source winget 2>&1 | Out-String
        $wingetList | ConvertFrom-Csv -Delimiter "`t" -Header Name,Id,Version,Source |
            ConvertTo-Json -Depth 3 | Set-Content $wingetFile
        $filesCreated += $wingetFile
        Write-Host "  winget packages saved: $wingetFile" -ForegroundColor Gray
    } catch {
        Write-Warning "  winget list failed: $_"
    }

    # Appx packages (all users)
    $appxFile = Join-Path $pkgDir 'appx-packages.json'
    try {
        $appx = Get-AppxPackage -AllUsers | Select-Object Name, PackageFullName, Version, Publisher
        $appx | ConvertTo-Json -Depth 3 | Set-Content $appxFile
        $filesCreated += $appxFile
        Write-Host "  Appx packages saved: $appxFile" -ForegroundColor Gray
    } catch {
        Write-Warning "  Appx enumeration failed: $_"
    }

    # Provisioned Appx (system-wide)
    $provFile = Join-Path $pkgDir 'appx-provisioned.json'
    try {
        $prov = Get-AppxProvisionedPackage -Online | Select-Object DisplayName, PackageName
        $prov | ConvertTo-Json -Depth 3 | Set-Content $provFile
        $filesCreated += $provFile
    } catch {
        Write-Warning "  AppxProvisioned enumeration failed: $_"
    }
}

# --- Service States ---
if ($All -or $ListServices) {
    Write-Host '`n[3/3] Capturing service states...' -ForegroundColor Cyan
    $svcDir = Join-Path $backupRoot 'services'
    New-Item -Path $svcDir -ItemType Directory -Force | Out-Null

    $svcFile = Join-Path $svcDir 'services.csv'
    try {
        $services = Get-Service | Select-Object Name, DisplayName, Status, StartType, ServiceType
        $services | Export-Csv -Path $svcFile -NoTypeInformation
        $filesCreated += $svcFile
        Write-Host "  Service states saved: $svcFile" -ForegroundColor Gray
    } catch {
        Write-Warning "  Service enumeration failed: $_"
    }
}

# --- PowerShell Profile Snapshot ---
$profileBackup = Join-Path $backupRoot 'profile.ps1'
if (Test-Path $PROFILE) {
    Copy-Item $PROFILE $profileBackup -Force
    $filesCreated += $profileBackup
    Write-Host "  Profile snapshot: $profileBackup" -ForegroundColor Gray
}

# --- Summary ---
Write-Host ''
Write-Host "Backup complete. $($filesCreated.Count) file(s) saved." -ForegroundColor Green

if ($Compress) {
    $zipPath = "$backupRoot.zip"
    Write-Host "  Compressing to $zipPath ..." -ForegroundColor Cyan
    Compress-Archive -Path (Join-Path $backupRoot '*') -DestinationPath $zipPath -Force
    Write-Host "  ZIP created: $zipPath" -ForegroundColor Green

    if (-not $KeepLocal) {
        Remove-Item $backupRoot -Recurse -Force
        Write-Host "  Temporary files removed (kept ZIP only)." -ForegroundColor Gray
    }
}

Write-Host ''
Write-Host '  Manifest:' -ForegroundColor Gray
foreach ($f in $filesCreated) {
    Write-Host "    $f"
}
Write-Host ''

if (-not $Compress) {
    Write-Host "  Backup directory: $backupRoot" -ForegroundColor Gray
}
