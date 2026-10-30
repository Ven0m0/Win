#Requires -Version 5.1
<#
.SYNOPSIS
    Installs all required packages and tools for the Windows development environment.
.DESCRIPTION
    Consolidates package installation from setup.ps1, Setup-Dotfiles.ps1, Setup-Win11.ps1,
    the retired shell-setup.ps1, and auto/install.ps1. Installs tools via winget, Scoop, and Chocolatey
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
    Skip peripheral driver/tool installs (GMK Driver, Endgame Gear OP1 8k tools).
.PARAMETER SkipManualInstalls
    Skip manual (no winget package) app installs.
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
    $script:InstallExitCode = 0

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

    # Runs a native command and throws on an unexpected exit code. Output is discarded; the
    # exit code is the only signal we trust. Resetting LASTEXITCODE keeps mocked natives at 0.
    function Invoke-NativeStep {
        param([scriptblock]$Command, [int[]]$OkCode = @(0))
        Set-Variable -Name LASTEXITCODE -Scope Global -Value 0 -WhatIf:$false
        & $Command *>$null
        $ec = (Get-Variable -Name LASTEXITCODE -Scope Global).Value
        if ($ec -notin $OkCode) { throw "exit code $ec" }
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
    if (-not $SkipWinget) {
        try {
            $null = Wait-ForWinget
            Write-Status 'winget is available' -Status 'OK'
        } catch {
            Write-Status "winget not available: $_. Install from https://aka.ms/getwinget" -Status 'FAIL'
            throw "winget not available: $_"
        }
    }

    # ============================================================================
    # Phase 2: Install core tools via winget
    # ============================================================================
    if (-not $SkipWinget) {
        Write-Host ''
        Write-Host '[2/11] Installing core tools via winget...' -ForegroundColor Cyan
        foreach ($id in $catalog.WingetCore) {
            Install-WingetTool -Id $id -Name $id -NoPathRefresh
        }
    }

    # ============================================================================
    # Phase 3: Install runtimes via winget
    # ============================================================================
    if (-not $SkipWinget) {
        Write-Host ''
        Write-Host '[3/11] Installing runtimes via winget...' -ForegroundColor Cyan
        foreach ($id in $catalog.WingetRuntimes) {
            Install-WingetTool -Id $id -Name $id -NoPathRefresh
        }
    }

    # ============================================================================
    # Phase 4: Install build toolchains via winget
    # ============================================================================
    if (-not $SkipWinget) {
        Write-Host ''
        Write-Host '[4/11] Installing build toolchains via winget...' -ForegroundColor Cyan
        foreach ($id in $catalog.WingetToolchains) {
            Install-WingetTool -Id $id -Name $id -NoPathRefresh
        }
    }

    # ============================================================================
    # Phase 5: Install development tools via winget
    # ============================================================================
    if (-not $SkipWinget) {
        Write-Host ''
        Write-Host '[5/11] Installing development tools via winget...' -ForegroundColor Cyan
        foreach ($id in $catalog.WingetDevTools) {
            Install-WingetTool -Id $id -Name $id -NoPathRefresh
        }
    }

    # ============================================================================
    # Phase 6: Install CLI tools via winget
    # ============================================================================
    if (-not $SkipWinget) {
        Write-Host ''
        Write-Host '[6/11] Installing CLI tools via winget...' -ForegroundColor Cyan
        foreach ($id in $catalog.WingetCliTools) {
            Install-WingetTool -Id $id -Name $id -NoPathRefresh
        }
    }

    # ============================================================================
    # Phase 7: Install applications via winget
    # ============================================================================
    if (-not $SkipWinget) {
        Write-Host ''
        Write-Host '[7/11] Installing applications via winget...' -ForegroundColor Cyan
        foreach ($id in $catalog.WingetApplications) {
            Install-WingetTool -Id $id -Name $id -NoPathRefresh
        }
        # Installs above skip the per-package PATH refresh; do it once for the whole batch.
        Update-EnvironmentPath
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
    # Phase 7.6: Peripheral drivers/tools (GMK Driver, Endgame Gear OP1 8k)
    # ============================================================================
    if (-not $SkipPeripherals) {
        Write-Host ''
        Write-Host '[7.6/11] Installing peripheral drivers...' -ForegroundColor Cyan

        foreach ($peripheral in @(
                @{ Name = 'GMK Driver'; Script = 'third-party\gmk\install-gmk-driver.ps1' }
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

        # Index access: the key is optional in packages.psd1 and dot access throws under StrictMode.
        foreach ($manualApp in $catalog['ManualInstalls']) {
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
        Update-EnvironmentPath

        if (Get-Command bun -ErrorAction SilentlyContinue) {
            foreach ($pkg in $catalog.BunPackages) {
                try {
                    if ($PSCmdlet.ShouldProcess($pkg, 'bun add -g')) {
                        Invoke-NativeStep { bun add -g $pkg }
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
                        Invoke-NativeStep { npm install -g $pkg }
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
                        Invoke-NativeStep { cargo install cargo-binstall }
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
                            Invoke-NativeStep { cargo install --git $pkg.Git }
                        } else {
                            Invoke-NativeStep { cargo binstall -y $pkg }
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
                # This script is elevated and Scoop's installer refuses admin without -RunAsAdmin.
                & $scoopInstaller -RunAsAdmin
                Remove-Item -Path $scoopInstaller -Force -ErrorAction SilentlyContinue
                Update-EnvironmentPath
                Write-Status 'Scoop installed' -Status 'OK'
            } catch {
                Write-Status "Scoop installation failed: $_" -Status 'FAIL'
            }
        } else {
            Write-Status 'Scoop already installed' -Status 'OK'
        }

        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            foreach ($bucket in $catalog.ScoopBuckets) {
                $bucketName = if ($bucket -is [hashtable]) { $bucket.Name } else { $bucket }
                $bucketArgs = if ($bucket -is [hashtable]) { @($bucket.Name, $bucket.Url) } else { @($bucket) }
                try {
                    Invoke-NativeStep { scoop bucket add @bucketArgs }
                    Write-Status "Scoop bucket '$bucketName' added" -Status 'OK'
                } catch {
                    Write-Status "Scoop bucket '$bucketName' - $($_.Exception.Message)" -Status 'FAIL'
                }
            }

            try {
                Invoke-NativeStep { scoop config aria2-enabled true }
                Invoke-NativeStep { scoop config aria2-warning-enabled false }
            } catch {
                Write-Warning "  Could not configure scoop aria2: $_"
            }

            foreach ($pkg in $catalog.ScoopPackages) {
                try {
                    Invoke-NativeStep { scoop install $pkg }
                    Write-Status "Scoop package '$pkg' installed" -Status 'OK'
                } catch {
                    Write-Status "Scoop package '$pkg' - $($_.Exception.Message)" -Status 'FAIL'
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
                Update-EnvironmentPath
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
                        # 1641/3010 = success, reboot pending
                        Invoke-NativeStep { choco install $pkg -y --no-progress } -OkCode 0, 1641, 3010
                        Write-Status "Choco package '$pkg' installed" -Status 'OK'
                    }
                } catch {
                    Write-Status "Choco package '$pkg' - $($_.Exception.Message)" -Status 'FAIL'
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
                if ($PSCmdlet.ShouldProcess($feature, 'Enable Windows feature')) {
                    # 3010 = success, reboot required
                    $dismArgs = @(
                        '/Online', '/Enable-Feature', "/FeatureName:$feature", '/All', '/NoRestart', '/Quiet'
                    )
                    Invoke-NativeStep { DISM @dismArgs } -OkCode 0, 3010
                    Write-Status "Feature '$feature' enabled" -Status 'OK'
                }
            } catch {
                Write-Status "Feature '$feature' - $($_.Exception.Message)" -Status 'FAIL'
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

        New-RestorePoint -Description 'Before Install-Packages post-install'

        # Set timezone
        try {
            Set-TimeZone -Name $PostInstallTimeZone -ErrorAction Stop
            Write-Status "Timezone set to '$PostInstallTimeZone'" -Status 'OK'
        } catch {
            try {
                Invoke-NativeStep { tzutil.exe /s $PostInstallTimeZone }
                Write-Status "Timezone set to '$PostInstallTimeZone' (tzutil)" -Status 'OK'
            } catch {
                Write-Status "Timezone '$PostInstallTimeZone' - $($_.Exception.Message)" -Status 'SKIP'
            }
        }

        # Disable WPBT (Windows Platform Binary Table) - prevents malicious firmware attacks
        try {
            $sysHive = 'HKLM\SYSTEM\CurrentControlSet\Control\Session Manager'
            Invoke-NativeStep {
                Set-RegistryValue -Path $sysHive -Name 'DisableWpbtExecution' -Type REG_DWORD -Data 1
            }
            Write-Status 'WPBT execution disabled' -Status 'OK'
        } catch {
            Write-Status "WPBT disable failed: $($_.Exception.Message)" -Status 'SKIP'
        }

        # Set geographic region (GeoId)
        try {
            $regionKey = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Control Panel\DeviceRegion'
            Invoke-NativeStep {
                Set-RegistryValue -Path $regionKey -Name 'DeviceRegion' -Type REG_DWORD -Data $PostInstallGeoId
            }
            Write-Status "Geographic region set to GeoId $PostInstallGeoId" -Status 'OK'
        } catch {
            Write-Status "GeoId set failed: $($_.Exception.Message)" -Status 'SKIP'
        }

        # BypassSetup LabConfig (for future reinstallation/repair)
        $labConfig = 'HKLM\SYSTEM\Setup\LabConfig'
        try {
            foreach ($flag in 'BypassTPMCheck', 'BypassSecureBootCheck', 'BypassRAMCheck') {
                Invoke-NativeStep { Set-RegistryValue -Path $labConfig -Name $flag -Type REG_DWORD -Data 1 }
            }
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
            if ($PSCmdlet.ShouldProcess("$systemDrive 8.3 names", 'Disable and strip')) {
                Invoke-NativeStep { fsutil.exe 8dot3name set $systemDrive 1 }
                # No /f: let fsutil refuse when registry entries still reference short names.
                Invoke-NativeStep { fsutil.exe 8dot3name strip /s $systemDrive }
                Write-Status '8.3 file name stripping done' -Status 'OK'
            }
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

    $failed = @($script:Results.Keys | Where-Object { $script:Results[$_] -eq 'FAIL' })
    if ($failed.Count -gt 0) {
        $script:InstallExitCode = 1
        Write-Host "  $($failed.Count) step(s) failed." -ForegroundColor Red
    }

    $duration = (Get-Date) - $script:StartTime
    Write-Host ''
    Write-Host "  Total time: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  Next: Run Setup-Win11.ps1 (or dotbot -c install.conf.yaml) to deploy config files.' -ForegroundColor Yellow
    Write-Host ''
}

if ($MyInvocation.InvocationName -ne '.') {
    $script:InstallExitCode = 0
    Start-InstallPackage @PSBoundParameters
    exit $script:InstallExitCode
}
