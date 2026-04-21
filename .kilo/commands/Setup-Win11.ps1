#!/usr/bin/env pwsh
<#
.SYNOPSIS
    One-command Windows 11 setup: installs prerequisites, clones dotfiles with yadm, and runs bootstrap.
.DESCRIPTION
    Designed for fresh Windows 11 installs. Detects and installs missing prerequisites
    (winget, Git, PowerShell 7, yadm), clones this repository via yadm, and runs the
    full bootstrap process. Can run unattended with -Unattended.
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

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:StartTime = Get-Date
$script:Results = @{}

# ---------------------------------------------------------------------------
# Helper: record result and write status
# ---------------------------------------------------------------------------
function Write-Status {
    param([string]$Message, [string]$Status = 'INFO')
    $color = switch ($Status) {
        'OK'       { 'Green' }
        'FAIL'     { 'Red' }
        'SKIP'     { 'Yellow' }
        'RUNNING'  { 'Cyan' }
        default    { 'White' }
    }
    Write-Host "  [$Status] $Message" -ForegroundColor $color
    $script:Results[$Message] = $Status
}

function Invoke-Operation {
    param([string]$Name, [scriptblock]$Action, [string]$SuccessStatus = 'OK')
    Write-Status "$Name" -Status 'RUNNING'
    try {
        & $Action
        Write-Status "$Name" -Status $SuccessStatus
        return $true
    } catch {
        Write-Status "$Name - $($_.Exception.Message)" -Status 'FAIL'
        return $false
    }
}

# ---------------------------------------------------------------------------
# Phase 0: Elevation check (need admin for most operations)
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '=== Windows 11 Dotfiles Setup ===' -ForegroundColor Cyan
Write-Host ''

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host '  [REQUIRED] Administrator privileges required. Relaunching as administrator...' -ForegroundColor Yellow
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    $shell = if ($pwshCmd) { $pwshCmd.Source } else { 'PowerShell.exe' }
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Force) { $argList += ' -Force' }
    if ($SkipWingetTools) { $argList += ' -SkipWingetTools' }
    if ($SkipWSL) { $argList += ' -SkipWSL' }
    if ($Unattended) { $argList += ' -Unattended' }
    Start-Process $shell -ArgumentList $argList -Verb RunAs
    exit 0
}

# ---------------------------------------------------------------------------
# Phase 1: Prerequisites (winget, Git, PowerShell 7, yadm)
# ---------------------------------------------------------------------------
Write-Host '[1/5] Checking prerequisites...' -ForegroundColor Cyan

# winget - needed for tool installation
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Status 'winget not found - attempting to install' -Status 'RUNNING'
    try {
        # Use the repo's shell-setup to install prerequisites
        if (Test-Path "$PSScriptRoot\Scripts\shell-setup.ps1") {
            Write-Status 'Installing prerequisites via shell-setup.ps1' -Status 'RUNNING'
            & "$PSScriptRoot\Scripts\shell-setup.ps1"
            Write-Status 'Prerequisites installed' -Status 'OK'
        } else {
            throw "shell-setup.ps1 not found. Install winget manually from https://aka.ms/getwinget"
        }
    } catch {
        Write-Status "Failed to install prerequisites: $_" -Status 'FAIL'
        Write-Host "  Install winget from https://aka.ms/getwinget and re-run this script." -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Status 'winget is available' -Status 'OK'
}

# Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $gitInstalled = Invoke-Operation -Name 'Installing Git' -Action {
        winget install --id Git.Git --silent --accept-source-agreements --accept-package-agreements | Out-Null
    }
} else {
    Write-Status 'Git is available' -Status 'OK'
}

# PowerShell 7 (optional but recommended)
if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    $ps7Installed = Invoke-Operation -Name 'Installing PowerShell 7+' -Action {
        winget install --id Microsoft.PowerShell --silent --accept-source-agreements --accept-package-agreements | Out-Null
    }
} else {
    Write-Status 'PowerShell 7+ is available' -Status 'OK'
}

# yadm - the dotfile manager
if (-not (Get-Command yadm -ErrorAction SilentlyContinue)) {
    $yadmInstalled = Invoke-Operation -Name 'Installing yadm' -Action {
        winget install --id yadm.yadm --silent --accept-source-agreements --accept-package-agreements | Out-Null
    }
} else {
    Write-Status 'yadm is available' -Status 'OK'
}

# ---------------------------------------------------------------------------
# Phase 2: Clone or update dotfiles repository
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '[2/5] Setting up dotfiles repository...' -ForegroundColor Cyan

$repoUrl = 'https://github.com/Ven0m0/Win.git'
$yadmDir = Join-Path $HOME '.yadm'

# Check if repo already cloned
if (Test-Path $yadmDir) {
    if ($Force) {
        Write-Status 'Existing yadm repo found - forcing re-clone' -Status 'RUNNING'
        # Backup and remove
        Remove-Item $yadmDir -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Status 'yadm repository already initialized - pulling latest changes' -Status 'RUNNING'
        try {
            yadm pull
            Write-Status 'Dotfiles updated' -Status 'OK'
        } catch {
            Write-Status "Failed to pull updates: $_" -Status 'WARN'
        }
    }
}

if (-not (Test-Path $yadmDir)) {
    Write-Status "Cloning dotfiles from $repoUrl" -Status 'RUNNING'
    try {
        yadm clone $repoUrl
        Write-Status 'Repository cloned' -Status 'OK'
    } catch {
        Write-Status "Clone failed: $_" -Status 'FAIL'
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Phase 3: Run bootstrap
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '[3/5] Running bootstrap...' -ForegroundColor Cyan

$bootstrapArgs = @()
if ($Unattended) { $bootstrapArgs += '-Unattended' }
if ($Force) { $bootstrapArgs += '-Force' }
if ($SkipWingetTools) { $bootstrapArgs += '-SkipWingetTools' }

$bootstrapScript = Join-Path $yadmDir 'bootstrap'
if (Test-Path $bootstrapScript) {
    try {
        pwsh -NoProfile -ExecutionPolicy Bypass -File $bootstrapScript @bootstrapArgs
        Write-Status 'Bootstrap completed' -Status 'OK'
    } catch {
        Write-Status "Bootstrap failed: $_" -Status 'FAIL'
        exit 1
    }
} else {
    Write-Status "Bootstrap script not found at $bootstrapScript" -Status 'FAIL'
    exit 1
}

# ---------------------------------------------------------------------------
# Phase 4: Optional WSL2 setup
# ---------------------------------------------------------------------------
if (-not $SkipWSL) {
    Write-Host ''
    Write-Host '[4/5] Optional: WSL2 setup' -ForegroundColor Cyan

    # Check if WSL is already installed
    $wslState = wsl --status 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Status 'WSL is already installed' -Status 'OK'
    } else {
        if ($Unattended) {
            $installWSL = $true
        } else {
            $installWSL = $host.UI.PromptForChoice('WSL2', 'Install WSL2 (recommended for Windows 11)?', @('&Yes', '&No'), 0) -eq 0
        }

        if ($installWSL) {
            Write-Status 'Installing WSL2...' -Status 'RUNNING'
            wsl --install --no-distribution | Out-Null
            Write-Status 'WSL2 installation started (distribution can be installed later)' -Status 'OK'
        } else {
            Write-Status 'WSL2 installation skipped' -Status 'SKIP'
        }
    }
} else {
    Write-Status 'WSL2 setup skipped (flag -SkipWSL)' -Status 'SKIP'
}

# ---------------------------------------------------------------------------
# Phase 5: Summary and next steps
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '[5/5] Setup Summary' -ForegroundColor Cyan
Write-Host ''

foreach ($key in $script:Results.Keys | Sort-Object) {
    $status = $script:Results[$key]
    $color = switch ($status) {
        'OK'    { 'Green' }
        'FAIL'  { 'Red' }
        'SKIP'  { 'Yellow' }
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
Write-Host '  1. Restart your terminal (or restart Windows if prompted)' -ForegroundColor Gray
Write-Host '  2. Verify your profile loaded: Get-Command -Module posh-git, oh-my-posh' -ForegroundColor Gray
Write-Host '  3. Review Scripts/ for available utilities' -ForegroundColor Gray
Write-Host ''

if ($Unattended) {
    Write-Host 'Setup completed in unattended mode. Check results above for any failures.' -ForegroundColor Cyan
} else {
    Write-Host 'Setup completed! If any errors appeared above, review and re-run with -Force if needed.' -ForegroundColor Cyan
}

Write-Host ''
