#Requires -Version 5.1
<#
.SYNOPSIS
    PowerShell Pester test runner script for pre-commit hooks and CI.

.DESCRIPTION
    Finds and runs Pester tests (*.Tests.ps1) for PowerShell scripts.
    Outputs results in a format suitable for CI integration.

.PARAMETER Path
    Root path to search for tests. Defaults to the repository root.

.PARAMETER Pattern
    File pattern to match test files. Default: *.Tests.ps1

.PARAMETER OutputFormat
    Pester output format: Detailed, Normal, Minimal, None. Default: Detailed

.PARAMETER Coverage
    Enable code coverage reporting. Default: false

.EXAMPLE
    # Run all tests
    .\Test-PowerShell.ps1

.EXAMPLE
    # Run tests in specific path
    .\Test-PowerShell.ps1 -Path "Scripts/"

.EXAMPLE
    # Run tests with coverage
    .\Test-PowerShell.ps1 -Coverage -OutputFormat Normal
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [string]$Pattern = '*.Tests.ps1',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Detailed', 'Normal', 'Minimal', 'None')]
    [string]$OutputFormat = 'Detailed',

    [Parameter(Mandatory = $false)]
    [switch]$Coverage
)

$ErrorActionPreference = 'Stop'

# Find the test directory relative to this script
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

if (-not $Path) {
    $Path = $RepoRoot
}

# Verify Pester is available
$pesterModule = Get-Module -Name Pester -ListAvailable
if (-not $pesterModule) {
    Write-Host "Pester module not found. Installing..." -ForegroundColor Yellow
    try {
        # For PowerShell 5.1, install Pester 5.x
        Install-Module -Name Pester -MinimumVersion 5.0 -Scope CurrentUser -Force -SkipPublisherCheck -AllowClobber
        Import-Module Pester -MinimumVersion 5.0
    } catch {
        Write-Host "Failed to install Pester: $_" -ForegroundColor Red
        exit 1
    }
} else {
    Import-Module Pester -MinimumVersion 5.0 -Force
}

Write-Host "Running PowerShell tests in: $Path" -ForegroundColor Cyan
Write-Host "Pattern: $Pattern" -ForegroundColor Cyan
Write-Host ""

# Find test files
$testFiles = Get-ChildItem -Path $Path -Recurse -Include $Pattern -File

if ($testFiles.Count -eq 0) {
    Write-Host "No test files found matching pattern '$Pattern' in $Path" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($testFiles.Count) test file(s)" -ForegroundColor Green
Write-Host ""

# Build Pester configuration
$pesterConfig = New-PesterConfiguration
$pesterConfig.Run.Path = $testFiles.FullName
$pesterConfig.Output.Verbosity = $OutputFormat
$pesterConfig.TestResult.Enabled = $true
$pesterConfig.TestResult.OutputPath = Join-Path $RepoRoot '.agents_tmp/test-results.xml'
$pesterConfig.TestResult.OutputFormat = 'NUnitXml'

if ($Coverage) {
    $pesterConfig.CodeCoverage.Enabled = $true
    $pesterConfig.CodeCoverage.OutputPath = Join-Path $RepoRoot '.agents_tmp/coverage.xml'
    $pesterConfig.CodeCoverage.OutputEncoding = 'UTF8'
}

# Run tests
try {
    $result = Invoke-Pester -Configuration $pesterConfig

    Write-Host ""
    if ($result.FailedCount -gt 0) {
        Write-Host "Tests failed: $($result.FailedCount) of $($result.TotalCount)" -ForegroundColor Red
        exit 1
    } elseif ($result.SkippedCount -gt 0) {
        Write-Host "Tests passed (some skipped): $($result.PassedCount) passed, $($result.SkippedCount) skipped" -ForegroundColor Yellow
        exit 0
    } else {
        Write-Host "All tests passed: $($result.PassedCount)" -ForegroundColor Green
        exit 0
    }
} catch {
    Write-Host "Test execution failed: $_" -ForegroundColor Red
    exit 1
}
