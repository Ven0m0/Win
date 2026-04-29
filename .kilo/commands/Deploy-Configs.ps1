#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy dotfiles using dotbot with hash-based change detection.
.DESCRIPTION
    Canonical deployment command: runs dotbot against install.conf.yaml.
    Use this to apply configuration changes after editing tracked files.
    Supports dry-run (-WhatIf), verbose output, and targeted deployment.
.PARAMETER WhatIf
    Show what would change without modifying any files.
.PARAMETER VerboseOutput
    Enable verbose dotbot output for detailed change logs.
.PARAMETER Target
    Deploy only specific config groups (e.g., 'PowerShell profile', 'Windows Terminal').
.PARAMETER SkipWingetTools
    Skip winget package installation phase (only deploy configs).
.PARAMETER SkipWSL
    Skip WSL2 configuration during deployment.
.EXAMPLE
    .\Deploy-Configs.ps1
.EXAMPLE
    .\Deploy-Configs.ps1 -WhatIf
.EXAMPLE
    .\Deploy-Configs.ps1 -Target 'PowerShell profile' -VerboseOutput
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$WhatIf,
    [switch]$VerboseOutput,
    [string[]]$Target,
    [switch]$SkipWingetTools,
    [switch]$SkipWSL
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolve repo root from script location
$scriptPath = $PSScriptRoot
if ($scriptPath -like "*.kilo/commands/*") {
    # Running from .kilo/commands; repo root is two levels up
    $repoRoot = Split-Path (Split-Path $scriptPath -Parent) -Parent
} else {
    $repoRoot = $PWD
}

$installConf = Join-Path $repoRoot 'install.conf.yaml'
$setupScript = Join-Path $repoRoot 'Scripts/Setup-Dotfiles.ps1'

if (-not (Test-Path $installConf)) {
    Write-Error "install.conf.yaml not found at $installConf. Are you in the repository root?"
    exit 1
}

Write-Host '=== Deploy Dotfiles ===' -ForegroundColor Cyan
Write-Host "  Repository: $repoRoot"
Write-Host "  Config:     $installConf"
Write-Host ''

if ($WhatIf) {
    Write-Host '  [DRY-RUN] Showing what would change without modifying files.' -ForegroundColor Yellow
}

# Build args for dotbot or Setup-Dotfiles.ps1
$dotbotArgs = @('-c', $installConf)
if ($WhatIf) { $dotbotArgs += '-p' }  # dotbot print mode for dry-run
if ($VerboseOutput) { $dotbotArgs += '-v' }

if ($Target) {
    # Use Setup-Dotfiles.ps1 for targeted deployment
    $setupArgs = @()
    foreach ($t in $Target) {
        $setupArgs += "-Target"; $setupArgs += "'$t'"
    }
    if ($SkipWingetTools) { $setupArgs += '-SkipWingetTools' }
    if ($SkipWSL) { $setupArgs += '-SkipWSL' }
    if ($WhatIf) { $setupArgs += '-WhatIf' }

    Write-Host "  [TARGETED] Deploying: $($Target -join ', ')" -ForegroundColor Cyan
    pwsh -NoLogo -NoProfile -File $setupScript @setupArgs
} else {
    # Full dotbot deployment
    Write-Host '  [FULL] Running dotbot deployment...' -ForegroundColor Cyan

    if ($WhatIf) {
        # Dry-run: just print what would happen
        dotbot @dotbotArgs
    } else {
        if ($PSCmdlet.ShouldProcess('dotbot', 'Deploy all dotfiles')) {
            dotbot @dotbotArgs
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Deployment failed with exit code $LASTEXITCODE"
                exit $LASTEXITCODE
            }
        }
    }
}

Write-Host ''
Write-Host '  Deployment complete.' -ForegroundColor Green
