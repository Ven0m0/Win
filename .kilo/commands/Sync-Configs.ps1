#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Sync dotfiles: pull latest changes and optionally re-deploy.
.DESCRIPTION
    Fast workflow for keeping dotfiles up to date. Pulls latest from GitHub,
    then optionally re-runs dotbot deployment to apply any config changes.
    Can target specific config groups for selective update.
.PARAMETER PullOnly
    Only git pull, do not redeploy.
.PARAMETER DeployAfterPull
    Pull then run full dotbot deployment (default behavior).
.PARAMETER Target
    Deploy only specific config groups after pulling (implies DeployAfterPull).
.PARAMETER Force
    Force re-deploy even if no changes detected (useful after manual config edits).
.PARAMETER Branch
    Specify branch to pull (default: current branch).
.PARAMETER Repository
    Specify remote repository URL (default: origin).
.PARAMETER DryRun
    Show what would be pulled/deployed without making changes.
.EXAMPLE
    .\Sync-Configs.ps1
    # Pull latest and redeploy all
.EXAMPLE
    .\Sync-Configs.ps1 -PullOnly
    # Just update the repository
.EXAMPLE
    .\Sync-Configs.ps1 -Target 'PowerShell profile'
    # Pull then update only PowerShell profile
.EXAMPLE
    .\Sync-Configs.ps1 -Force -DeployAfterPull
    # Pull and force full redeploy
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(ParameterSetName = 'PullOnly')]
    [switch]$PullOnly,

    [Parameter(ParameterSetName = 'Deploy')]
    [switch]$DeployAfterPull,

    [Parameter(ParameterSetName = 'TargetDeploy')]
    [string[]]$Target,

    [switch]$Force,
    [string]$Branch,
    [string]$Repository = 'origin',
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = $PWD
if ($PSScriptRoot -like "*.kilo/commands/*") {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

pushd $repoRoot

Write-Host '=== Sync Dotfiles ===' -ForegroundColor Cyan

# --- Git Pull ---
Write-Host '`n[1/2] Pulling latest changes...' -ForegroundColor Cyan
if ($DryRun) {
    Write-Host '  [DRY-RUN] git fetch would be executed' -ForegroundColor Yellow
} else {
    try {
        $fetchArgs = @('fetch', $Repository)
        if ($Branch) { $fetchArgs += $Branch }
        git @fetchArgs
        if ($LASTEXITCODE -ne 0) { throw "git fetch failed" }

        $pullArgs = @('pull', $Repository)
        if ($Branch) { $pullArgs += $Branch }
        git @pullArgs
        if ($LASTEXITCODE -ne 0) { throw "git pull failed" }

        Write-Host '  Repository updated.' -ForegroundColor Green
    } catch {
        Write-Error "Git operation failed: $_"
        exit 1
    }
}

# Check if there are config changes to deploy
$configChanged = $false
if (-not $PullOnly) {
    $status = git status --porcelain 2>$null | Out-String
    $configChanged = $status -match 'user/.dotfiles/config/'
    if ($Force) { $configChanged = $true }
}

# --- Deploy ---
if ($PullOnly) {
    Write-Host '`n[2/2] Pull-only mode — skipping deployment.' -ForegroundColor Cyan
    exit 0
}

Write-Host ''
if ($Target) {
    Write-Host "[2/2] Deploying targeted configs: $($Target -join ', ')" -ForegroundColor Cyan
    $deployScript = Join-Path $repoRoot 'Scripts/Setup-Dotfiles.ps1'
    $deployArgs = @()
    foreach ($t in $Target) {
        $deployArgs += '-Target'; $deployArgs += "'$t'"
    }
    if ($DryRun) { $deployArgs += '-WhatIf' }

    pwsh -NoLogo -NoProfile -File $deployScript @deployArgs
} elseif ($configChanged -or $DeployAfterPull) {
    Write-Host '[2/2] Running full dotbot deployment...' -ForegroundColor Cyan
    $deployScript = Join-Path $repoRoot 'Scripts/Setup-Dotfiles.ps1'
    $deployArgs = @()
    if ($DryRun) { $deployArgs += '-WhatIf' }

    pwsh -NoLogo -NoProfile -File $deployScript @deployArgs
} else {
    Write-Host '[2/2] No config changes detected. Skipping deployment.' -ForegroundColor Gray
    Write-Host '  Use -Force to redeploy anyway, or -Target to deploy specific groups.' -ForegroundColor Gray
}

Write-Host ''
Write-Host 'Sync complete.' -ForegroundColor Green
popd
