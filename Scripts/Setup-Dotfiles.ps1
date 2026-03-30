#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploys dotfiles and sets up a Windows development environment.
.DESCRIPTION
    Canonical implementation of the yadm bootstrap process. Installs tools via winget,
    deploys config files with hash-based change detection, and configures the environment
    non-interactively. Can be run standalone or via .yadm/bootstrap.
.EXAMPLE
    .\Setup-Dotfiles.ps1
.EXAMPLE
    .\Setup-Dotfiles.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# ---------------------------------------------------------------------------
# Admin elevation
# ---------------------------------------------------------------------------
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
  Write-Host 'Relaunching as administrator...' -ForegroundColor Yellow
  $pwshCmd = Get-Command pwsh -ErrorAction SilentlyContinue
  $shell = if ($pwshCmd) { $pwshCmd.Source } else { 'PowerShell.exe' }
  $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
  if ($WhatIfPreference) { $argList += ' -WhatIf' }
  Start-Process $shell -ArgumentList $argList -Verb RunAs
  exit 0
}

$configRoot = Join-Path $HOME 'user\.dotfiles\config'

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

function Deploy-Config {
  <#
  .SYNOPSIS
      Deploys a config file, copying only if the source differs from the destination.
  .PARAMETER Source
      Full path to the source file.
  .PARAMETER Destination
      Full path to the destination file.
  .PARAMETER Label
      Human-readable label for output messages.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [string]$Source,
    [string]$Destination,
    [string]$Label
  )

  if (-not (Test-Path $Source)) {
    Write-Warning "  [SKIP] $Label — source not found: $Source"
    return
  }

  $destDir = Split-Path $Destination -Parent
  $srcHash = (Get-FileHash $Source -Algorithm SHA256).Hash

  if (Test-Path $Destination) {
    $dstHash = (Get-FileHash $Destination -Algorithm SHA256).Hash
    if ($srcHash -eq $dstHash) {
      Write-Host "  [UP-TO-DATE] $Label" -ForegroundColor Gray
      return
    }
  }

  if ($PSCmdlet.ShouldProcess($Destination, "Deploy $Label")) {
    if (-not (Test-Path $destDir)) {
      New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Copy-Item $Source $Destination -Force
    Write-Host "  [OK] $Label deployed" -ForegroundColor Green
  }
}

function Deploy-ConfigDirectory {
  <#
  .SYNOPSIS
      Deploys all files matching a filter from a source directory to a destination directory.
  .PARAMETER SourceDir
      Path to the source directory.
  .PARAMETER DestDir
      Path to the destination directory.
  .PARAMETER Filter
      File filter pattern (default: *).
  .PARAMETER Label
      Human-readable label for output messages.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [string]$SourceDir,
    [string]$DestDir,
    [string]$Filter = '*',
    [string]$Label
  )

  if (-not (Test-Path $SourceDir)) {
    Write-Warning "  [SKIP] $Label — source directory not found: $SourceDir"
    return
  }

  $files = Get-ChildItem -Path $SourceDir -Filter $Filter -File
  if ($files.Count -eq 0) {
    Write-Host "  [SKIP] $Label — no files matching '$Filter' in $SourceDir" -ForegroundColor Gray
    return
  }

  foreach ($file in $files) {
    Deploy-Config -Source $file.FullName -Destination (Join-Path $DestDir $file.Name) -Label "$Label/$($file.Name)"
  }
}

function Install-WingetTool {
  <#
  .SYNOPSIS
      Installs a package via winget. Treats exit codes 0 and -1978335189 (already installed) as success.
  .PARAMETER Id
      Winget package identifier.
  .PARAMETER Name
      Human-readable tool name for output messages.
  #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [string]$Id,
    [string]$Name
  )

  if ($PSCmdlet.ShouldProcess($Name, 'Install via winget')) {
    Write-Host "  Installing $Name..." -ForegroundColor Gray -NoNewline
    try {
      winget install --id $Id --silent --accept-source-agreements --accept-package-agreements 2>&1 | Out-Null
      $ec = $LASTEXITCODE
      # 0 = success, -1978335189 (0x8A150021) = already installed at required version
      if ($ec -eq 0 -or $ec -eq -1978335189) {
        Write-Host " [OK]" -ForegroundColor Green
      } else {
        Write-Host ""
        Write-Warning "  [WARN] $Name — winget exit code: $ec"
      }
    } catch {
      Write-Host ""
      Write-Warning "  [WARN] $Name — $_"
    }
  }
}

# ---------------------------------------------------------------------------
# Phase 1: Prerequisites & execution policy
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '[1/5] Setting execution policy...' -ForegroundColor Cyan

try {
  if ($PSCmdlet.ShouldProcess('CurrentUser execution policy', 'Set to RemoteSigned')) {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host '  [OK] Execution policy set to RemoteSigned (CurrentUser)' -ForegroundColor Green
  }
} catch {
  Write-Warning "  Could not set execution policy: $_"
}

# ---------------------------------------------------------------------------
# Phase 2: Install tools via winget
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '[2/5] Installing tools...' -ForegroundColor Cyan

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Warning '  winget not found. Install from: https://aka.ms/getwinget'
} else {
  $tools = @(
    @{ id = 'Git.Git';                    name = 'Git' },
    @{ id = 'Microsoft.PowerShell';       name = 'PowerShell 7+' },
    @{ id = 'Microsoft.WindowsTerminal';  name = 'Windows Terminal' },
    @{ id = 'Microsoft.VisualStudioCode'; name = 'VS Code' },
    @{ id = 'yadm.yadm';                  name = 'yadm' }
  )

  foreach ($tool in $tools) {
    Install-WingetTool -Id $tool.id -Name $tool.name
  }
}

# ---------------------------------------------------------------------------
# Phase 3: Deploy configs
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '[3/5] Deploying configs...' -ForegroundColor Cyan

# PowerShell profile
Deploy-Config `
  -Source (Join-Path $configRoot 'powershell\profile.ps1') `
  -Destination $PROFILE `
  -Label 'PowerShell profile'

# Windows Terminal — glob for package dir to handle version string changes
$wtPackageDir = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Filter 'Microsoft.WindowsTerminal_*' -Directory -ErrorAction SilentlyContinue |
  Select-Object -First 1
if ($wtPackageDir) {
  Deploy-Config `
    -Source (Join-Path $configRoot 'windows-terminal\settings.json') `
    -Destination (Join-Path $wtPackageDir.FullName 'LocalState\settings.json') `
    -Label 'Windows Terminal settings'
} else {
  Write-Host '  [SKIP] Windows Terminal — package directory not found' -ForegroundColor Gray
}

# BleachBit custom cleaners
Deploy-ConfigDirectory `
  -SourceDir (Join-Path $configRoot 'bleachbit\cleaners') `
  -DestDir "$env:APPDATA\BleachBit\cleaners" `
  -Filter '*.xml' `
  -Label 'BleachBit cleaners'

# Configs with unknown destinations — skip with informational warnings
$tbdConfigs = @(
  @{ path = 'nvidia';    note = 'NVIDIA Inspector — destination path varies by install location' },
  @{ path = 'games\bf2'; note = 'BF2 — game config path not yet mapped' },
  @{ path = 'games\bo6'; note = 'BO6 — COD config path varies by install' },
  @{ path = 'games\bo7'; note = 'BO7 — COD config path varies by install' },
  @{ path = 'cmd';       note = 'CMD aliases — destination path not yet mapped' },
  @{ path = 'firefox';   note = 'Firefox — profile path varies per installation' },
  @{ path = 'brave';     note = 'Brave — user data path not yet mapped' }
)

foreach ($cfg in $tbdConfigs) {
  $srcPath = Join-Path $configRoot $cfg.path
  if (Test-Path $srcPath) {
    Write-Warning "  [SKIP] $($cfg.path) — $($cfg.note)"
  }
}

# ---------------------------------------------------------------------------
# Phase 4: PATH + directory setup
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '[4/5] Configuring PATH and directories...' -ForegroundColor Cyan

$scriptsPath = Join-Path $HOME 'Scripts'
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')

if (-not $userPath) { $userPath = '' }

if ($userPath -notlike "*$scriptsPath*") {
  if ($PSCmdlet.ShouldProcess('User PATH', "Add $scriptsPath")) {
    $newPath = ($userPath.TrimEnd(';') + ";$scriptsPath").TrimStart(';')
    [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    Write-Host "  [OK] Added Scripts to PATH" -ForegroundColor Green
  }
} else {
  Write-Host '  [UP-TO-DATE] Scripts already in PATH' -ForegroundColor Gray
}

$commonDirs = @(
  "$HOME\.local\bin",
  "$HOME\.cache",
  "$HOME\Projects"
)

foreach ($dir in $commonDirs) {
  if (-not (Test-Path $dir)) {
    if ($PSCmdlet.ShouldProcess($dir, 'Create directory')) {
      New-Item -ItemType Directory -Path $dir -Force | Out-Null
      Write-Host "  [OK] Created $dir" -ForegroundColor Green
    }
  }
}

# ---------------------------------------------------------------------------
# Phase 5: Verification summary
# ---------------------------------------------------------------------------
Write-Host ''
Write-Host '[5/5] Verification summary' -ForegroundColor Cyan

$updatedPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$checks = @(
  @{ label = 'PowerShell profile';      ok = Test-Path $PROFILE },
  @{ label = 'Scripts directory';       ok = Test-Path $scriptsPath },
  @{ label = 'Scripts in PATH';         ok = ($updatedPath -like "*$scriptsPath*") },
  @{ label = 'Execution policy (User)'; ok = (Get-ExecutionPolicy -Scope CurrentUser) -notin @('Restricted', 'Undefined') }
)

foreach ($check in $checks) {
  if ($check.ok) {
    Write-Host "  [OK] $($check.label)" -ForegroundColor Green
  } else {
    Write-Host "  [!!] $($check.label)" -ForegroundColor Red
  }
}

Write-Host ''
Write-Host 'Bootstrap complete. Restart your terminal to apply the new profile.' -ForegroundColor Cyan
Write-Host ''
