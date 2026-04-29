#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run PSScriptAnalyzer on PowerShell scripts with project-specific settings.
.DESCRIPTION
    Lints PowerShell files using the repository's PSScriptAnalyzerSettings.psd1.
    Can target specific files or auto-detect changed scripts via git.
    Enforces PSAvoidGlobalAliases, PSAvoidUsingConvertToSecureStringWithPlainText,
    and other repo-specific rules.
.PARAMETER Path
    Specific file or directory path to analyze. Defaults to entire Scripts/ directory.
.PARAMETER ChangedOnly
    Only analyze scripts modified in the current git working tree (git diff).
.PARAMETER UncommittedOnly
    Only analyze staged but uncommitted changes.
.PARAMETER Fix
    Attempt to auto-fix fixable issues (use with caution — review changes).
.PARAMETER ExportReport
    Save detailed analysis report to file (JSON format).
.PARAMETER OutputFile
    Path for the exported report. Default: ./psa-report.json.
.EXAMPLE
    .\Invoke-ScriptAnalyzer.ps1
.EXAMPLE
    .\Invoke-ScriptAnalyzer.ps1 -ChangedOnly
.EXAMPLE
    .\Invoke-ScriptAnalyzer.ps1 -Path Scripts/Setup-Dotfiles.ps1 -Fix
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path = 'Scripts',
    [switch]$ChangedOnly,
    [switch]$UncommittedOnly,
    [switch]$Fix,
    [string]$OutputFile = './psa-report.json',
    [switch]$OutputFile,
    [switch]$ExportReport
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = $PWD
if ($PSScriptRoot -like "*.kilo/commands/*") {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$settingsPath = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'

if (-not (Test-Path $settingsPath)) {
    Write-Warning "PSScriptAnalyzerSettings.psd1 not found at $settingsPath — using default rules"
}

# Resolve target paths
$targets = @()
if ($ChangedOnly) {
    Write-Host '=== PSScriptAnalyzer (Changed Files Only) ===' -ForegroundColor Cyan
    $changed = git diff --name-only 2>$null | Where-Object { $_ -like '*.ps1' -or $_ -like '*.psm1' -or $_ -like '*.psd1' }
    if (-not $changed) {
        Write-Host '  No changed PowerShell files detected.' -ForegroundColor Yellow
        exit 0
    }
    foreach ($relPath in $changed) {
        $fullPath = Join-Path $repoRoot $relPath
        if (Test-Path $fullPath) {
            $targets += $fullPath
        }
    }
} elseif ($UncommittedOnly) {
    Write-Host '=== PSScriptAnalyzer (Staged Changes Only) ===' -ForegroundColor Cyan
    $staged = git diff --cached --name-only 2>$null | Where-Object { $_ -like '*.ps1' -or $_ -like '*.psm1' -or $_ -like '*.psd1' }
    if (-not $staged) {
        Write-Host '  No staged PowerShell files detected.' -ForegroundColor Yellow
        exit 0
    }
    foreach ($relPath in $staged) {
        $fullPath = Join-Path $repoRoot $relPath
        if (Test-Path $fullPath) {
            $targets += $fullPath
        }
    }
} else {
    Write-Host '=== PSScriptAnalyzer (Full Scan) ===' -ForegroundColor Cyan
    if (Test-Path $Path) {
        $resolved = Resolve-Path $Path -ErrorAction SilentlyContinue
        if ($resolved) {
            $targets = $resolved | ForEach-Object { $_.Path }
        } else {
            # Path might be a single file
            if (Test-Path $Path -PathType Leaf) {
                $targets = @((Resolve-Path $Path).Path)
            } else {
                Write-Error "Path not found: $Path"
                exit 1
            }
        }
    } else {
        Write-Error "Path not found: $Path"
        exit 1
    }
}

Write-Host "  Analyzing $($targets.Count) file(s)" -ForegroundColor Gray
if ($settingsPath) {
    Write-Host "  Settings:  $settingsPath" -ForegroundColor Gray
}
Write-Host ''

$allResults = @()
$hasErrors = $false

foreach ($file in $targets) {
    Write-Host "  [+] $file" -NoNewline -ForegroundColor Gray
    try {
        $params = @('-Path', "`"$file`"", '-Recurse:$false', '-Verbose:$false', '-ErrorAction', 'Stop']
        if ($settingsPath) { $params += '-Settings'; $params += "`"$settingsPath`"" }

        $result = Invoke-ScriptAnalyzer @params 2>&1

        if ($result) {
            Write-Host ' FAIL' -ForegroundColor Red
            foreach ($record in $result) {
                Write-Host "    [$($record.Severity)] $($record.RuleName)" -ForegroundColor Yellow
                Write-Host "      Line $($record.Line): $($record.Message)" -ForegroundColor White
                $allResults += $record
            }
            $hasErrors = $true
        } else {
            Write-Host ' PASS' -ForegroundColor Green
        }
    } catch {
        Write-Host ' ERROR' -ForegroundColor Red
        Write-Host "    $_" -ForegroundColor Red
        $hasErrors = $true
    }
}

if ($ExportReport -and $allResults.Count -gt 0) {
    $reportPath = Join-Path $repoRoot $OutputFile
    $allResults | ConvertTo-Json -Depth 3 | Set-Content $reportPath
    Write-Host "`n  Report exported to $reportPath" -ForegroundColor Cyan
}

Write-Host ''
if ($hasErrors) {
    Write-Error "Analysis FAILED — $($allResults.Count) issue(s) found"
    exit 1
} else {
    Write-Host 'All scripts pass PSScriptAnalyzer.' -ForegroundColor Green
    exit 0
}
