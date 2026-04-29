#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Installs all required packages and tools for the Windows development environment.
.DESCRIPTION
    Consolidates package installation from setup.ps1, Setup-Dotfiles.ps1, Setup-Win11.ps1,
    shell-setup.ps1, and auto/install.ps1. Installs tools via winget, Scoop, and Chocolatey
    without requiring a full bootstrap.
.PARAMETER SkipWinget
    Skip winget package installations.
.PARAMETER SkipScoop
    Skip Scoop package installations.
.PARAMETER SkipChoco
    Skip Chocolatey package installations.
.PARAMETER SkipSystemFeatures
    Skip Windows optional features.
.PARAMETER ApplyPostInstall
    Apply post-install Windows configuration (from autounattend.xml).
.PARAMETER PostInstallComputerName
    Computer name for post-install setup (default: PC).
.PARAMETER PostInstallTimeZone
    Timezone for post-install setup (default: W. Europe Standard Time).
.PARAMETER PostInstallInputLocale
    Input locale for post-install setup (default: en-US).
.PARAMETER PostInstallGeoId
    Geographic region ID for post-install setup (default: 94 for Germany).
.EXAMPLE
    .\Install-Packages.ps1
.EXAMPLE
    .\Install-Packages -SkipScoop -SkipChoco
.EXAMPLE
    .\Install-Packages -ApplyPostInstall
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$SkipWinget,
    [switch]$SkipScoop,
    [switch]$SkipChoco,
    [switch]$SkipSystemFeatures,
    [switch]$ApplyPostInstall,
    [string]$PostInstallComputerName = 'PC',
    [string]$PostInstallTimeZone = 'W. Europe Standard Time',
    [string]$PostInstallInputLocale = 'en-US',
    [int]$PostInstallGeoId = 94
)


function Start-InstallPackages {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$SkipWinget,
        [switch]$SkipScoop,
        [switch]$SkipChoco,
        [switch]$SkipSystemFeatures,
        [switch]$ApplyPostInstall,
        [string]$PostInstallComputerName = 'PC',
        [string]$PostInstallTimeZone = 'W. Europe Standard Time',
        [string]$PostInstallInputLocale = 'en-US',
        [int]$PostInstallGeoId = 94
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    $script:StartTime = Get-Date
    $script:Results = @{}

    function Write-Status {
        param([string]$Message, [string]$Status = 'INFO')
        $color = switch ($Status) { 'OK' { 'Green' } 'FAIL' { 'Red' } 'SKIP' { 'Yellow' } 'RUNNING' { 'Cyan' } default { 'White' } }
        Write-Host "  [$Status] $Message" -ForegroundColor $color
        $script:Results[$Message] = $Status
    }

    function Invoke-Operation {
        param([string]$Name, [scriptblock]$Action, [string]$SuccessStatus = 'OK')
        Write-Status "$Name" -Status 'RUNNING'
        try { & $Action; Write-Status "$Name" -Status $SuccessStatus; return $true }
        catch { Write-Status "$Name - $($_.Exception.Message)" -Status 'FAIL'; return $false }
    }

    function Install-WingetTool {
        param([string]$Id, [string]$Name)
        if ($PSCmdlet.ShouldProcess($Name, 'Install via winget')) {
            $winget = Wait-ForWinget
            Write-Host "  Installing $Name..." -ForegroundColor Gray -NoNewline
            try {
                $scopeArg = ''
                if ($isAdmin) { $scopeArg = '--scope machine' }
                & $winget install --id $Id --silent --accept-source-agreements `
                    --accept-package-agreements $scopeArg 2>&1 | Out-Null
                $ec = $LASTEXITCODE
                if ($ec -eq 0 -or $ec -eq -1978335189) {
                    Write-Host " [OK]" -ForegroundColor Green
                } else {
                    Write-Host ""
                    Write-Warning "  [WARN] $Name - winget exit code: $ec"
                }
            } catch {
                Write-Host ""
                Write-Warning "  [WARN] $Name - $_"
            }
        }
    }

    # ============================================================================
    # Phase 1: Prerequisites check and installation
    # ============================================================================
    Write-Host '[1/7] Checking prerequisites...' -ForegroundColor Cyan

    # Check if running as admin for system-level operations
    if ($null -eq $script:isAdminOverride) {
        $isAdmin = $false
        try {
            $isAdmin = ([Security.Principal.WindowsPrincipal]`
                [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator
            )
        } catch {}
    } else {
        $isAdmin = $script:isAdminOverride
    }

    if (-not $isAdmin) {
        Write-Host '  [REQUIRED] Some operations require administrator privileges.' -ForegroundColor Yellow
        Write-Host '  Relaunching as administrator...' -ForegroundColor Yellow
        $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
        $shell = if ($pwshCmd) { $pwshCmd.Source } else { 'PowerShell.exe' }
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        foreach ($p in 'SkipWinget','SkipScoop','SkipChoco','SkipSystemFeatures','ApplyPostInstall') {
            if ((Get-Variable $p -ErrorAction SilentlyContinue).Value) { $argList += " -$p" }
        }
        try { Start-Process $shell -ArgumentList $argList -Verb RunAs } catch {}
        return
    }

    # Set execution policy
    try {
        if ($PSCmdlet.ShouldProcess('CurrentUser execution policy', 'Set to RemoteSigned')) {
            Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Status 'Execution policy set to RemoteSigned' -Status 'OK'
        }
    } catch {
        Write-Warning "  Could not set execution policy: $_"
    }

    # Ensure winget is available (wait-loop for fresh installs)
    try {
        $null = Wait-ForWinget
        Write-Status 'winget is available' -Status 'OK'
    } catch {
        Write-Status "winget not available: $_. Install from https://aka.ms/getwinget" -Status 'FAIL'
        exit 1
    }

    # ============================================================================
    # Phase 2: Install core tools via winget
    # ============================================================================
    if (-not $SkipWinget) {
        Write-Host ''
        Write-Host '[2/7] Installing core tools via winget...' -ForegroundColor Cyan

        $coreTools = @(
            @{ id = 'Git.Git';                    name = 'Git' },
            @{ id = 'Microsoft.PowerShell';       name = 'PowerShell 7+' },
            @{ id = 'Microsoft.WindowsTerminal';  name = 'Windows Terminal' },
            @{ id = 'Microsoft.VisualStudioCode'; name = 'VS Code' }
        )

        foreach ($tool in $coreTools) {
            Install-WingetTool -Id $tool.id -Name $tool.name
        }
    }

    # ============================================================================
    # Phase 3: Install runtimes via winget
    # ============================================================================
    if (-not $SkipWinget) {
        Write-Host ''
        Write-Host '[3/7] Installing runtimes via winget...' -ForegroundColor Cyan

        $runtimes = @(
            'Microsoft.VCRedist.2015+.x64',
            'Microsoft.DotNet.DesktopRuntime.10',
            'Microsoft.DotNet.DesktopRuntime.9',
            'Microsoft.DotNet.DesktopRuntime.8',
            'Microsoft.DotNet.DesktopRuntime.7',
            'Microsoft.EdgeWebView2Runtime',
            'Oracle.JavaRuntimeEnvironment',
            'EclipseAdoptium.Temurin.25.JRE'
        )

        foreach ($pkg in $runtimes) {
            Install-WingetTool -Id $pkg -Name $pkg
        }
    }

    # ============================================================================
    # Phase 4: Install development tools and utilities via winget
    # ============================================================================
    if (-not $SkipWinget) {
        Write-Host ''
        Write-Host '[4/7] Installing development tools via winget...' -ForegroundColor Cyan

        $devTools = @(
            'OpenJS.NodeJS',
            'Python.Python.3.13',
            'GitHub.cli',
            'Notepad++.Notepad++',
            'VSCodium.VSCodium',
            'Rustlang.Rust.MSVC',
            'astral-sh.uv',
            'Oven-sh.Bun',
            'jdx.mise',
            'topgrade-rs.topgrade',
            'eza-community.eza',
            'BurntSushi.ripgrep.MSVC',
            'sharkdp.fd',
            'sharkdp.bat',
            'JanDeDobbeleer.OhMyPosh',
            '7zip.7zip',
            'VideoLAN.VLC',
            'OBSProject.OBSStudio',
            'MartiCliment.UniGetUI',
            'Chocolatey.Chocolatey'
        )

        foreach ($pkg in $devTools) {
            Install-WingetTool -Id $pkg -Name $pkg
        }
    }

    # ============================================================================
    # Phase 5: Scoop installation and packages
    # ============================================================================
    if (-not $SkipScoop) {
        Write-Host ''
        Write-Host '[5/7] Setting up Scoop...' -ForegroundColor Cyan

        # Install Scoop if not present
        if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
            Write-Status 'Installing Scoop...' -Status 'RUNNING'
            try {
                $scoopInstaller = Join-Path $env:TEMP ("install-scoop-{0}.ps1" -f [System.Guid]::NewGuid().ToString('N'))
                Invoke-RestMethod -Uri 'https://get.scoop.sh' `
                -OutFile $scoopInstaller
                & $scoopInstaller
                Remove-Item $scoopInstaller -Force -ErrorAction SilentlyContinue
                Write-Status 'Scoop installed' -Status 'OK'
            } catch {
                Write-Status "Scoop installation failed: $_" -Status 'FAIL'
            }
        } else {
            Write-Status 'Scoop already installed' -Status 'OK'
        }

        # Add Scoop buckets
        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            $scoopBuckets = @('extras', 'nerd-fonts', 'java', 'nirsoft')
            foreach ($bucket in $scoopBuckets) {
                try {
                    scoop bucket add $bucket 2>$null
                    Write-Status "Scoop bucket '$bucket' added" -Status 'OK'
                } catch {
                    Write-Status "Scoop bucket '$bucket' (may already exist)" -Status 'SKIP'
                }
            }

            # Configure aria2 for Scoop
            if (Get-Command scoop -ErrorAction SilentlyContinue) {
                scoop config aria2-enabled true 2>$null
                scoop config aria2-warning-enabled false 2>$null
            }
        }
    }

    # ============================================================================
    # Phase 6: Chocolatey installation and packages
    # ============================================================================
    if (-not $SkipChoco) {
        Write-Host ''
        Write-Host '[6/7] Setting up Chocolatey...' -ForegroundColor Cyan

        # Install Chocolatey if not present
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
            Write-Status 'Installing Chocolatey...' -Status 'RUNNING'
            try {
                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
                Invoke-RestMethod -Uri 'https://community.chocolatey.org/install.ps1' `
                -OutFile "$env:TEMP\choco-install.ps1"
                & "$env:TEMP\choco-install.ps1"
                Remove-Item "$env:TEMP\choco-install.ps1" -Force -ErrorAction SilentlyContinue
                Write-Status 'Chocolatey installed' -Status 'OK'
            } catch {
                Write-Status "Chocolatey installation failed: $_" -Status 'FAIL'
            }
        } else {
            Write-Status 'Chocolatey already installed' -Status 'OK'
        }
    }

    # ============================================================================
    # Phase 7: Windows optional features (if admin)
    # ============================================================================
    if (-not $SkipSystemFeatures -and $isAdmin) {
        Write-Host ''
        Write-Host '[7/7] Enabling Windows optional features...' -ForegroundColor Cyan

        $features = @(
            'Microsoft-Windows-Subsystem-Linux',
            'VirtualMachinePlatform',
            'LegacyComponents',
            'DirectPlay'
        )

        foreach ($feature in $features) {
            try {
                DISM /Online /Enable-Feature /FeatureName:$feature /All /NoRestart /Quiet 2>&1 | Out-Null
                Write-Status "Feature '$feature' enabled" -Status 'OK'
            } catch {
                Write-Status "Feature '$feature' (may already be enabled)" -Status 'SKIP'
            }
        }
    }

    # ============================================================================
    # Phase 8: Post-Install Windows Setup (from autounattend.xml)
    # ============================================================================
    if ($ApplyPostInstall -and $isAdmin) {
        Write-Host ''
        Write-Host '[8/7] Applying post-install Windows configuration...' -ForegroundColor Cyan

        # Set timezone
        try {
            Set-TimeZone -Name $PostInstallTimeZone -ErrorAction Stop
            Write-Status "Timezone set to '$PostInstallTimeZone'" -Status 'OK'
        } catch {
            try {
                tzutil.exe /s $PostInstallTimeZone 2>&1 | Out-Null
                Write-Status "Timezone set to '$PostInstallTimeZone' (tzutil)" -Status 'OK'
            } catch {
                Write-Status "Timezone '$PostInstallTimeZone' - $($_.Exception.Message)" -Status 'SKIP'
            }
        }

        # Disable WPBT (Windows Platform Binary Table) - prevents malicious firmware attacks
        try {
            $sysHive = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
            if (-not (Test-Path $sysHive)) {
                New-Item -Path $sysHive -Force | Out-Null
            }
            Set-ItemProperty -Path $sysHive -Name 'DisableWpbtExecution' -Value 1 -Type DWord -Force
            Write-Status 'WPBT execution disabled' -Status 'OK'
        } catch {
            Write-Status "WPBT disable failed: $($_.Exception.Message)" -Status 'SKIP'
        }

        # Set geographic region (GeoId)
        try {
            $regionKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\DeviceRegion"
            if (-not (Test-Path $regionKey)) {
                New-Item -Path $regionKey -Force | Out-Null
            }
            Set-ItemProperty -Path $regionKey -Name 'DeviceRegion' -Value $PostInstallGeoId -Type DWord -Force
            Write-Status "Geographic region set to GeoId $PostInstallGeoId" -Status 'OK'
        } catch {
            Write-Status "GeoId set failed: $($_.Exception.Message)" -Status 'SKIP'
        }

        # BypassSetup LabConfig (for future reinstallation/repair)
        $labConfig = "HKLM:\SYSTEM\Setup\LabConfig"
        try {
            if (-not (Test-Path $labConfig)) {
                New-Item -Path $labConfig -Force | Out-Null
            }
            Set-ItemProperty -Path $labConfig -Name 'BypassTPMCheck' -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $labConfig -Name 'BypassSecureBootCheck' `
                -Value 1 -Type DWord -Force
            Set-ItemProperty -Path $labConfig -Name 'BypassRAMCheck' -Value 1 -Type DWord -Force
            Write-Status 'Setup bypass flags configured' -Status 'OK'
        } catch {
            Write-Status "LabConfig setup failed: $($_.Exception.Message)" -Status 'SKIP'
        }

        # Set system locale
        try {
            Set-Culture -CultureInfo $PostInstallInputLocale -ErrorAction Stop
            Write-Status "System locale set to '$PostInstallInputLocale'" -Status 'OK'
        } catch {
            Write-Status "System locale - $($_.Exception.Message)" -Status 'SKIP'
        }

        # Strip 8.3 names (reduces disk usage, improves performance)
        try {
            $systemDrive = $env:SystemDrive.TrimEnd('\')
            fsutil.exe 8dot3name set $systemDrive 1 2>&1 | Out-Null
            fsutil.exe 8dot3name strip /s /f $systemDrive 2>&1 | Out-Null
            Write-Status '8.3 file name stripping scheduled' -Status 'OK'
        } catch {
            Write-Status "8.3 stripping: $($_.Exception.Message)" -Status 'SKIP'
        }

        Write-Host ''
        Write-Host 'Post-install setup completed.' -ForegroundColor Green
    }

    # ============================================================================
    # Summary
    # ============================================================================
    Write-Host ''
    Write-Host 'Package Installation Summary' -ForegroundColor Cyan
    Write-Host ''

    foreach ($key in $script:Results.Keys | Sort-Object) {
        $status = $script:Results[$key]
        $color = switch ($status) { 'OK' { 'Green' } 'FAIL' { 'Red' } 'SKIP' { 'Yellow' } 'RUNNING' { 'Cyan' } default { 'White' } }
        Write-Host "  $($key.PadRight(50)) : " -NoNewline; Write-Host "$status" -ForegroundColor $color
    }

    $duration = (Get-Date) - $script:StartTime
    Write-Host ""
    Write-Host "  Total time: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Next: Run Deploy-Config.ps1 to deploy configuration files." -ForegroundColor Yellow
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-InstallPackages @PSBoundParameters
    $exitCode = $LASTEXITCODE
    if ($null -ne $exitCode) { exit $exitCode }
}
