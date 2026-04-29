#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Verify system environment meets repository requirements.
.DESCRIPTION
    Checks for required tools (winget, Git, PowerShell 7), validates execution policy,
    confirms dotbot installation, and verifies repository structure. Outputs a
    comprehensive readiness report for fresh or existing setups.
.PARAMETER FixIssues
    Attempt to fix common issues (install missing tools, set execution policy).
.PARAMETER SkipNetwork
    Skip network-dependent checks (winget, git clone verification).
.PARAMETER Detailed
    Show verbose details for all checks, not just failures.
.EXAMPLE
    .\Test-Environment.ps1
.EXAMPLE
    .\Test-Environment.ps1 -FixIssues
.EXAMPLE
    .\Test-Environment.ps1 -Detailed
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$FixIssues,
    [switch]$SkipNetwork,
    [switch]$Detailed
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host '=== Environment Readiness Check ===' -ForegroundColor Cyan
Write-Host "  Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n" -ForegroundColor Gray

$allPass = $true
$warnings = 0

function Test-Requirement {
    param(
        [string]$Name,
        [scriptblock]$Check,
        [string]$InstallHint,
        [switch]$Required
    )
    Write-Host "  [$Name]" -NoNewline -ForegroundColor Gray
    try {
        $result = & $Check
        if ($result) {
            Write-Host ' PASS' -ForegroundColor Green
            return $true
        } else {
            Write-Host ' FAIL' -ForegroundColor Red
            if ($Required) { $script:allPass = $false } else { $script:warnings++ }
            if ($InstallHint) { Write-Host "    → $InstallHint" -ForegroundColor Yellow }
            return $false
        }
    } catch {
        Write-Host ' ERROR' -ForegroundColor Red
        Write-Host "    → $_" -ForegroundColor Yellow
        if ($Required) { $script:allPass = $false } else { $script:warnings++ }
        return $false
    }
}

# --- PowerShell Version ---
Write-Host '`n[Core Tools]' -ForegroundColor Cyan
Test-Requirement -Name 'PowerShell 5.1+' -Check {
    $PSVersionTable.PSVersion.Major -ge 5
} -InstallHint 'Windows 10/11 includes PowerShell 5.1; install PowerShell 7+ from winget'

Test-Requirement -Name 'PowerShell 7+ (recommended)' -Check {
    Get-Command pwsh -ErrorAction SilentlyContinue | Out-Null
} -InstallHint 'winget install Microsoft.PowerShell'

# --- winget ---
Test-Requirement -Name 'winget (Package Manager)' -Check {
    Get-Command winget -ErrorAction SilentlyContinue | Out-Null
} -InstallHint 'Download from https://aka.ms/getwinget or run Setup-Win11.ps1' -Required

# --- Git ---
Test-Requirement -Name 'Git' -Check {
    Get-Command git -ErrorAction SilentlyContinue | Out-Null
} -InstallHint 'winget install Git.Git' -Required

# --- Python (for dotbot) ---
Test-Requirement -Name 'Python' -Check {
    Get-Command python -ErrorAction SilentlyContinue | Out-Null
} -InstallHint 'winget install Python.Python.3.12' -Required:$false

# --- dotbot ---
Test-Requirement -Name 'dotbot' -Check {
    Get-Command dotbot -ErrorAction SilentlyContinue | Out-Null
} -InstallHint 'pip install dotbot'

# --- Execution Policy ---
Write-Host '`n[Security]' -ForegroundColor Cyan
Test-Requirement -Name 'Execution Policy (RemoteSigned at CurrentUser)' -Check {
    (Get-ExecutionPolicy -Scope CurrentUser) -eq 'RemoteSigned' -or
    (Get-ExecutionPolicy -Scope LocalMachine) -eq 'RemoteSigned' -or
    (Get-ExecutionPolicy -Scope Process) -eq 'RemoteSigned'
} -InstallHint 'Run: .\Set-ExecutionPolicySafe.ps1' -Required:$false

# --- Repository Structure ---
Write-Host '`n[Repository]' -ForegroundColor Cyan
$repoRoot = $PWD
if ($PSScriptRoot -like "*.kilo/commands/*") {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

Test-Requirement -Name 'install.conf.yaml present' -Check {
    Test-Path (Join-Path $repoRoot 'install.conf.yaml')
} -InstallHint 'Clone the repository or copy config files'

Test-Requirement -Name 'Scripts/Setup-Dotfiles.ps1 present' -Check {
    Test-Path (Join-Path $repoRoot 'Scripts/Setup-Dotfiles.ps1')
} -InstallHint 'Repository structure incomplete'

Test-Requirement -Name 'user/.dotfiles/config/ exists' -Check {
    Test-Path (Join-Path $repoRoot 'user/.dotfiles/config')
} -InstallHint 'Run dotbot to deploy configs first, or clone with submodules'

# --- System Capability ---
Write-Host '`n[System]' -ForegroundColor Cyan
Test-Requirement -Name 'Windows 10 1909+ or Windows 11' -Check {
    $os = [Environment]::OSVersion.Version
    $os.Major -eq 10 -and $os.Build -ge 1909
} -InstallHint 'Supported: Windows 10 1909+ or Windows 11'

Test-Requirement -Name 'Admin rights (for system changes)' -Check {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
} -InstallHint 'Relaunch PowerShell as Administrator' -Required:$false

# --- Optional: Network Checks ---
if (-not $SkipNetwork) {
    Write-Host '`n[Network]' -ForegroundColor Cyan
    Test-Requirement -Name 'GitHub connectivity' -Check {
        try {
            Invoke-WebRequest -Uri 'https://github.com' -Method Head -TimeoutSec 5 | Out-Null
            $true
        } catch { $false }
    } -InstallHint 'Check internet connection'

    Test-Requirement -Name 'winget source available' -Check {
        winget source list 2>&1 | Out-String | Select-String 'winget' | Out-Null
    } -InstallHint 'winget may need to download source; run winget --help'
}

# --- Summary ---
Write-Host ''
Write-Host '=== Summary ===' -ForegroundColor Cyan
if ($allPass) {
    Write-Host '  All required checks PASSED.' -ForegroundColor Green
    if ($warnings -gt 0) {
        Write-Host "  $warnings warning(s) — review non-critical items above." -ForegroundColor Yellow
    }
    Write-Host '`n  Ready to deploy: .\Deploy-Configs.ps1' -ForegroundColor Green
    exit 0
} else {
    Write-Error '  Some requirements missing. Fix failures above.'
    if ($FixIssues) {
        Write-Host '`n  Attempting fixes with -FixIssues...' -ForegroundColor Cyan
        # Run Set-ExecutionPolicy, offer to install tools
        if (-not (Get-Command dotbot -ErrorAction SilentlyContinue)) {
            Write-Host '  Installing dotbot...' -ForegroundColor Yellow
            pip install dotbot | Out-Null
        }
        # Re-run check once
        Write-Host '  Re-checking...' -ForegroundColor Gray
        & $MyInvocation.MyCommand.Path @PSBoundParameters
    }
    exit 1
}
