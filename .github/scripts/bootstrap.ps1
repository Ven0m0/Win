#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Standalone bootstrap: installs dotbot if missing, clones repo, runs full setup.
.DESCRIPTION
    This script can be downloaded and executed directly without dotbot pre-installed.
    It handles all prerequisites and then delegates to the repository's bootstrap.
    Perfect for a single-command fresh Windows install.

    Usage from PowerShell (run as admin or script will self-elevate):
    ```powershell
    iwr https://raw.githubusercontent.com/Ven0m0/Win/main/bootstrap.ps1 -UseBasicParsing | iex
    ```
.PARAMETER Unattended
    Skip prompts and use defaults automatically.
.PARAMETER SkipWSL
    Skip WSL2 installation.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Unattended,
    [switch]$SkipWSL
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

# Self-elevate if not admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Info "Administrator privileges required. Relaunching..."
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    $shell = if ($pwshCmd) { $pwshCmd.Source } else { 'PowerShell.exe' }
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($Unattended) { $argList += ' -Unattended' }
    if ($SkipWSL) { $argList += ' -SkipWSL' }
    Start-Process $shell -ArgumentList $argList -Verb RunAs
    exit 0
}

Write-Host ''
Write-Host '=== Ven0m0/Win - One-Command Bootstrap ===' -ForegroundColor Cyan
Write-Host ''

# ---------------------------------------------------------------------------
# Step 1: Ensure winget (pre-requisite for yadm)
# ---------------------------------------------------------------------------
Write-Info 'Checking for winget...'

function Install-Winget {
    param([string]$Method = 'msix')
    if ($Method -eq 'msix') {
        # GitHub latest release method
        $releasesUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        try {
            $releases = Invoke-RestMethod -Uri $releasesUrl -UseBasicParsing
            $asset = $releases.assets | Where-Object { $_.browser_download_url -like '*msixbundle' } | Select-Object -First 1
            if ($asset) {
                Write-Info "Downloading winget from $($asset.browser_download_url)..."
                $tempFile = Join-Path $env:TEMP "winget.msixbundle"
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $tempFile -UseBasicParsing
                Write-Info 'Installing winget (this may take a minute)...'
                Add-AppxPackage -Path $tempFile -ErrorAction Stop
                Remove-Item $tempFile -Force
                return $true
            }
        } catch {
            Write-Warn "MSIX installation failed: $_"
        }
    }
    return $false
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Info 'winget not found - installing...'
    $installed = Install-Winget
    if (-not $installed) {
        Write-Fail 'Failed to install winget automatically.'
        Write-Host '  Please install winget manually from: https://aka.ms/getwinget' -ForegroundColor Yellow
        Write-Host '  Then re-run this script.' -ForegroundColor Yellow
        exit 1
    }
    Write-Ok 'winget installed successfully'
} else {
    Write-Ok 'winget is already installed'
}

# ---------------------------------------------------------------------------
# Step 2: Install dotbot via pip
# ---------------------------------------------------------------------------
Write-Info 'Installing dotbot (dotfile manager)...'
if (-not (Get-Command dotbot -ErrorAction SilentlyContinue)) {
    # Ensure Python is available via winget
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        Write-Info 'Installing Python via winget...'
        winget install --id Python.Python.3.12 --silent --accept-source-agreements --accept-package-agreements | Out-Null
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
            Write-Fail "Failed to install Python: Exit code: $LASTEXITCODE"
            exit 1
        }
        Write-Ok 'Python installed'
    } else {
        Write-Ok 'Python is already installed'
    }
    
    # Install dotbot via pip
    try {
        Write-Info 'Installing dotbot via pip...'
        pip install dotbot | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Ok 'dotbot installed'
        } else {
            throw "Exit code: $LASTEXITCODE"
        }
    } catch {
        Write-Fail "Failed to install dotbot: $_"
        exit 1
    }
} else {
    Write-Ok 'dotbot is already installed'
}

# ---------------------------------------------------------------------------
# Step 3: Clone repository via git
# ---------------------------------------------------------------------------
Write-Info 'Cloning dotfiles repository...'
$repoUrl = 'https://github.com/Ven0m0/Win.git'
$repoDir = Join-Path $HOME 'Win'  # Changed from .yadm to Win to match actual repo name

if (Test-Path $repoDir) {
    Write-Info 'Repository already exists - pulling updates...'
    try {
        git -C $repoDir pull
        Write-Ok 'Repository updated'
    } catch {
        Write-Warn "Pull failed, attempting fresh clone: $_"
        Remove-Item $repoDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if (-not (Test-Path $repoDir)) {
    try {
        git clone $repoUrl $repoDir
        Write-Ok 'Repository cloned'
    } catch {
        Write-Fail "Failed to clone repository: $_"
        exit 1
    }
}
}

if (-not (Test-Path $yadmDir)) {
    try {
        yadm clone $repoUrl
        Write-Ok 'Repository cloned'
    } catch {
        Write-Fail "Failed to clone repository: $_"
        exit 1
    }
}

# ---------------------------------------------------------------------------
# Step 4: Run repository bootstrap via dotbot
# ---------------------------------------------------------------------------
Write-Info 'Running repository bootstrap...'
# Change to repository directory and run dotbot
pushd $repoDir
try {
    dotbot -c install.conf.yaml
    Write-Ok 'Bootstrap completed successfully'
} catch {
    Write-Fail "Bootstrap failed: $_"
    popd
    exit 1
}
popd

Write-Host ''
Write-Ok 'Setup Complete!'
Write-Host ''
Write-Host '  Please restart your terminal or PowerShell session to load the new profile.' -ForegroundColor Cyan
Write-Host '  Run Get-Help about_* or explore Scripts/ for available utilities.' -ForegroundColor Cyan
Write-Host ''
