#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Complete Windows 11 setup: installs prerequisites, clones dotfiles with yadm, runs bootstrap.
.DESCRIPTION
    One-command fresh Windows 11 setup. Detects and installs missing prerequisites
    (winget, Git, PowerShell 7, yadm), clones the dotfiles repository via yadm, and
    runs the full bootstrap process.
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

function Write-Status { param([string]$Message, [string]$Status = 'INFO')
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

# Elevation
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Host '  [REQUIRED] Administrator privileges required. Relaunching as administrator...' -ForegroundColor Yellow
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    $shell = if ($pwshCmd) { $pwshCmd.Source } else { 'PowerShell.exe' }
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    foreach ($p in 'Force','SkipWingetTools','SkipWSL','Unattended') { if ((Get-Variable $p -ErrorAction SilentlyContinue).Value) { $argList += " -$p" } }
    Start-Process $shell -ArgumentList $argList -Verb RunAs
    exit 0
}

# ---------------------------------------------------------------------------
# Phase 1: Prerequisites (winget, Git, PowerShell 7, yadm)
# ---------------------------------------------------------------------------
Write-Host '[1/5] Checking prerequisites...' -ForegroundColor Cyan

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    if (Test-Path "$PSScriptRoot\shell-setup.ps1") {
        Write-Status 'Installing prerequisites via shell-setup.ps1' -Status 'RUNNING'
        & "$PSScriptRoot\shell-setup.ps1"
        Write-Status 'Prerequisites installed' -Status 'OK'
    } else {
        Write-Fail 'winget not found and shell-setup.ps1 unavailable.'
        Write-Host '  Install winget from https://aka.ms/getwinget then re-run.' -ForegroundColor Yellow
        exit 1
    }
} else { Write-Status 'winget is available' -Status 'OK' }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    $null = Invoke-Operation -Name 'Installing Git' -Action { winget install --id Git.Git --silent --accept-source-agreements --accept-package-agreements | Out-Null }
} else { Write-Status 'Git is available' -Status 'OK' }

if (-not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
    $null = Invoke-Operation -Name 'Installing PowerShell 7+' -Action { winget install --id Microsoft.PowerShell --silent --accept-source-agreements --accept-package-agreements | Out-Null }
} else { Write-Status 'PowerShell 7+ is available' -Status 'OK' }

if (-not (Get-Command yadm -ErrorAction SilentlyContinue)) {
    $null = Invoke-Operation -Name 'Installing yadm' -Action { winget install --id yadm.yadm --silent --accept-source-agreements --accept-package-agreements | Out-Null }
} else { Write-Status 'yadm is available' -Status 'OK' }

# ---------------------------------------------------------------------------
# Phase 2: Clone or update dotfiles repository
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '[2/5] Setting up dotfiles repository...' -ForegroundColor Cyan

$repoUrl = 'https://github.com/Ven0m0/Win.git'
$yadmDir = Join-Path $HOME '.yadm'

if (Test-Path $yadmDir) {
    if ($Force) {
        Write-Status 'Existing yadm repo found - forcing re-clone' -Status 'RUNNING'
        Remove-Item $yadmDir -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Status 'yadm repository already initialized - pulling latest changes' -Status 'RUNNING'
        try { yadm pull; Write-Status 'Dotfiles updated' -Status 'OK' }
        catch { Write-Status "Pull failed: $_" -Status 'WARN' }
    }
}

if (-not (Test-Path $yadmDir)) {
    Write-Status "Cloning dotfiles from $repoUrl" -Status 'RUNNING'
    try { yadm clone $repoUrl; Write-Status 'Repository cloned' -Status 'OK' }
    catch { Write-Status "Clone failed: $_" -Status 'FAIL'; exit 1 }
}

# ---------------------------------------------------------------------------
# Phase 3: Run bootstrap
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '[3/5] Running bootstrap...' -ForegroundColor Cyan

$bootstrapScript = Join-Path $yadmDir 'bootstrap'
if (-not (Test-Path $bootstrapScript)) { Write-Fail "Bootstrap not found: $bootstrapScript"; exit 1 }

try {
    $bootstrapArgs = @()
    if ($Unattended) { $bootstrapArgs += '-Unattended' }
    if ($SkipWingetTools) { $bootstrapArgs += '-SkipWingetTools' }
    pwsh -NoProfile -ExecutionPolicy Bypass -File $bootstrapScript @bootstrapArgs
    Write-Status 'Bootstrap completed' -Status 'OK'
} catch {
    Write-Status "Bootstrap failed: $_" -Status 'FAIL'
    exit 1
}

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
            $installWSL = $host.UI.PromptForChoice('WSL2','Install WSL2 (recommended for Windows 11)?', @('&Yes','&No'), 0) -eq 0
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
    $color = switch ($status) { 'OK' { 'Green' } 'FAIL' { 'Red' } 'SKIP' { 'Yellow' } 'RUNNING' { 'Cyan' } default { 'White' } }
    Write-Host "  $($key.PadRight(50)) : " -NoNewline; Write-Host "$status" -ForegroundColor $color
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
if ($Unattended) { Write-Host 'Unattended setup complete. Review results above for failures.' -ForegroundColor Cyan }
else { Write-Host 'Setup complete! Re-run with -Force to re-execute.' -ForegroundColor Cyan }
Write-Host ''

function Write-Warning($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Fail($msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red }
