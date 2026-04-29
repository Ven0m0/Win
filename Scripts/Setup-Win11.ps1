#!/usr/bin/env pwsh

#Requires -Version 5.1

<#
.SYNOPSIS
    Complete Windows 11 setup: installs prerequisites, clones dotfiles, runs bootstrap.
.DESCRIPTION
    One-command fresh Windows 11 setup. Detects and installs missing prerequisites
    (winget, Git, PowerShell 7), clones the dotfiles repository via git, and
    runs the full bootstrap process via dotbot.
.PARAMETER Unattended
    Skip all prompts and use defaults (no user interaction).
.PARAMETER Force
    Re-run setup even if already configured.
.PARAMETER SkipWingetTools
    Skip installing tools via winget (use existing installations).
.PARAMETER SkipWSL
    Skip WSL2 installation/configuration.
.EXAMPLE
    .\Setup-Win11.ps1
.EXAMPLE
    .\Setup-Win11.ps1 -Unattended -Force
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Unattended,
    [switch]$Force,
    [switch]$SkipWingetTools,
    [switch]$SkipWSL
)

function Start-SetupWin11 {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [switch]$Unattended,
        [switch]$Force,
        [switch]$SkipWingetTools,
        [switch]$SkipWSL
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $ProgressPreference = 'SilentlyContinue'

    $script:StartTime = Get-Date
    $script:Results = @{}

    function Write-Status { param([string]$Message, [string]$Status = 'INFO')
        $color = switch ($Status) { 'OK' { 'Green' } 'FAIL' { 'Red' } 'SKIP' { 'Yellow' } 'RUNNING' { 'Cyan' } default { 'White' } }
        Write-Host "  [$Status] $Message" -ForegroundColor $color
        $script:Results[$Message] = $Status
    }

    function Write-Warning($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
    function Write-Fail($msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red }

    function Invoke-Operation {
        param([string]$Name, [scriptblock]$Action, [string]$SuccessStatus = 'OK')
        Write-Status "$Name" -Status 'RUNNING'
        try { & $Action; Write-Status "$Name" -Status $SuccessStatus; return $true }
        catch { Write-Status "$Name - $($_.Exception.Message)" -Status 'FAIL'; return $false }
    }

    # Elevation
    function Test-IsAdmin {
        if ($IsLinux -or $IsMacOS) { return $true }
        return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    $isAdmin = Test-IsAdmin
    if (-not $isAdmin) {
        Write-Host '  [REQUIRED] Administrator privileges required. Relaunching as administrator...' -ForegroundColor Yellow
        $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
        $shell = if ($pwshCmd) { $pwshCmd.Source } else { 'PowerShell.exe' }
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        foreach ($p in 'Force','SkipWingetTools','SkipWSL','Unattended') {
            if ((Get-Variable $p -ErrorAction SilentlyContinue).Value) { $argList += " -$p" }
        }
        Start-Process $shell -ArgumentList $argList -Verb RunAs
        return $true
    }

    # ---------------------------------------------------------------------------
    # Phase 1: Prerequisites (winget, Git, PowerShell 7)
    # ---------------------------------------------------------------------------
    Write-Host '[1/5] Checking prerequisites...' -ForegroundColor Cyan

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        if (Test-Path "$PSScriptRoot\shell-setup.ps1") {
            Write-Status 'Installing prerequisites via shell-setup.ps1' -Status 'RUNNING'
            & "$PSScriptRoot\shell-setup.ps1"
            Write-Status 'Prerequisites installed' -Status 'OK'
        } else {
            Write-Fail 'winget not found and shell-setup.ps1 unavailable.'
            Write-Host '  Install winget from https://aka.ms/getwinget then re-run.' `
                -ForegroundColor Yellow
            return $false
        }
    } else { Write-Status 'winget is available' -Status 'OK' }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $null = Invoke-Operation -Name 'Installing Git' -Action {
            winget install --id Git.Git --silent --accept-source-agreements --accept-package-agreements | Out-Null
        }
    } else { Write-Status 'Git is available' -Status 'OK' }

    if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
        $null = Invoke-Operation -Name 'Installing PowerShell 7+' -Action {
            winget install --id Microsoft.PowerShell --silent --accept-source-agreements `
                --accept-package-agreements | Out-Null
        }
    } else { Write-Status 'PowerShell 7+ is available' -Status 'OK' }


    # ---------------------------------------------------------------------------
    # Phase 2: Clone or update dotfiles repository
    # ---------------------------------------------------------------------------
    Write-Host ''
    Write-Host '[2/5] Setting up dotfiles repository...' -ForegroundColor Cyan

    $repoUrl = 'https://github.com/Ven0m0/Win.git'
    $repoDir = Join-Path $HOME 'Win'

    if (Test-Path $repoDir) {
        if ($Force) {
            Write-Status 'Existing repo found - forcing re-clone' -Status 'RUNNING'
            Remove-Item $repoDir -Recurse -Force -ErrorAction SilentlyContinue
        } else {
            Write-Status 'Repository already initialized - pulling latest changes' `
                -Status 'RUNNING'
            try { git -C $repoDir pull; Write-Status 'Dotfiles updated' -Status 'OK' }
            catch { Write-Status "Pull failed: $_" -Status 'WARN' }
        }
    }

    if (-not (Test-Path $repoDir)) {
        Write-Status "Cloning dotfiles from $repoUrl" -Status 'RUNNING'
        try { git clone $repoUrl $repoDir; Write-Status 'Repository cloned' -Status 'OK' }
        catch { Write-Status "Clone failed: $_" -Status 'FAIL'; return $false }
    }

    # Ensure Python and dotbot are installed
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Status 'Installing Python via winget...' -Status 'RUNNING'
        try {
            winget install --id Python.Python.3.12 --silent --accept-source-agreements `
                --accept-package-agreements | Out-Null
            Write-Status 'Python installed' -Status 'OK'
        }
        catch { Write-Status "Python installation failed: $_" -Status 'WARN' }
    }

    if (-not (Get-Command dotbot -ErrorAction SilentlyContinue)) {
        Write-Status 'Installing dotbot via pip...' -Status 'RUNNING'
        try { pip install dotbot | Out-Null; Write-Status 'dotbot installed' -Status 'OK' }
        catch { Write-Status "dotbot installation failed: $_" -Status 'WARN' }
    }

    # ---------------------------------------------------------------------------
    # Phase 3: Run bootstrap via dotbot
    # ---------------------------------------------------------------------------
    Write-Host ''
    Write-Host '[3/5] Running bootstrap via dotbot...' -ForegroundColor Cyan

    # Change to repository directory and run dotbot
    pushd $repoDir
    try {
        dotbot -c install.conf.yaml
        Write-Status 'Bootstrap completed' -Status 'OK'
    } catch {
        Write-Status "Bootstrap failed: $_" -Status 'FAIL'
        popd
        return $false
    }
    popd

    # ---------------------------------------------------------------------------
    # Phase 4: Optional WSL2
    # ---------------------------------------------------------------------------
    if (-not $SkipWSL) {
        Write-Host ''
        Write-Host '[4/5] Optional: WSL2 setup' -ForegroundColor Cyan
        $wslState = wsl --status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Status 'WSL is already installed' -Status 'OK'
        } else {
            if ($Unattended) { $installWSL = $true }
            else {
                $installWSL = $host.UI.PromptForChoice(
                    'WSL2','Install WSL2 (recommended for Windows 11)?', @('&Yes','&No'), 0) -eq 0
            }
            if ($installWSL) {
                $null = Invoke-Operation -Name 'Installing WSL2' -Action { wsl --install --no-distribution | Out-Null }
            } else {
                Write-Status 'WSL2 installation skipped' -Status 'SKIP'
            }
        }
    } else {
        Write-Status 'WSL2 setup skipped (-SkipWSL)' -Status 'SKIP'
    }

    # ---------------------------------------------------------------------------
    # Phase 5: Summary
    # ---------------------------------------------------------------------------
    Write-Host ''
    Write-Host '[5/5] Setup Summary' -ForegroundColor Cyan
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
    if (-not $result) { exit 1 }
    exit $LASTEXITCODE
}
