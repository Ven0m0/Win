#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Complete Windows 11 setup: debloat, install software catalog, deploy dotfiles.
.DESCRIPTION
    Full machine setup for an already-cloned Ven0m0/Win checkout. Debloats Windows,
    installs the software catalog (Install-Packages.ps1), and deploys tracked dotfiles
    via mise-managed dotbot. Intended to be chained from bootstrap.ps1, which installs
    prerequisites (git/python/mise/uv) and clones the repository before invoking this
    script - it no longer clones or pulls the repository itself.
.PARAMETER Unattended
    Skip all prompts and use defaults (no user interaction).
.PARAMETER Force
    Re-run setup even if already configured.
.PARAMETER SkipWingetTools
    Skip installing tools via winget (use existing installations).
.PARAMETER SkipWSL
    Skip WSL2 installation/configuration.
.PARAMETER SkipPackages
    Skip the full software installation phase (Install-Packages.ps1).
.PARAMETER SkipDebloat
    Skip the Windows debloat phase (debloat-windows.ps1).
.EXAMPLE
    .\Setup-Win11.ps1
.EXAMPLE
    .\Setup-Win11.ps1 -Unattended -Force
.EXAMPLE
    .\Setup-Win11.ps1 -Unattended -SkipDebloat -SkipPackages
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Unattended,
    [switch]$Force,
    [switch]$SkipWingetTools,
    [switch]$SkipWSL,
    [switch]$SkipPackages,
    [switch]$SkipDebloat
)

$ErrorActionPreference = 'Stop'

. "$PSScriptRoot\Common.ps1"

function Initialize-ShellEnvironment {
    <#
    .SYNOPSIS
        Enables the Windows OpenSSH client, sets a git credential helper and a user TERM.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $ssh = Get-WindowsCapability -Online -Name 'OpenSSH.Client*' | Select-Object -First 1
    if ($ssh -and $ssh.State -ne 'Installed' -and $PSCmdlet.ShouldProcess($ssh.Name, 'Add Windows capability')) {
        $null = Add-WindowsCapability -Online -Name $ssh.Name
    }

    # Windows ships ssh-agent disabled; Manual lets `ssh-add` start it on demand.
    $agent = Get-Service -Name 'ssh-agent' -ErrorAction SilentlyContinue
    if ($agent -and $agent.StartType -eq 'Disabled' -and $PSCmdlet.ShouldProcess('ssh-agent', 'Set startup Manual')) {
        Set-Service -Name 'ssh-agent' -StartupType Manual
    }

    if ((Get-Command git -ErrorAction SilentlyContinue) -and -not (& git config --global credential.helper) -and
        $PSCmdlet.ShouldProcess('git config --global', 'Set credential.helper manager')) {
        & git config --global credential.helper manager
    }

    if (-not [Environment]::GetEnvironmentVariable('TERM', 'User') -and
        $PSCmdlet.ShouldProcess('TERM', 'Set user environment variable xterm-256color')) {
        [Environment]::SetEnvironmentVariable('TERM', 'xterm-256color', 'User')
    }
}


function Start-SetupWin11 {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Unattended,
        [switch]$Force,
        [switch]$SkipWingetTools,
        [switch]$SkipWSL,
        [switch]$SkipPackages,
        [switch]$SkipDebloat
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    $script:StartTime = Get-Date
    $script:Results = @{}
    $repoRoot = Split-Path -Path $PSScriptRoot -Parent

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

    function Invoke-Operation {
        param([string]$Name, [scriptblock]$Action, [string]$SuccessStatus = 'OK')
        Write-Status "$Name" -Status 'RUNNING'
        try { & $Action; Write-Status "$Name" -Status $SuccessStatus; return $true }
        catch { Write-Status "$Name - $($_.Exception.Message)" -Status 'FAIL'; return $false }
    }

    # Elevation
    $isAdmin = Test-IsAdmin
    if (-not $isAdmin) {
        Write-Host '  [REQUIRED] Administrator privileges required. Relaunching as admin...' -ForegroundColor Yellow
        $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
        $shell = if ($pwshCmd) { $pwshCmd.Source } else { 'PowerShell.exe' }
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        foreach ($key in $PSBoundParameters.Keys) {
            if ($PSBoundParameters[$key]) { $argList += " -$key" }
        }
        if ($WhatIfPreference -and -not $PSBoundParameters.ContainsKey('WhatIf')) { $argList += ' -WhatIf' }
        Start-Process $shell -ArgumentList $argList -Verb RunAs
        return $true
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    # ---------------------------------------------------------------------------
    # Phase 1: Prerequisites (winget, Git, PowerShell 7, mise)
    # ---------------------------------------------------------------------------
    Write-Host '[1/6] Checking prerequisites...' -ForegroundColor Cyan

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        # Re-registers the App Installer package that ships winget (present but unregistered on fresh images).
        $null = Invoke-Operation -Name 'Registering winget (App Installer)' -Action {
            Add-AppxPackage -RegisterByFamilyName -MainPackage 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe'
        }
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            Write-Host '  [FAIL] winget not found and could not be registered.' -ForegroundColor Red
            Write-Host '  Install winget from https://aka.ms/getwinget then re-run.' `
                -ForegroundColor Yellow
            return $false
        }
    } else { Write-Status 'winget is available' -Status 'OK' }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $null = Invoke-Operation -Name 'Installing Git' -Action {
            $ProgressPreference = 'SilentlyContinue'
            & winget install --id Git.Git --silent --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -notin @(0, -1978335189)) { throw "git install failed with exit code $LASTEXITCODE" }
        }
    } else { Write-Status 'Git is available' -Status 'OK' }

    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        $null = Invoke-Operation -Name 'Installing PowerShell 7+' -Action {
            $ProgressPreference = 'SilentlyContinue'
            & winget install --id Microsoft.PowerShell --silent --accept-source-agreements `
                --accept-package-agreements
            if ($LASTEXITCODE -notin @(0, -1978335189)) { throw "pwsh install failed with exit code $LASTEXITCODE" }
        }
    } else { Write-Status 'PowerShell 7+ is available' -Status 'OK' }

    # Fresh winget installs only update the registry PATH; dotbot's `pwsh` steps need it in this process.
    Update-EnvironmentPath

    if (-not (Get-Command mise -ErrorAction SilentlyContinue)) {
        Write-Status 'mise not found - run bootstrap.ps1 first (installs git/python/mise/uv and clones the repo)' -Status 'FAIL'
        return $false
    } else { Write-Status 'mise is available' -Status 'OK' }

    $null = Invoke-Operation -Name 'Shell environment (OpenSSH, git credential helper, TERM)' -Action {
        Initialize-ShellEnvironment -WhatIf:$WhatIfPreference
    }

    # ---------------------------------------------------------------------------
    # Phase 2: Debloat Windows
    # ---------------------------------------------------------------------------
    Write-Host ''
    Write-Host '[2/6] Debloating Windows...' -ForegroundColor Cyan
    if ($SkipDebloat) {
        Write-Status 'Debloat skipped (-SkipDebloat)' -Status 'SKIP'
    } else {
        $debloatScript = Join-Path $repoRoot 'Scripts\debloat-windows.ps1'
        if (Test-Path $debloatScript) {
            $null = Invoke-Operation -Name 'Windows debloat' -Action {
                & $debloatScript -NoRestorePoint -Unattended
            }
        } else {
            Write-Status 'debloat-windows.ps1 not found - skipping' -Status 'SKIP'
        }
    }

    # ---------------------------------------------------------------------------
    # Phase 3: Install all software
    # ---------------------------------------------------------------------------
    Write-Host ''
    Write-Host '[3/6] Installing software catalog...' -ForegroundColor Cyan
    if ($SkipPackages) {
        Write-Status 'Package install skipped (-SkipPackages)' -Status 'SKIP'
    } else {
        $installScript = Join-Path $repoRoot 'Scripts\Install-Packages.ps1'
        if (Test-Path $installScript) {
            $null = Invoke-Operation -Name 'Full software install' -Action {
                & $installScript
            }
        } else {
            Write-Status 'Install-Packages.ps1 not found - skipping' -Status 'SKIP'
        }
    }

    # ---------------------------------------------------------------------------
    # Phase 4: Deploy configs via mise-managed dotbot
    # ---------------------------------------------------------------------------
    Write-Host ''
    Write-Host '[4/6] Deploying configs via mise/dotbot...' -ForegroundColor Cyan

    Push-Location -Path $repoRoot
    try {
        if ($WhatIfPreference) {
            # dotbot's shell steps are static and cannot forward -WhatIf, so preview the scripts directly.
            & (Join-Path $repoRoot 'Scripts\Setup-Dotfiles.ps1') -SkipWingetTools -WhatIf
            & (Join-Path $repoRoot 'Scripts\Setup-ClaudeCode.ps1') -WhatIf
            Write-Status 'Bootstrap previewed (WhatIf)' -Status 'OK'
        } else {
            # Out-Host keeps tool output out of this function's return value (a non-empty array is truthy).
            mise trust | Out-Host
            mise install | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "mise install failed with exit code $LASTEXITCODE" }
            mise run bootstrap | Out-Host
            if ($LASTEXITCODE -ne 0) { throw "mise run bootstrap failed with exit code $LASTEXITCODE" }
            Write-Status 'Bootstrap completed' -Status 'OK'
        }
    } catch {
        Write-Status "Bootstrap failed: $_" -Status 'FAIL'
        Pop-Location
        return $false
    }
    Pop-Location

    # ---------------------------------------------------------------------------
    # Phase 5: Optional WSL2
    # ---------------------------------------------------------------------------
    if (-not $SkipWSL) {
        Write-Host ''
        Write-Host '[5/6] Optional: WSL2 setup' -ForegroundColor Cyan
        $null = & wsl.exe --status 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status 'WSL is already installed' -Status 'OK'
        } else {
            if ($Unattended) { $installWSL = $true }
            else {
                $installWSL = $host.UI.PromptForChoice(
                    'WSL2','Install WSL2 (recommended for Windows 11)?', @('&Yes','&No'), 0) -eq 0
            }
            if ($installWSL) {
                $null = Invoke-Operation -Name 'Installing WSL2' -Action { $null = & wsl.exe --install --no-distribution }
            } else {
                Write-Status 'WSL2 installation skipped' -Status 'SKIP'
            }
        }
    } else {
        Write-Status 'WSL2 setup skipped (-SkipWSL)' -Status 'SKIP'
    }

    # ---------------------------------------------------------------------------
    # Phase 6: Summary
    # ---------------------------------------------------------------------------
    Write-Host ''
    Write-Host '[6/6] Setup Summary' -ForegroundColor Cyan
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
        Write-Host "  $($key.PadRight(50)) : " -NoNewline
        Write-Host "$status" -ForegroundColor $color
    }
    Write-Host ''
    $duration = (Get-Date) - $script:StartTime
    Write-Host "  Total time: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  Next steps:' -ForegroundColor Yellow
    Write-Host '  1. Restart your terminal or restart Windows.' -ForegroundColor Gray
    Write-Host '  2. Verify profile: Get-Command about_*' -ForegroundColor Gray
    Write-Host '  3. Explore Scripts/ for utilities.' -ForegroundColor Gray
    Write-Host ''
    if ($Unattended) {
        Write-Host 'Unattended setup complete. Review results above for failures.' -ForegroundColor Cyan
    }
    else {
        Write-Host 'Setup complete! Re-run with -Force to re-execute.' -ForegroundColor Cyan
    }
    Write-Host ''

    return $true

}

if ($MyInvocation.InvocationName -ne '.') {
    $result = Start-SetupWin11 @PSBoundParameters
    # Not $LASTEXITCODE: it holds whatever native command ran last, not this script's outcome.
    if (-not $result) { exit 1 }
    exit 0
}
