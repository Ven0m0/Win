#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploys all tracked configuration files to their system locations.
.DESCRIPTION
    Consolidates config deployment from Setup-Dotfiles.ps1 without requiring yadm.
    Deploys PowerShell profile, Windows Terminal settings, Firefox user.js, CMD aliases,
    game configs, and other tracked configurations.
.PARAMETER WhatIf
    Shows what would be deployed without making changes.
.PARAMETER SkipConfirmation
    Skips confirmation prompts for deployments.
.EXAMPLE
    .\Deploy-Config.ps1
.EXAMPLE
    .\Deploy-Config.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$SkipConfirmation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:StartTime = Get-Date
$script:Results = @{}
$script:ConfigRoot = Join-Path $PSScriptRoot '..\user\.dotfiles\config'

# Resolve to absolute path if relative
if (-not (Test-Path $script:ConfigRoot)) {
    $script:ConfigRoot = Join-Path $HOME 'user\.dotfiles\config'
}

function Write-Status {
    param([string]$Message, [string]$Status = 'INFO')
    $color = switch ($Status) { 'OK' { 'Green' } 'FAIL' { 'Red' } 'SKIP' { 'Yellow' } 'UP-TO-DATE' { 'Gray' } default { 'White' } }
    Write-Host "  [$Status] $Message" -ForegroundColor $color
    $script:Results[$Message] = $Status
}

function Deploy-ConfigFile {
    <#
    .SYNOPSIS
        Deploys a config file, copying only if the source differs from the destination.
    #>
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Label
    )

    if (-not (Test-Path $Source)) {
        Write-Status "$Label - source not found: $Source" -Status 'SKIP'
        return $false
    }

    $destDir = Split-Path $Destination -Parent
    $srcHash = (Get-FileHash $Source -Algorithm SHA256).Hash

    if (Test-Path $Destination) {
        $dstHash = (Get-FileHash $Destination -Algorithm SHA256).Hash
        if ($srcHash -eq $dstHash) {
            Write-Status "$Label - up to date" -Status 'UP-TO-DATE'
            return $false
        }
    }

    if ($PSCmdlet.ShouldProcess($Destination, "Deploy $Label")) {
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        Copy-Item $Source $Destination -Force
        Write-Status "$Label deployed" -Status 'OK'
        return $true
    }
    return $false
}

function Deploy-ConfigDirectory {
    <#
    .SYNOPSIS
        Deploys all files matching a filter from a source directory to a destination directory.
    #>
    param(
        [string]$SourceDir,
        [string]$DestDir,
        [string]$Filter = '*',
        [string]$Label
    )

    if (-not (Test-Path $SourceDir)) {
        Write-Status "$Label - source directory not found: $SourceDir" -Status 'SKIP'
        return
    }

    $files = Get-ChildItem -Path $SourceDir -Filter $Filter -File
    if ($files.Count -eq 0) {
        Write-Status "$Label - no files matching '$Filter'" -Status 'SKIP'
        return
    }

    foreach ($file in $files) {
        Deploy-ConfigFile -Source $file.FullName -Destination (Join-Path $DestDir $file.Name) -Label "$Label/$($file.Name)"
    }
}

function Import-RegistryConfig {
    <#
    .SYNOPSIS
        Imports a registry file into the local registry.
    #>
    param(
        [string]$Source,
        [string]$Label
    )

    if (-not (Test-Path $Source)) {
        Write-Status "$Label - source not found: $Source" -Status 'SKIP'
        return
    }

    if ($PSCmdlet.ShouldProcess('Registry', "Import $Label")) {
        & reg.exe import $Source 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Status "$Label imported" -Status 'OK'
        } else {
            Write-Status "$Label - reg import exit code: $LASTEXITCODE" -Status 'SKIP'
        }
    }
}

function Get-FirefoxDefaultProfilePath {
    $profilesIni = Join-Path $env:APPDATA 'Mozilla\Firefox\profiles.ini'
    if (-not (Test-Path $profilesIni)) {
        return $null
    }

    $profiles = [System.Collections.Generic.List[hashtable]]::new()
    $currentProfile = $null

    foreach ($line in [System.IO.File]::ReadLines($profilesIni)) {
        if ($line -match '^\[(?<section>[^\]]+)\]$') {
            if ($currentProfile -and $currentProfile.Section -like 'Profile*') {
                $profiles.Add($currentProfile)
            }
            $currentProfile = @{ Section = $matches.section }
            continue
        }

        if ($currentProfile -and $line -match '^(?<key>[^=]+)=(?<value>.*)$') {
            $currentProfile[$matches.key] = $matches.value
        }
    }

    if ($currentProfile -and $currentProfile.Section -like 'Profile*') {
        $profiles.Add($currentProfile)
    }

    if ($profiles.Count -eq 0) {
        return $null
    }

    $defaultProfile = $profiles | Where-Object { $_.Default -eq '1' } | Select-Object -First 1
    if (-not $defaultProfile) {
        $defaultProfile = $profiles | Select-Object -First 1
    }

    if (-not $defaultProfile.Path) {
        return $null
    }

    if ($defaultProfile.IsRelative -eq '1') {
        return Join-Path (Split-Path $profilesIni -Parent) $defaultProfile.Path
    }

    return $defaultProfile.Path
}

function Get-CallOfDutyPlayersPath {
    $playersPath = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Call of Duty\players'
    if (Test-Path $playersPath) {
        return $playersPath
    }
    return $null
}

function Get-StarWarsBattlefrontIIRootPath {
    return (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Star Wars Battlefront II')
}

function Get-StarWarsBattlefrontIIActiveProfilePath {
    $bf2Root = Get-StarWarsBattlefrontIIRootPath
    $profilesDir = Join-Path $bf2Root 'Profiles'
    if (-not (Test-Path $profilesDir)) {
        return $null
    }

    $globalConfigPath = Join-Path $profilesDir 'Global.con'
    if (Test-Path $globalConfigPath) {
        foreach ($line in [System.IO.File]::ReadLines($globalConfigPath)) {
            if ($line -match 'GlobalSettings\.setDefaultUser\s+"?(?<profileId>[^"\r\n]+)"?') {
                $profilePath = Join-Path $profilesDir $matches.profileId
                if (Test-Path $profilePath) {
                    return $profilePath
                }
            }
        }
    }

    return (
        Get-ChildItem -Path $profilesDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'Default' } |
            Sort-Object Name |
            Select-Object -First 1 -ExpandProperty FullName
    )
}

function Set-CmdAliasAutoRun {
    <#
    .SYNOPSIS
        Configures cmd.exe AutoRun to load tracked DOSKEY aliases.
    #>
    param([string]$AliasScript, [string]$Label)

    if (-not (Test-Path $AliasScript)) {
        Write-Status "$Label - alias script not found: $AliasScript" -Status 'SKIP'
        return
    }

    $commandProcessorKey = 'HKCU:\Software\Microsoft\Command Processor'
    $autoRunSnippet = "if exist `"$AliasScript`" call `"$AliasScript`""
    $currentAutoRun = (Get-ItemProperty -Path $commandProcessorKey -Name AutoRun -ErrorAction SilentlyContinue).AutoRun

    if ($currentAutoRun -and $currentAutoRun -match [regex]::Escape($AliasScript)) {
        Write-Status "$Label - already configured" -Status 'UP-TO-DATE'
        return
    }

    $newAutoRun = if ([string]::IsNullOrWhiteSpace($currentAutoRun)) {
        $autoRunSnippet
    } else {
        "$currentAutoRun & $autoRunSnippet"
    }

    if ($PSCmdlet.ShouldProcess($commandProcessorKey, "Configure $Label")) {
        if (-not (Test-Path $commandProcessorKey)) {
            New-Item -Path $commandProcessorKey -Force | Out-Null
        }
        New-ItemProperty -Path $commandProcessorKey -Name AutoRun -Value $newAutoRun -PropertyType String -Force | Out-Null
        Write-Status "$Label configured" -Status 'OK'
    }
}

function Deploy-StarWarsBattlefrontIIConfigs {
    <#
    .SYNOPSIS
        Deploys Star Wars Battlefront II (2017) configs.
    #>
    param([string]$SourceDir, [string]$Label)

    if (-not (Test-Path $SourceDir)) {
        return
    }

    $bf2Root = Get-StarWarsBattlefrontIIRootPath
    if (-not (Test-Path $bf2Root)) {
        Write-Status "$Label - Star Wars Battlefront II directory not found" -Status 'SKIP'
        return
    }

    $activeProfilePath = Get-StarWarsBattlefrontIIActiveProfilePath
    if (-not $activeProfilePath) {
        Write-Status "$Label - active profile not found" -Status 'SKIP'
        return
    }

    $rootFiles = @('BootOptions', 'user.cfg')
    foreach ($fileName in $rootFiles) {
        $sourcePath = Join-Path $SourceDir $fileName
        if (Test-Path $sourcePath) {
            Deploy-ConfigFile -Source $sourcePath -Destination (Join-Path $bf2Root $fileName) -Label "$Label/$fileName"
        }
    }

    $profileOptionsPath = Join-Path $SourceDir 'ProfileOptions_profile'
    if (Test-Path $profileOptionsPath) {
        Deploy-ConfigFile -Source $profileOptionsPath -Destination (Join-Path $activeProfilePath 'ProfileOptions_profile') -Label "$Label/ProfileOptions_profile"
    }
}

# ============================================================================
# Phase 1: Verify config root exists
# ============================================================================
Write-Host '[1/5] Verifying configuration source...' -ForegroundColor Cyan

if (-not (Test-Path $script:ConfigRoot)) {
    Write-Status "Config directory not found: $script:ConfigRoot" -Status 'FAIL'
    Write-Host "  Ensure the repository is cloned or the config directory exists." -ForegroundColor Yellow
    exit 1
}

Write-Status "Config root: $script:ConfigRoot" -Status 'OK'

# ============================================================================
# Phase 2: Deploy PowerShell profile
# ============================================================================
Write-Host ''
Write-Host '[2/5] Deploying PowerShell profile...' -ForegroundColor Cyan

$profileSource = Join-Path $script:ConfigRoot 'powershell\profile.ps1'
if (Test-Path $profileSource) {
    Deploy-ConfigFile -Source $profileSource -Destination $PROFILE -Label 'PowerShell profile'
} else {
    Write-Status 'PowerShell profile source not found' -Status 'SKIP'
}

# ============================================================================
# Phase 3: Deploy Windows Terminal settings
# ============================================================================
Write-Host ''
Write-Host '[3/5] Deploying Windows Terminal settings...' -ForegroundColor Cyan

$wtSettingsSource = Join-Path $script:ConfigRoot 'windows-terminal\settings.json'
$wtPackageDir = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Filter 'Microsoft.WindowsTerminal_*' -Directory -ErrorAction SilentlyContinue | Select-Object -First 1

if ($wtPackageDir -and (Test-Path $wtSettingsSource)) {
    $wtTarget = Join-Path $wtPackageDir.FullName 'LocalState\settings.json'
    Deploy-ConfigFile -Source $wtSettingsSource -Destination $wtTarget -Label 'Windows Terminal settings'
} elseif (-not $wtPackageDir) {
    Write-Status 'Windows Terminal package directory not found' -Status 'SKIP'
} else {
    Write-Status 'Windows Terminal settings source not found' -Status 'SKIP'
}

# ============================================================================
# Phase 4: Deploy application configs
# ============================================================================
Write-Host ''
Write-Host '[4/5] Deploying application configs...' -ForegroundColor Cyan

# Firefox user.js
$firefoxSource = Join-Path $script:ConfigRoot 'firefox\user.js'
$firefoxProfile = Get-FirefoxDefaultProfilePath
if ($firefoxProfile -and (Test-Path $firefoxSource)) {
    Deploy-ConfigFile -Source $firefoxSource -Destination (Join-Path $firefoxProfile 'user.js') -Label 'Firefox user.js'
} elseif (-not $firefoxProfile) {
    Write-Status 'Firefox profile not found' -Status 'SKIP'
}

# BleachBit cleaners
$bleachbitSource = Join-Path $script:ConfigRoot 'bleachbit\cleaners'
$bleachbitDest = "$env:APPDATA\BleachBit\cleaners"
if (Test-Path $bleachbitSource) {
    Deploy-ConfigDirectory -SourceDir $bleachbitSource -DestDir $bleachbitDest -Filter '*.xml' -Label 'BleachBit cleaners'
}

# Brave debloater registry
$braveRegSource = Join-Path $script:ConfigRoot 'brave\brave_debloater.reg'
if (Test-Path $braveRegSource) {
    Import-RegistryConfig -Source $braveRegSource -Label 'Brave policies'
}

# CMD aliases
$cmdAliasSource = Join-Path $script:ConfigRoot 'cmd\alias.cmd'
if (Test-Path $cmdAliasSource) {
    Set-CmdAliasAutoRun -AliasScript $cmdAliasSource -Label 'CMD aliases'
}

# ============================================================================
# Phase 5: Deploy game configs
# ============================================================================
Write-Host ''
Write-Host '[5/5] Deploying game configs...' -ForegroundColor Cyan

# Star Wars Battlefront II (2017)
$bf2Source = Join-Path $script:ConfigRoot 'games\bf2'
if (Test-Path $bf2Source) {
    Deploy-StarWarsBattlefrontIIConfigs -SourceDir $bf2Source -Label 'Star Wars Battlefront II (2017)'
}

# Call of Duty Black Ops 6
$bo6Source = Join-Path $script:ConfigRoot 'games\bo6'
$codPlayersPath = Get-CallOfDutyPlayersPath
if ($codPlayersPath -and (Test-Path $bo6Source)) {
    Deploy-ConfigDirectory -SourceDir $bo6Source -DestDir $codPlayersPath -Filter '*' -Label 'Call of Duty Black Ops 6'
} elseif (-not $codPlayersPath) {
    Write-Status 'Call of Duty players directory not found' -Status 'SKIP'
}

# Call of Duty Black Ops 7
$bo7Source = Join-Path $script:ConfigRoot 'games\bo7'
if ($codPlayersPath -and (Test-Path $bo7Source)) {
    Deploy-ConfigDirectory -SourceDir $bo7Source -DestDir $codPlayersPath -Filter '*' -Label 'Call of Duty Black Ops 7'
}

# Arc Raiders
$arcRaidersSource = Join-Path $script:ConfigRoot 'games\arc-raiders'
$documentsPath = [Environment]::GetFolderPath('MyDocuments')
$arcRaidersPath = Join-Path $documentsPath 'ArcRaiders\Saved\Config\WindowsClient'
if ((Test-Path $arcRaidersSource) -and (Test-Path (Split-Path $arcRaidersPath -Parent))) {
    Deploy-ConfigDirectory -SourceDir $arcRaidersSource -DestDir $arcRaidersPath -Filter '*' -Label 'Arc Raiders'
}

# ============================================================================
# Phase 6: PATH and directory setup
# ============================================================================
Write-Host ''
Write-Host '[6/5] Configuring PATH and directories...' -ForegroundColor Cyan

$scriptsPath = Join-Path $HOME 'Scripts'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

if (-not $userPath) { $userPath = '' }

if ($userPath -notlike "*$scriptsPath*") {
    if ($PSCmdlet.ShouldProcess('User PATH', "Add $scriptsPath")) {
        $newPath = ($userPath.TrimEnd(';') + ";$scriptsPath").TrimStart(';')
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
        Write-Status "Added Scripts to PATH" -Status 'OK'
    }
} else {
    Write-Status 'Scripts already in PATH' -Status 'UP-TO-DATE'
}

# Create common directories
$commonDirs = @(
    "$HOME\.local\bin",
    "$HOME\.cache",
    "$HOME\Projects"
)

foreach ($dir in $commonDirs) {
    if (-not (Test-Path $dir)) {
        if ($PSCmdlet.ShouldProcess($dir, 'Create directory')) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Status "Created $dir" -Status 'OK'
        }
    } else {
        Write-Status "Directory exists: $dir" -Status 'UP-TO-DATE'
    }
}

# ============================================================================
# Summary
# ============================================================================
Write-Host ''
Write-Host 'Configuration Deployment Summary' -ForegroundColor Cyan
Write-Host ''

$successCount = 0
$failCount = 0
$skipCount = 0
$upToDateCount = 0

foreach ($key in $script:Results.Keys | Sort-Object) {
    $status = $script:Results[$key]
    $color = switch ($status) { 'OK' { 'Green' } 'FAIL' { 'Red' } 'SKIP' { 'Yellow' } 'UP-TO-DATE' { 'Gray' } default { 'White' } }
    Write-Host "  $($key.PadRight(50)) : " -NoNewline; Write-Host "$status" -ForegroundColor $color
    
    switch ($status) {
        'OK' { $successCount++ }
        'FAIL' { $failCount++ }
        'SKIP' { $skipCount++ }
        'UP-TO-DATE' { $upToDateCount++ }
    }
}

Write-Host ""
Write-Host "  Results: " -NoNewline
Write-Host "$successCount deployed" -ForegroundColor Green -NoNewline
Write-Host ", " -NoNewline
Write-Host "$upToDateCount up-to-date" -ForegroundColor Gray -NoNewline
Write-Host ", " -NoNewline
Write-Host "$skipCount skipped" -ForegroundColor Yellow -NoNewline
if ($failCount -gt 0) {
    Write-Host ", " -NoNewline
    Write-Host "$failCount failed" -ForegroundColor Red
} else {
    Write-Host ""
}

$duration = (Get-Date) - $script:StartTime
Write-Host "  Total time: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Restart your terminal to apply the new profile." -ForegroundColor Cyan
Write-Host ""