#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Standalone bootstrap: installs prerequisites and clones the dotfiles repo on a clean Windows install.
.DESCRIPTION
    Single entry point for a brand-new Windows machine with nothing installed. It ensures
    winget, Git, Python, mise, and uv are present, shallow-clones the dotfiles repository
    into $env:USERPROFILE\project\Win, then chains into Scripts/Setup-Win11.ps1 for the full
    machine setup (debloat, software catalog, mise-managed dotbot config deploy, WSL2).

    Usage from PowerShell (run as admin or script will self-elevate):
    ```powershell
    iwr https://raw.githubusercontent.com/Ven0m0/Win/main/bootstrap.ps1 -UseBasicParsing | iex
    ```
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

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$env:MISE_YES = '1'

function Write-Info($msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Fail($msg) { Write-Host "[FAIL] $msg" -ForegroundColor Red }
function Write-Warn($msg) { Write-Host "[WARN] $msg" -ForegroundColor Yellow }

function Update-SessionPath {
    <#
    .SYNOPSIS
        Refreshes $env:PATH from the registry so tools installed by winget in this
        process become resolvable without restarting the shell.
    #>
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:PATH = ($machine, $user, $env:PATH -join ';')
}

function Install-WingetPackage {
    <#
    .SYNOPSIS
        Installs a package via winget if its command isn't already resolvable.
    .PARAMETER Command
        Command name to check for on PATH before installing.
    .PARAMETER Id
        Winget package identifier.
    .PARAMETER Name
        Human-readable name for output messages.
    #>
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name
    )
    if (Get-Command $Command -ErrorAction SilentlyContinue) {
        Write-Ok "$Name is already installed"
        return $true
    }
    Write-Info "Installing $Name via winget..."
    winget install --id $Id --silent --accept-source-agreements --accept-package-agreements | Out-Null
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) {
        Write-Fail "Failed to install $Name (exit code $LASTEXITCODE)"
        return $false
    }
    Update-SessionPath
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        Write-Warn "$Name installed but '$Command' not yet resolvable in this session (restart terminal if later steps fail)"
    }
    Write-Ok "$Name installed"
    return $true
}

# Self-elevate if not admin
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Info "Administrator privileges required. Relaunching..."
    $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
    $shell = if ($pwshCmd) { $pwshCmd.Source } else { 'PowerShell.exe' }
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    foreach ($p in 'Unattended', 'Force', 'SkipWingetTools', 'SkipWSL', 'SkipPackages', 'SkipDebloat') {
        if ((Get-Variable $p -ErrorAction SilentlyContinue).Value) { $argList += " -$p" }
    }
    Start-Process $shell -ArgumentList $argList -Verb RunAs
    exit 0
}

Write-Host ''
Write-Host '=== Ven0m0/Win - One-Command Bootstrap ===' -ForegroundColor Cyan
Write-Host ''

# ---------------------------------------------------------------------------
# Step 1: Ensure winget (pre-requisite for everything below)
# ---------------------------------------------------------------------------
Write-Info 'Checking for winget...'

function Install-Winget {
    param([string]$Method = 'msix')
    if ($Method -eq 'msix') {
        # GitHub latest release method
        $releasesUrl = "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        try {
            $releases = Invoke-RestMethod -Uri $releasesUrl -UseBasicParsing
            $asset = $releases.assets |
              Where-Object { $_.browser_download_url -like '*msixbundle' } |
              Select-Object -First 1
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
# Step 2: Install prerequisites (Git, Python, mise, uv)
# ---------------------------------------------------------------------------
Write-Info 'Installing prerequisites...'

$prereqs = @(
    @{ Command = 'git';    Id = 'Git.Git';            Name = 'Git' },
    @{ Command = 'python'; Id = 'Python.Python.3.14'; Name = 'Python 3.14' },
    @{ Command = 'mise';   Id = 'jdx.mise';            Name = 'mise' },
    @{ Command = 'uv';     Id = 'astral-sh.uv';        Name = 'uv' }
)

$gitReady = $true
foreach ($prereq in $prereqs) {
    $ok = Install-WingetPackage -Command $prereq.Command -Id $prereq.Id -Name $prereq.Name
    if (-not $ok -and $prereq.Command -eq 'git') { $gitReady = $false }
}

if (-not $gitReady) {
    Write-Fail 'Git is required to clone the repository. Install it manually and re-run.'
    exit 1
}

# ---------------------------------------------------------------------------
# Step 3: Shallow-clone the repository
# ---------------------------------------------------------------------------
$projectRoot = Join-Path $env:USERPROFILE 'project'
$repoDir = Join-Path $projectRoot 'Win'
$repoUrl = 'https://github.com/Ven0m0/Win.git'

if (-not (Test-Path $projectRoot)) {
    Write-Info "Creating project directory: $projectRoot"
    $null = New-Item -ItemType Directory -Path $projectRoot -Force
}

Write-Info 'Cloning dotfiles repository...'
if (Test-Path $repoDir) {
    Write-Info 'Repository already exists - pulling updates...'
    git -C $repoDir pull --depth 1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Pull failed (exit $LASTEXITCODE), attempting fresh clone"
        Remove-Item $repoDir -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Ok 'Repository updated'
    }
}

if (-not (Test-Path $repoDir)) {
    git clone --depth 1 $repoUrl $repoDir
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Failed to clone repository (exit code $LASTEXITCODE)"
        exit 1
    }
    Write-Ok 'Repository cloned'
}

# ---------------------------------------------------------------------------
# Step 4: Chain into the full Windows 11 setup (debloat, packages, dotbot, WSL)
# ---------------------------------------------------------------------------
$setupScript = Join-Path $repoDir 'Scripts\Setup-Win11.ps1'
if (-not (Test-Path $setupScript)) {
    Write-Fail "Setup-Win11.ps1 not found at: $setupScript"
    exit 1
}

Write-Info 'Running full Windows 11 setup...'
$setupParams = @{}
foreach ($p in 'Unattended', 'Force', 'SkipWingetTools', 'SkipWSL', 'SkipPackages', 'SkipDebloat') {
    if ((Get-Variable $p -ErrorAction SilentlyContinue).Value) { $setupParams[$p] = $true }
}
if ($WhatIfPreference) { $setupParams['WhatIf'] = $true }

$setupResult = & $setupScript @setupParams
if (-not $setupResult) {
    Write-Fail 'Windows 11 setup reported failure(s). Review the summary above.'
    exit 1
}

Write-Host ''
Write-Ok 'Setup Complete!'
Write-Host ''
Write-Host "  Repository: $repoDir" -ForegroundColor Cyan
Write-Host '  Please restart your terminal or PowerShell session to load the new profile.' -ForegroundColor Cyan
Write-Host '  Run Get-Help about_* or explore Scripts/ for available utilities.' -ForegroundColor Cyan
Write-Host ''
