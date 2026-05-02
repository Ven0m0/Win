#Requires -Version 5.1

#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Backs up game configs for Arc Raiders and Black Ops 6 to dotfiles.
.DESCRIPTION
    Copies game settings, keybinds, and preferences to the user's dotfiles.
    Does NOT copy account login credentials or sensitive data.
.EXAMPLE
    .\Backup-GameConfigs.ps1
#>

param(
    [string]$DotfilesPath = "$env:USERPROFILE\.dotfiles\config\games"
)

$ErrorActionPreference = 'Stop'

function Write-BackupStatus {
    param([string]$Message, [string]$Color = 'White')
    Write-Host "[Backup] $Message" -ForegroundColor $Color
}

$bo6Source = "$env:USERPROFILE\Documents\Call of Duty\players"
$bo6Dest = "$DotfilesPath\bo6"

$arcRaidersSource = "$env:LOCALAPPDATA\PioneerGame\Saved\SaveGames"
$arcRaidersDest = "$DotfilesPath\arc-raiders"

Write-BackupStatus "Starting game config backup..." -Color Cyan
Write-BackupStatus "Destination: $DotfilesPath" -Color Gray

if (-not (Test-Path $DotfilesPath)) {
    [void](New-Item -ItemType Directory -Path $DotfilesPath -Force)
}

if (Test-Path $bo6Source) {
    Write-BackupStatus "Backing up Black Ops 6 settings..." -Color Yellow

    if (-not (Test-Path $bo6Dest)) {
        [void](New-Item -ItemType Directory -Path $bo6Dest -Force)
    }

    $playerFolders = Get-ChildItem -Path $bo6Source -Directory -ErrorAction SilentlyContinue
    foreach ($playerFolder in $playerFolders) {
        $destPlayerFolder = Join-Path $bo6Dest $playerFolder.Name
        if (-not (Test-Path $destPlayerFolder)) {
            [void](New-Item -ItemType Directory -Path $destPlayerFolder -Force)
        }

        $filesToCopy = Get-ChildItem -Path $playerFolder.FullName -File -ErrorAction SilentlyContinue
        foreach ($file in $filesToCopy) {
            Copy-Item -Path $file.FullName -Destination $destPlayerFolder -Force
            Write-BackupStatus "  Copied: $($file.Name)" -Color Gray
        }
    }

    $rootFiles = Get-ChildItem -Path $bo6Source -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^s' }
    foreach ($file in $rootFiles) {
        Copy-Item -Path $file.FullName -Destination $bo6Dest -Force
        Write-BackupStatus "  Copied: $($file.Name)" -Color Gray
    }

    Write-BackupStatus "Black Ops 6 backup complete!" -Color Green
} else {
    Write-BackupStatus "Black Ops 6 settings not found at $bo6Source" -Color Yellow
}

if (Test-Path $arcRaidersSource) {
    Write-BackupStatus "Backing up Arc Raiders settings..." -Color Yellow

    if (-not (Test-Path $arcRaidersDest)) {
        [void](New-Item -ItemType Directory -Path $arcRaidersDest -Force)
    }

    $keybindsFile = Get-ChildItem -Path $arcRaidersSource -File -Filter "*KeyBindings*.sav" -ErrorAction SilentlyContinu
    if ($keybindsFile) {
        Copy-Item -Path $keybindsFile.FullName -Destination (Join-Path $arcRaidersDest "keybinds.sav") -Force
        Write-BackupStatus "  Copied: keybinds.sav" -Color Gray
    }

    $settingsFiles = @('GameUserSettings.ini', 'Engine.ini')
    foreach ($settingsFile in $settingsFiles) {
        $sourceFile = Get-ChildItem -Path $arcRaidersSource -File -Filter $settingsFile -Recurse -ErrorAction SilentlyCo
        if ($sourceFile) {
            Copy-Item -Path $sourceFile.FullName -Destination $arcRaidersDest -Force
            Write-BackupStatus "  Copied: $settingsFile" -Color Gray
        }
    }

    Write-BackupStatus "Arc Raiders backup complete!" -Color Green
} else {
    Write-BackupStatus "Arc Raiders settings not found at $arcRaidersSource" -Color Yellow
}

Write-BackupStatus "All game configs backed up successfully!" -Color Green