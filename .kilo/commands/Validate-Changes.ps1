#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Validate repository changes: run PSScriptAnalyzer, check autounattend.xml, and lint guidance files.
.DESCRIPTION
    Comprehensive validation command for CI-like checks on local changes.
    Runs ScriptAnalyzer on changed PowerShell files, validates autounattend.xml,
    and runs ctxlint on .github/ guidance files. Use before committing.
.PARAMETER All
    Run all validation checks regardless of changed files.
.PARAMETER PowerShellOnly
    Only validate PowerShell scripts.
.PARAMETER GuidanceOnly
    Only validate .github/ guidance files.
.PARAMETER AutounattendOnly
    Only validate autounattend.xml.
.PARAMETER SkipAnalyzer
    Skip PSScriptAnalyzer checks.
.EXAMPLE
    .\Validate-Changes.ps1
.EXAMPLE
    .\Validate-Changes.ps1 -All
.EXAMPLE
    .\Validate-Changes.ps1 -PowerShellOnly
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$All,
    [switch]$PowerShellOnly,
    [switch]$GuidanceOnly,
    [switch]$AutounattendOnly,
    [switch]$SkipAnalyzer
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = $PWD
if ($PSScriptRoot -like "*.kilo/commands/*") {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$PSScriptAnalyzerSettings = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'
$autounattendPath = Join-Path $repoRoot 'Scripts/auto/autounattend.xml'

$hasErrors = $false
$results = @{}

function Test-PowerShellScripts {
    Write-Host '`n=== Validate PowerShell Scripts ===' -ForegroundColor Cyan

    $psFiles = @('Scripts/**/*.ps1', 'Scripts/**/*.psm1', 'Scripts/**/*.psd1', '*.ps1')
    $found = $false

    foreach ($pattern in $psFiles) {
        $files = Get-ChildItem -Path $repoRoot -Filter $pattern -Recurse -File -ErrorAction SilentlyContinue
        if ($files) {
            $found = $true
            foreach ($file in $files) {
                Write-Host "  [+] Analyzing: $($file.FullName)" -ForegroundColor Gray
                if (-not (Test-Path $PSScriptAnalyzerSettings)) {
                    Write-Warning "  PSScriptAnalyzerSettings.psd1 not found, using defaults"
                }
                $analyzerResult = pwsh -NoLogo -NoProfile -Command "
                    Import-Module PSScriptAnalyzer -ErrorAction Stop
                    `$result = Invoke-ScriptAnalyzer -Path '$($file.FullName)' -Settings '$PSScriptAnalyzerSettings' -Recurse:$false
                    if (`$result) { `$result | Format-Table -AutoSize | Out-String -Width 200 } else { 'PASS' }
                " 2>&1

                if ($analyzerResult -match 'PASS') {
                    Write-Host "    PASS" -ForegroundColor Green
                } else {
                    Write-Host "    FAIL:`n$analyzerResult" -ForegroundColor Red
                    $hasErrors = $true
                }
            }
        }
    }

    if (-not $found) {
        Write-Host '  No PowerShell files found to validate.' -ForegroundColor Yellow
    }
}

function Test-AutounattendXML {
    Write-Host '`n=== Validate autounattend.xml ===' -ForegroundColor Cyan

    if (-not (Test-Path $autounattendPath)) {
        Write-Host '  autounattend.xml not found — skipping.' -ForegroundColor Yellow
        return
    }

    try {
        [xml]$xml = Get-Content $autounattendPath -Raw
        Write-Host '  XML syntax: PASS' -ForegroundColor Green
        Write-Host "  Path: $autounattendPath" -ForegroundColor Gray

        # Check for ExtractScript blocks
        $extractScripts = $xml.SelectNodes('//script:ExtractScript', @{script='urn:schemas-microsoft-com:unattend'})
        if ($extractScripts) {
            Write-Host "  Embedded scripts (ExtractScript): $($extractScripts.Count)" -ForegroundColor Cyan
        }
    } catch {
        Write-Error "  XML validation FAILED: $_"
        $hasErrors = $true
    }
}

function Test-GuidanceFiles {
    Write-Host '`n=== Validate Guidance Files (.github/) ===' -ForegroundColor Cyan

    $guidancePaths = @('.github/instructions', '.github/skills', '.github/workflows')
    $hasFiles = $false

    foreach ($relPath in $guidancePaths) {
        $fullPath = Join-Path $repoRoot $relPath
        if (Test-Path $fullPath) {
            $hasFiles = $true
            Write-Host "  Checking $relPath..." -ForegroundColor Gray

            # Verify referenced paths/commands exist
            if ($relPath -eq '.github/workflows') {
                $workflows = Get-ChildItem $fullPath -Filter '*.yml'
                foreach ($wf in $workflows) {
                    Write-Host "    Workflow: $($wf.Name)" -ForegroundColor Gray
                    # Expand workflow references and verify
                    $content = Get-Content $wf.FullName -Raw
                    if ($content -match 'Scripts/.*\.ps1') {
                        # Extract script paths and verify
                        $matches = [regex]::Matches($content, 'Scripts/([\w\-/]+\.ps1)')
                        foreach ($m in $matches) {
                            $scriptPath = Join-Path $repoRoot $m.Value
                            if (-not (Test-Path $scriptPath)) {
                                Write-Error "    MISSING: $($m.Value) (referenced in $($wf.Name))"
                                $hasErrors = $true
                            }
                        }
                    }
                }
            }

            # Run ctxlint if available on .github/ tree
            $ctxlintResult = npm list -g @yawlabs/ctxlint 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host '  Running ctxlint...' -ForegroundColor Cyan
                $lintOutput = npx -y @yawlabs/ctxlint --depth 3 --mcp --strict .github 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Host '    ctxlint: PASS' -ForegroundColor Green
                } else {
                    Write-Host "    ctxlint FAILED:`n$lintOutput" -ForegroundColor Red
                    $hasErrors = $true
                }
            } else {
                Write-Host '  ctxlint not installed — skipping (npm i -g @yawlabs/ctxlint)' -ForegroundColor Yellow
            }
        }
    }

    if (-not $hasFiles) {
        Write-Host '  No guidance files found.' -ForegroundColor Yellow
    }
}

# Run requested validations
if ($All -or (-not ($PowerShellOnly -or $GuidanceOnly -or $AutounattendOnly))) {
    if (-not $SkipAnalyzer) { Test-PowerShellScripts }
    Test-AutounattendXML
    Test-GuidanceFiles
} else {
    if ($PowerShellOnly -and -not $SkipAnalyzer) { Test-PowerShellScripts }
    if ($GuidanceOnly) { Test-GuidanceFiles }
    if ($AutounattendOnly) { Test-AutounattendXML }
}

Write-Host '' -ForegroundColor Cyan
if ($hasErrors) {
    Write-Error 'Validation FAILED. Fix errors above before committing.'
    exit 1
} else {
    Write-Host 'All checks passed.' -ForegroundColor Green
    exit 0
}
