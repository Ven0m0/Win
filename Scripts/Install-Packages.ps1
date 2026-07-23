#Requires -Version 5.1
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
.PARAMETER SkipPowerShellModules
    Skip PowerShell module installations.
.PARAMETER SkipNotepadReplacer
    Skip Notepad Replacer setup.
.PARAMETER SkipPeripherals
    Skip peripheral driver/tool installs (GMK Driver, DS4Windows, Endgame Gear OP1 8k tools).
.PARAMETER SkipManualInstalls
    Skip manual (no winget package) app installs (DLSSync, GraalVM).
.PARAMETER SkipLanguagePackages
    Skip bun/npm/cargo global package installs.
.PARAMETER ApplyPostInstall
    Apply post-install Windows configuration (from autounattend.xml).
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
    [switch]$SkipPowerShellModules,
    [switch]$SkipNotepadReplacer,
    [switch]$SkipPeripherals,
    [switch]$SkipManualInstalls,
    [switch]$SkipLanguagePackages,
    [switch]$ApplyPostInstall,
    [string]$PostInstallTimeZone = 'W. Europe Standard Time',
    [string]$PostInstallInputLocale = 'en-US',
    [int]$PostInstallGeoId = 94
)

. "$PSScriptRoot\Common.ps1"

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

function Start-InstallPackage {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$SkipWinget,
        [switch]$SkipScoop,
        [switch]$SkipChoco,
        [switch]$SkipSystemFeatures,
        [switch]$SkipPowerShellModules,
        [switch]$SkipNotepadReplacer,
        [switch]$SkipPeripherals,
        [switch]$SkipManualInstalls,
        [switch]$SkipLanguagePackages,
        [switch]$ApplyPostInstall,
        [string]$PostInstallTimeZone = 'W. Europe Standard Time',
        [string]$PostInstallInputLocale = 'en-US',
        [int]$PostInstallGeoId = 94
    )

    # Load canonical package catalog
    $catalog = Import-PowerShellDataFile "$PSScriptRoot\packages.psd1"

    $script:StartTime = Get-Date
    $script:Results = @{}

    function Write-Status {
        param([string]$Message, [string]$Status = 'INFO')
        $color = switch ($Status) {
            'OK'      { 'Green' }
            'FAIL'    { 'Red' }
            'SKIP'    { 'Yellow' }
            'RUNNING' { 'Cyan' }
            default   { 'White' }
        }
        Write-Host "  [$Status] $Message" -ForegroundColor $color
        $script:Results[$Message] = $Status
    }

    function Install-WingetTool {
        [CmdletBinding(SupportsShouldProcess)]
        param([string]$Id, [string]$Name)
        if ($PSCmdlet.ShouldProcess($Name, 'Install via winget')) {
            $winget = Wait-ForWinget
            Write-Host "  Installing $Name..." -ForegroundColor Gray -NoNewline
            try {
                & $winget install --id $Id --accept-package-agreements --accept-source-agreements `
                    --disable-interactivity --nowarn --no-proxy --ignore-local-archive-malware-scan `
                    -h --force *>$null
                $ec = $LASTEXITCODE
                # 0 = success; -1978335189 = already installed; -1978335230 = no applicable installer for scope
                if ($ec -eq 0 -or $ec -eq -1978335189 -or $ec -eq -1978335230) {
                    Write-Host ' [OK]' -ForegroundColor Green
                } else {
                    Write-Host ''
                    Write-Warning "  [WARN] $Name - winget exit code: $ec"
                }
            } catch {
                Write-Host ''
                Write-Warning "  [WARN] $Name - $_"
                Write-Verbose "winget install failed for $Id : $_"
            }
        }
    }

    # ============================================================================
    # Phase 1: Prerequisites check and installation
    # ============================================================================
    Write-Host '[1/11] Checking prerequisites...' -ForegroundColor Cyan

    # Check if running as admin for system-level operations
    $adminOverride = Get-Variable -Name 'isAdminOverride' -Scope script -ErrorAction SilentlyContinue
    if ($null -eq $adminOverride -or $null -eq $adminOverride.Value) {
        $isAdmin = $false
        try {
            $isAdmin = Test-IsAdmin
        } catch { Write-Verbose "Admin role check failed: $_" }
    } else {
        $isAdmin = $adminOverride.Value
    }

    if (-not $isAdmin) {
        Write-Host '  [REQUIRED] Some operations require administrator privileges.' -ForegroundColor Yellow
        Write-Host '  Relaunching as administrator...' -ForegroundColor Yellow
        $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
        $shell = if ($pwshCmd) { $pwshCmd.Source } else { 'PowerShell.exe' }
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        foreach ($p in 'SkipWinget', 'SkipScoop', 'SkipChoco', 'SkipSystemFeatures', `
          'SkipPowerShellModules', 'SkipNotepadReplacer', 'SkipPeripherals', 'SkipManualInstalls', `
          'SkipLanguagePackages', 'ApplyPostInstall') {
            if ((Get-Variable -Name $p -ErrorAction SilentlyContinue).Value) { $argList += " -$p" }
        }
        if ($WhatIfPreference) { $argList += ' -WhatIf' }
        try { Start-Process -FilePath $shell -ArgumentList $argList -Verb RunAs } catch { Write-Verbose "Elevation relaunch failed: $_" }
        return
    }

    # Set execution policy
    try {
        if ($PSCmdlet.ShouldProcess('CurrentUser execution policy', 'Set to RemoteSigned')) {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
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
        Write-Host '[2/11] Installing core tools via winget...' -ForegroundColor Cyan
        foreach ($id in $catalog.WingetCore) {
            Install-WingetTool -Id $id -Name $id
        }
    }

    # ============================================================================
    # Phase 3: Install runtimes via winget
    # ============================================================================
    if (-not $SkipWinget) {
        Write-Host ''
        Write-Host '[3/11] Installing runtimes via winget...' -ForegroundColor Cyan
        foreach ($id in $catalog.WingetRuntimes) {
            Install-WingetTool -Id $id -Name $id
        }
    }

    # ============================================================================
    # Phase 4: Install build toolchains via winget
    # ============================================================================
    if (-not $SkipWinget) {
        Write-Host ''
        Write-Host '[4/11] Installing build toolchains via winget...' -ForegroundColor Cyan
        foreach ($id in $catalog.WingetToolchains) {
            Install-WingetTool -Id $id -Name $id
        }
    }

    # ============================================================================
    # Phase 5: Install development tools via winget
    # ============================================================================
    if (-not $SkipWinget) {
        Write-Host ''
        Write-Host '[5/11] Installing development tools via winget...' -ForegroundColor Cyan
        foreach ($id in $catalog.WingetDevTools) {
            Install-WingetTool -Id $id -Name $id
        }
    }

    # ============================================================================
    # Phase 6: Install CLI tools via winget
    # ============================================================================
    if (-not $SkipWinget) {
        Write-Host ''
        Write-Host '[6/11] Installing CLI tools via winget...' -ForegroundColor Cyan
        foreach ($id in $catalog.WingetCliTools) {
            Install-WingetTool -Id $id -Name $id
        }
    }

    # ============================================================================
    # Phase 7: Install applications via winget
    # ============================================================================
    if (-not $SkipWinget) {
        Write-Host ''
        Write-Host '[7/11] Installing applications via winget...' -ForegroundColor Cyan
        foreach ($id in $catalog.WingetApplications) {
            Install-WingetTool -Id $id -Name $id
        }
        # Name-based installs (no stable ID)
        if ($PSCmdlet.ShouldProcess('FFmpeg (Shared Build)', 'Install via winget')) {
            $winget = Wait-ForWinget
            & $winget install 'FFmpeg (Shared Build)' --accept-package-agreements --accept-source-agreements `
                --disable-interactivity --nowarn --no-proxy --ignore-local-archive-malware-scan `
                -h --force *>$null
        }
    }

    # ============================================================================
    # Phase 7.5: Notepad Replacer (requires Notepad++ installed first)
    # ============================================================================
    if (-not $SkipNotepadReplacer) {
        Write-Host ''
        Write-Host '[7.5/11] Setting up Notepad Replacer...' -ForegroundColor Cyan

        $notepadPlusPlus = @(
            Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' `
                -ErrorAction SilentlyContinue
            Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' `
                -ErrorAction SilentlyContinue
        ) | Where-Object { $_ -and $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -like 'Notepad++*' }

        $notepadReplacer = @(
            Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' `
                -ErrorAction SilentlyContinue
            Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' `
                -ErrorAction SilentlyContinue
        ) | Where-Object { $_ -and $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -like 'Notepad Replacer*' }

        if (-not $notepadPlusPlus) {
            Write-Status 'Notepad++ not found - skipping Notepad Replacer' -Status 'SKIP'
        } elseif ($notepadReplacer) {
            Write-Status 'Notepad Replacer already installed' -Status 'OK'
        } else {
            try {
                $url = 'https://www.binaryfortress.com/Data/Download/?Package=notepadreplacer&Log=100'
                $tempInstaller = Join-Path -Path $env:TEMP -ChildPath 'NotepadReplacer-Setup.exe'

                if ($PSCmdlet.ShouldProcess('Notepad Replacer', 'Download and install')) {
                    Get-FileFromWeb -URL $url -File $tempInstaller
                    Start-Process -FilePath $tempInstaller -ArgumentList '/S' -Wait -NoNewWindow
                    Remove-Item -Path $tempInstaller -Force -ErrorAction SilentlyContinue
                    Write-Status 'Notepad Replacer installed' -Status 'OK'
                }
            } catch {
                Write-Status "Notepad Replacer - $($_.Exception.Message)" -Status 'FAIL'
            }
        }
    }

    # ============================================================================
    # Phase 7.6: Peripheral drivers/tools (GMK Driver, DS4Windows, Endgame Gear OP1 8k)
    # ============================================================================
    if (-not $SkipPeripherals) {
        Write-Host ''
        Write-Host '[7.6/11] Installing peripheral drivers...' -ForegroundColor Cyan

        foreach ($peripheral in @(
                @{ Name = 'GMK Driver'; Script = 'third-party\gmk\install-gmk-driver.ps1' }
                @{ Name = 'DS4Windows'; Script = 'third-party\ds4windows\install-ds4windows.ps1' }
                @{ Name = 'Endgame Gear OP1 8k Tools'; Script = 'third-party\endgame-gear\install-op1-tools.ps1' }
            )) {
            $scriptPath = Join-Path $PSScriptRoot $peripheral.Script
            if (-not (Test-Path -LiteralPath $scriptPath)) {
                Write-Status "$($peripheral.Name) - script not found, skipping" -Status 'SKIP'
                continue
            }
            try {
                if ($PSCmdlet.ShouldProcess($peripheral.Name, 'Install')) {
                    & $scriptPath
                    Write-Status "$($peripheral.Name) installed" -Status 'OK'
                }
            } catch {
                Write-Status "$($peripheral.Name) - $($_.Exception.Message)" -Status 'FAIL'
            }
        }
    }

    # ============================================================================
    # Phase 7.7: Manual installs (apps with no winget package)
    # ============================================================================
    if (-not $SkipManualInstalls) {
        Write-Host ''
        Write-Host '[7.7/11] Installing manual (no winget package) apps...' -ForegroundColor Cyan

        foreach ($manualApp in $catalog.ManualInstalls) {
            $scriptPath = Join-Path $PSScriptRoot $manualApp.Script
            if (-not (Test-Path -LiteralPath $scriptPath)) {
                Write-Status "$($manualApp.Name) - script not found, skipping" -Status 'SKIP'
                continue
            }
            try {
                if ($PSCmdlet.ShouldProcess($manualApp.Name, 'Install')) {
                    & $scriptPath
                    Write-Status "$($manualApp.Name) installed" -Status 'OK'
                }
            } catch {
                Write-Status "$($manualApp.Name) - $($_.Exception.Message)" -Status 'FAIL'
            }
        }
    }

    # ============================================================================
    # Phase 7.8: bun / npm / cargo global packages
    # ============================================================================
    if (-not $SkipLanguagePackages) {
        Write-Host ''
        Write-Host '[7.8/11] Installing bun/npm/cargo global packages...' -ForegroundColor Cyan

        # Winget installs earlier in this run (bun, node, rustup) may not be on PATH yet.
        $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
            [System.Environment]::GetEnvironmentVariable('Path', 'User')

        if (Get-Command bun -ErrorAction SilentlyContinue) {
            foreach ($pkg in $catalog.BunPackages) {
                try {
                    if ($PSCmdlet.ShouldProcess($pkg, 'bun add -g')) {
                        bun add -g $pkg *>$null
                        Write-Status "Bun package '$pkg' installed" -Status 'OK'
                    }
                } catch {
                    Write-Status "Bun package '$pkg' - $($_.Exception.Message)" -Status 'FAIL'
                }
            }
        } else {
            Write-Status 'bun not on PATH - restart shell and re-run' -Status 'SKIP'
        }

        if (Get-Command npm -ErrorAction SilentlyContinue) {
            foreach ($pkg in $catalog.NpmPackages) {
                try {
                    if ($PSCmdlet.ShouldProcess($pkg, 'npm install -g')) {
                        npm install -g $pkg *>$null
                        Write-Status "npm package '$pkg' installed" -Status 'OK'
                    }
                } catch {
                    Write-Status "npm package '$pkg' - $($_.Exception.Message)" -Status 'FAIL'
                }
            }
        } else {
            Write-Status 'npm not on PATH - restart shell and re-run' -Status 'SKIP'
        }

        if (Get-Command cargo -ErrorAction SilentlyContinue) {
            if (-not (Get-Command cargo-binstall -ErrorAction SilentlyContinue)) {
                try {
                    if ($PSCmdlet.ShouldProcess('cargo-binstall', 'cargo install')) {
                        cargo install cargo-binstall *>$null
                    }
                } catch {
                    Write-Verbose "cargo-binstall bootstrap failed: $_"
                }
            }
            foreach ($pkg in $catalog.CargoPackages) {
                $pkgName = if ($pkg -is [hashtable]) { $pkg.Name } else { $pkg }
                try {
                    if ($PSCmdlet.ShouldProcess($pkgName, 'cargo install')) {
                        if ($pkg -is [hashtable]) {
                            cargo install --git $pkg.Git *>$null
                        } else {
                            cargo binstall -y $pkg *>$null
                        }
                        Write-Status "Cargo package '$pkgName' installed" -Status 'OK'
                    }
                } catch {
                    Write-Status "Cargo package '$pkgName' - $($_.Exception.Message)" -Status 'FAIL'
                }
            }
        } else {
            Write-Status 'cargo not on PATH - run "rustup default stable" and re-run' -Status 'SKIP'
        }
    }

    # ============================================================================
    # Phase 8: Scoop installation, buckets, and packages
    # ============================================================================
    if (-not $SkipScoop) {
        Write-Host ''
        Write-Host '[8/11] Setting up Scoop...' -ForegroundColor Cyan

        if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
            Write-Status 'Installing Scoop...' -Status 'RUNNING'
            try {
                $guid = [System.Guid]::NewGuid().ToString('N')
                $scoopInstaller = Join-Path -Path $env:TEMP -ChildPath "install-scoop-$guid.ps1"
                Invoke-RestMethod -Uri 'https://get.scoop.sh' -OutFile $scoopInstaller
                & $scoopInstaller
                Remove-Item -Path $scoopInstaller -Force -ErrorAction SilentlyContinue
                Write-Status 'Scoop installed' -Status 'OK'
            } catch {
                Write-Status "Scoop installation failed: $_" -Status 'FAIL'
            }
        } else {
            Write-Status 'Scoop already installed' -Status 'OK'
        }

        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            foreach ($bucket in $catalog.ScoopBuckets) {
                try {
                    scoop bucket add $bucket 2>$null
                    Write-Status "Scoop bucket '$bucket' added" -Status 'OK'
                } catch {
                    Write-Status "Scoop bucket '$bucket' (may already exist)" -Status 'SKIP'
                }
            }

            scoop config aria2-enabled true 2>$null
            scoop config aria2-warning-enabled false 2>$null

            foreach ($pkg in $catalog.ScoopPackages) {
                try {
                    scoop install $pkg 2>$null
                    Write-Status "Scoop package '$pkg' installed" -Status 'OK'
                } catch {
                    Write-Status "Scoop package '$pkg'" -Status 'SKIP'
                }
            }
        }
    }

    # ============================================================================
    # Phase 9: Chocolatey installation and packages
    # ============================================================================
    if (-not $SkipChoco) {
        Write-Host ''
        Write-Host '[9/11] Setting up Chocolatey...' -ForegroundColor Cyan

        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
            Write-Status 'Installing Chocolatey...' -Status 'RUNNING'
            try {
                try {
                    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
                } catch {
                    Write-Verbose "ExecutionPolicy: $_"
                }
                $chocoInstaller = Join-Path -Path $env:TEMP -ChildPath 'choco-install.ps1'
                Invoke-RestMethod -Uri 'https://community.chocolatey.org/install.ps1' `
                    -OutFile $chocoInstaller -ErrorAction Stop
                & $chocoInstaller
                Remove-Item -Path $chocoInstaller -Force -ErrorAction SilentlyContinue
                Write-Status 'Chocolatey installed' -Status 'OK'
            } catch {
                Write-Status "Chocolatey installation failed: $_" -Status 'FAIL'
            }
        } else {
            Write-Status 'Chocolatey already installed' -Status 'OK'
        }

        if (Get-Command choco -ErrorAction SilentlyContinue) {
            foreach ($pkg in $catalog.ChocoPackages) {
                try {
                    if ($PSCmdlet.ShouldProcess($pkg, 'choco install')) {
                        choco install $pkg -y --no-progress *>$null
                        Write-Status "Choco package '$pkg' installed" -Status 'OK'
                    }
                } catch {
                    Write-Status "Choco package '$pkg'" -Status 'SKIP'
                }
            }
        }
    }

    # ============================================================================
    # Phase 10: Windows optional features (if admin)
    # ============================================================================
    if (-not $SkipSystemFeatures -and $isAdmin) {
        Write-Host ''
        Write-Host '[10/11] Enabling Windows optional features...' -ForegroundColor Cyan

        foreach ($feature in $catalog.WindowsFeatures) {
            try {
                DISM /Online /Enable-Feature /FeatureName:$feature /All /NoRestart /Quiet *>$null
                Write-Status "Feature '$feature' enabled" -Status 'OK'
            } catch {
                Write-Status "Feature '$feature' (may already be enabled)" -Status 'SKIP'
            }
        }
    }

    # ============================================================================
    # Phase 11: PowerShell modules
    # ============================================================================
    if (-not $SkipPowerShellModules) {
        Write-Host ''
        Write-Host '[11/11] Installing PowerShell modules...' -ForegroundColor Cyan

        foreach ($modName in $catalog.PsModules) {
            if (-not (Get-Module -ListAvailable -Name $modName)) {
                try {
                    Install-Module -Name $modName -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber
                    Write-Status "PowerShell module '$modName' installed" -Status 'OK'
                } catch {
                    Write-Status "PowerShell module '$modName' - $($_.Exception.Message)" -Status 'FAIL'
                }
            } else {
                Write-Status "PowerShell module '$modName' already installed" -Status 'OK'
            }
        }
    }

    # ============================================================================
    # Phase 12: Post-Install Windows Setup (from autounattend.xml)
    # ============================================================================
    if ($ApplyPostInstall -and $isAdmin) {
        Write-Host ''
        Write-Host '[12/12] Applying post-install Windows configuration...' -ForegroundColor Cyan

        # Set timezone
        try {
            Set-TimeZone -Name $PostInstallTimeZone -ErrorAction Stop
            Write-Status "Timezone set to '$PostInstallTimeZone'" -Status 'OK'
        } catch {
            try {
                tzutil.exe /s $PostInstallTimeZone *>$null
                Write-Status "Timezone set to '$PostInstallTimeZone' (tzutil)" -Status 'OK'
            } catch {
                Write-Status "Timezone '$PostInstallTimeZone' - $($_.Exception.Message)" -Status 'SKIP'
            }
        }

        # Disable WPBT (Windows Platform Binary Table) - prevents malicious firmware attacks
        try {
            $sysHive = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
            if (-not (Test-Path -Path $sysHive)) {
                $null = New-Item -Path $sysHive -Force
            }
            Set-RegistryValue -Path $sysHive -Name 'DisableWpbtExecution' -Value 1
            Write-Status 'WPBT execution disabled' -Status 'OK'
        } catch {
            Write-Status "WPBT disable failed: $($_.Exception.Message)" -Status 'SKIP'
        }

        # Set geographic region (GeoId)
        try {
            $regionKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\DeviceRegion'
            if (-not (Test-Path -Path $regionKey)) {
                $null = New-Item -Path $regionKey -Force
            }
            Set-RegistryValue -Path $regionKey -Name 'DeviceRegion' -Value $PostInstallGeoId
            Write-Status "Geographic region set to GeoId $PostInstallGeoId" -Status 'OK'
        } catch {
            Write-Status "GeoId set failed: $($_.Exception.Message)" -Status 'SKIP'
        }

        # BypassSetup LabConfig (for future reinstallation/repair)
        $labConfig = 'HKLM:\SYSTEM\Setup\LabConfig'
        try {
            if (-not (Test-Path -Path $labConfig)) {
                $null = New-Item -Path $labConfig -Force
            }
            Set-RegistryValue -Path $labConfig -Name 'BypassTPMCheck' -Value 1
            Set-RegistryValue -Path $labConfig -Name 'BypassSecureBootCheck' -Value 1
            Set-RegistryValue -Path $labConfig -Name 'BypassRAMCheck' -Value 1
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
            fsutil.exe 8dot3name set $systemDrive 1 *>$null
            fsutil.exe 8dot3name strip /s /f $systemDrive *>$null
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

    foreach ($key in ($script:Results.Keys | Sort-Object)) {
        $status = $script:Results[$key]
        $color = switch ($status) {
            'OK'      { 'Green' }
            'FAIL'    { 'Red' }
            'SKIP'    { 'Yellow' }
            'RUNNING' { 'Cyan' }
            default   { 'White' }
        }
        Write-Host "  $($key.PadRight(50)) : " -NoNewline
        Write-Host "$status" -ForegroundColor $color
    }

    $duration = (Get-Date) - $script:StartTime
    Write-Host ''
    Write-Host "  Total time: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  Next: Run Setup-Win11.ps1 (or dotbot -c install.conf.yaml) to deploy config files.' -ForegroundColor Yellow
    Write-Host ''
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-InstallPackage @PSBoundParameters
    $exitCode = $LASTEXITCODE
    if ($null -ne $exitCode) { exit $exitCode }
}
