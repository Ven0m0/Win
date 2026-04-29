#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Debloat Windows: remove built-in apps, disable services/tasks, clean features.
.DESCRIPTION
    Safe debloat wrapper that calls Scripts/debloat-windows.ps1 with optional
    preset profiles. Can target apps, services, scheduled tasks, and Windows features.
    Always creates a restore point before proceeding (unless -NoRestorePoint).
    Supports dry-run (-WhatIf) and selective debloat modes.
.PARAMETER Preset
    Debloat preset to use: 'Minimal' (keep essentials), 'Moderate' (remove most bloat), 'Aggressive' (also disable optional services).
.PARAMETER AppsOnly
    Remove only built-in Appx packages (no services/tasks/features).
.PARAMETER ServicesOnly
    Disable only unnecessary services.
.PARAMETER TasksOnly
    Disable only scheduled tasks.
.PARAMETER FeaturesOnly
    Remove only Windows optional features.
.PARAMETER NoRestorePoint
    Skip creating a system restore point before debloating.
.PARAMETER Undo
    Attempt to reverse debloat operations (reinstall removed apps, re-enable services/tasks).
    WARNING: May not restore all changes perfectly; check system state after.
.PARAMETER GenerateReport
    Export a JSON report of all changes made for later rollback.
.PARAMETER ReportPath
    Output path for the debloat report. Default: ./debloat-report.json.
.EXAMPLE
    .\Debloat-Windows.ps1 -Preset Moderate
.EXAMPLE
    .\Debloat-Windows.ps1 -AppsOnly -WhatIf
.EXAMPLE
    .\Debloat-Windows.ps1 -Undo -GenerateReport
#>
[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = 'Preset')]
param(
    [Parameter(Position = 0, ParameterSetName = 'Preset')]
    [ValidateSet('Minimal', 'Moderate', 'Aggressive')]
    [string]$Preset = 'Moderate',

    [Parameter(ParameterSetName = 'Apps')]
    [switch]$AppsOnly,

    [Parameter(ParameterSetName = 'Services')]
    [switch]$ServicesOnly,

    [Parameter(ParameterSetName = 'Tasks')]
    [switch]$TasksOnly,

    [Parameter(ParameterSetName = 'Features')]
    [switch]$FeaturesOnly,

    [switch]$NoRestorePoint,
    [switch]$Undo,
    [switch]$GenerateReport,
    [string]$ReportPath = './debloat-report.json'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = $PWD
if ($PSScriptRoot -like "*.kilo/commands/*") {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}

$debloatScript = Join-Path $repoRoot 'Scripts/debloat-windows.ps1'

if (-not (Test-Path $debloatScript)) {
    Write-Error "debloat-windows.ps1 not found at $debloatScript"
    exit 1
}

# Elevation check
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Write-Error "Administrator privileges required for debloating. Relaunch as admin."
    exit 1
}

Write-Host '=== Windows Debloat ===' -ForegroundColor Cyan
Write-Host "  Script: $debloatScript"

# Restore point
if (-not $NoRestorePoint -and -not $Undo) {
    $rpDesc = "Before debloat ($Preset preset) - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    Write-Host "  Creating restore point: $rpDesc" -ForegroundColor Cyan
    try {
        Checkpoint-Computer -Description $rpDesc -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Host '  Restore point created.' -ForegroundColor Green
    } catch {
        Write-Warning "  Failed to create restore point: $_"
    }
}

# Build arguments
$argsList = @()
if ($Undo) { $argsList += '-Undo' }
if ($AppsOnly) { $argsList += '-AppsOnly' }
if ($ServicesOnly) { $argsList += '-ServicesOnly' }
if ($TasksOnly) { $argsList += '-TasksOnly' }
if ($FeaturesOnly) { $argsList += '-FeaturesOnly' }
if ($Preset -and $PSCmdlet.ParameterSetName -eq 'Preset') {
    $argsList += "-Preset"; $argsList += $Preset
}
if ($GenerateReport) {
    $argsList += '-GenerateReport'
    $argsList += '-ReportPath'; $argsList += $ReportPath
}
if ($WhatIfPreference) {
    $argsList += '-WhatIf'
}

Write-Host "  Mode: $($PSCmdlet.ParameterSetName)" -ForegroundColor Gray
if ($Undo) { Write-Host '  Undoing previous debloat...' -ForegroundColor Yellow }

# Execute
$startTime = Get-Date
Write-Host ''

if ($PSCmdlet.ShouldProcess('debloat-windows.ps1', 'Execute debloat operations')) {
    pwsh -NoLogo -NoProfile -File $debloatScript @argsList
    $exitCode = $LASTEXITCODE
}

$duration = (Get-Date) - $startTime
Write-Host ''
Write-Host "  Time: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray

if ($exitCode -eq 0) {
    Write-Host 'Débloat completed successfully.' -ForegroundColor Green
    exit 0
} else {
    Write-Error "Debloat failed with exit code $exitCode"
    exit $exitCode
}
