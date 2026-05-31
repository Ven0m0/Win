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
    [switch]$SkipPowerShellModules,
    [switch]$SkipNotepadReplacer,
    [switch]$ApplyPostInstall,
    [string]$PostInstallComputerName = 'PC',
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
        [switch]$ApplyPostInstall,
        [string]$PostInstallComputerName = 'PC',
        [string]$PostInstallTimeZone = 'W. Europe Standard Time',
        [string]$PostInstallInputLocale = 'en-US',
        [int]$PostInstallGeoId = 94
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    # Load canonical package catalog
    $catalog = Import-PowerShellDataFile "$PSScriptRoot\packages.psd1"

    $script:StartTime = Get-Date
    $script:Results = @{}

    function Write-Status {
        param([string]$Message, [string]$Status = 'INFO')
        $color = switch ($Status) {
            'OK' { 'Green' }
            'FAIL' { 'Red' }
            'SKIP' { 'Yellow' }
            'RUNNING' { 'Cyan' }
            default { 'White' }
        }
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
        [CmdletBinding(SupportsShouldProcess)]
        param([string]$Id, [string]$Name)
        if ($PSCmdlet.ShouldProcess($Name, 'Install via winget')) {
            $winget = Wait-ForWinget
            Write-Host "  Installing $Name..." -ForegroundColor Gray -NoNewline
            try {
                # Try without --scope first so packages with only user-scope installers
                # (eza, fd, bat, ripgrep, starship, mise, etc.) are not rejected.
                # --scope machine caused exit -1978335230 for those packages.
                & $winget install --id $Id --silent --disable-interactivity `
                    --accept-source-agreements --accept-package-agreements *>$null
                $ec = $LASTEXITCODE
                # 0 = success; -1978335189 = already installed; -1978335230 = no applicable installer for scope
                if ($ec -eq 0 -or $ec -eq -1978335189 -or $ec -eq -1978335230) {
                    Write-Host " [OK]" -ForegroundColor Green
                } else {
                    Write-Host ""
                    Write-Warning "  [WARN] $Name - winget exit code: $ec"
                }
            } catch {
                Write-Host ""
                Write-Warning "  [WARN] $Name - $_"
                Write-Verbose "winget install failed for $Id : $_"
            }
        }
    }

    # ============================================================================
    # Phase 1: Prerequisites check and installation
    # ============================================================================
    Write-Host '[1/7] Checking prerequisites...' -ForegroundColor Cyan

    # Check if running as admin for system-level operations
    $adminOverride = Get-Variable -Name 'isAdminOverride' -Scope script -ErrorAction SilentlyContinue
    if ($null -eq $adminOverride -or $null -eq $adminOverride.Value) {
        $isAdmin = $false
        try {
            $isAdmin = ([Security.Principal.WindowsPrincipal]`
                [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator
            )
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
          'SkipPowerShellModules', 'SkipNotepadReplacer', 'ApplyPostInstall') {
            if ((Get-Variable $p -ErrorAction SilentlyContinue).Value) { $argList += " -$p" }
        }
        if ($WhatIfPreference) { $argList += ' -WhatIf' }
        try { Start-Process $shell `
    -ArgumentList $argList -Verb RunAs } catch { Write-Verbose "Elevation relaunch failed: $_" }
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
        if ($PSCmdlet.ShouldProcess('FFmpeg (Essentials Build)', 'Install via winget')) {
            $null = Wait-ForWinget
            winget install 'FFmpeg (Essentials Build)' --silent --accept-source-agreements `
                --accept-package-agreements *>$null
        }
        if ($PSCmdlet.ShouldProcess('ShutterEncoder', 'Install via winget')) {
            $null = Wait-ForWinget
            winget install 'PaulPacifico.ShutterEncoder' --silent --accept-source-agreements `
                --accept-package-agreements *>$null
        }
    }

    # ============================================================================
    # Phase 7.5: Notepad Replacer (requires Notepad++ installed first)
    # ============================================================================
    if (-not $SkipNotepadReplacer) {
        Write-Host ''
        Write-Host '[7.5/11] Setting up Notepad Replacer...' -ForegroundColor Cyan

        # Check if Notepad++ is installed
        $notepadPlusPlus = @(
          Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' `
            -ErrorAction SilentlyContinue
          Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' `
            -ErrorAction SilentlyContinue
        ) | Where-Object { $_ -and $_.PSObject.Properties['DisplayName'] -and $_.DisplayName -eq 'Notepad++' }

        if (-not $notepadPlusPlus) {
            Write-Status 'Notepad++ not found - skipping Notepad Replacer' -Status 'SKIP'
        } else {
            try {
                $url = 'https://www.binaryfortress.com/Data/Download/?Package=notepadreplacer&Log=100'
                $tempInstaller = Join-Path $env:TEMP 'NotepadReplacer-Setup.exe'

                if ($PSCmdlet.ShouldProcess('Notepad Replacer', 'Download and install')) {
                    Invoke-WebRequest -Uri $url -OutFile $tempInstaller -UseBasicParsing -ErrorAction Stop
                    Start-Process -FilePath $tempInstaller -ArgumentList '/S' -Wait -NoNewWindow
                    Remove-Item $tempInstaller -Force -ErrorAction SilentlyContinue
                    Write-Status 'Notepad Replacer installed' -Status 'OK'
                }
            } catch {
                Write-Status "Notepad Replacer - $($_.Exception.Message)" -Status 'FAIL'
            }
        }
    }

    # ============================================================================
    # Phase 8: Scoop installation, buckets, and packages
    # ============================================================================
    if (-not $SkipScoop) {
        Write-Host ''
        Write-Host '[8/11] Setting up Scoop...' -ForegroundColor Cyan

        # Install Scoop if not present
        if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
            Write-Status 'Installing Scoop...' -Status 'RUNNING'
            try {
                $guid = [System.Guid]::NewGuid().ToString('N')
                $scoopInstaller = Join-Path $env:TEMP "install-scoop-$guid.ps1"
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

        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            # Add Scoop buckets
            foreach ($bucket in $catalog.ScoopBuckets) {
                try {
                    scoop bucket add $bucket 2>$null
                    Write-Status "Scoop bucket '$bucket' added" -Status 'OK'
                } catch {
                    Write-Status "Scoop bucket '$bucket' (may already exist)" -Status 'SKIP'
                }
            }

            # Configure aria2 for Scoop
            scoop config aria2-enabled true 2>$null
            scoop config aria2-warning-enabled false 2>$null

            # Install Scoop packages
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

        # Install Chocolatey if not present
        if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
            Write-Status 'Installing Chocolatey...' -Status 'RUNNING'
            try {
                try { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue } catch { Write-Verbose "ExecutionPolicy: $_" }
                Invoke-RestMethod -Uri 'https://community.chocolatey.org/install.ps1' `
                    -OutFile "$env:TEMP\choco-install.ps1" -ErrorAction Stop
                & "$env:TEMP\choco-install.ps1"
                Remove-Item "$env:TEMP\choco-install.ps1" -Force -ErrorAction SilentlyContinue
                Write-Status 'Chocolatey installed' -Status 'OK'
            } catch {
                Write-Status "Chocolatey installation failed: $_" -Status 'FAIL'
            }
        } else {
            Write-Status 'Chocolatey already installed' -Status 'OK'
        }

        # Install Chocolatey packages
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
    # Phase 8: Post-Install Windows Setup (from autounattend.xml)
    # ============================================================================
    if ($ApplyPostInstall -and $isAdmin) {
        Write-Host ''
        Write-Host '[8/8] Applying post-install Windows configuration...' -ForegroundColor Cyan

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

    foreach ($key in $script:Results.Keys | Sort-Object) {
        $status = $script:Results[$key]
        $color = switch ($status) {
            'OK' { 'Green' }
            'FAIL' { 'Red' }
            'SKIP' { 'Yellow' }
            'RUNNING' { 'Cyan' }
            default { 'White' }
        }
        Write-Host "  $($key.PadRight(50)) : " -NoNewline; Write-Host "$status" -ForegroundColor $color
    }

    $duration = (Get-Date) - $script:StartTime
    Write-Host ""
    Write-Host "  Total time: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Next: Run Setup-Win11.ps1 (or dotbot -c install.conf.yaml) to deploy config files." -ForegroundColor Yellow
    Write-Host ""
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-InstallPackage @PSBoundParameters
    $exitCode = $LASTEXITCODE
    if ($null -ne $exitCode) { exit $exitCode }
}

