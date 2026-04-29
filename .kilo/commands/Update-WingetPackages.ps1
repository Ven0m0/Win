#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Update all winget-installed packages to latest versions.
.DESCRIPTION
    Bulk upgrade all packages installed via winget. Useful for keeping
    development tools and applications current. Excludes optional features
    and shows a summary of available upgrades before applying.
.PARAMETER WhatIf
    Show which packages would be upgraded without making changes.
.PARAMETER IncludeMicrosoftStore
    Also update Microsoft Store apps (slow, may requireStore sign-in).
.PARAMETER Exclude
    Array of package IDs to exclude from updates (e.g., @('Git.Git', 'Microsoft.PowerShell')).
.PARAMETER DryRunOnly
    List upgradable packages but do not install anything.
.EXAMPLE
    .\Update-WingetPackages.ps1
.EXAMPLE
    .\Update-WingetPackages.ps1 -WhatIf
.EXAMPLE
    .\Update-WingetPackages.ps1 -Exclude 'Git.Git','Microsoft.WindowsTerminal'
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$WhatIf,
    [switch]$IncludeMicrosoftStore,
    [string[]]$Exclude = @(),
    [switch]$DryRunOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Check winget exists
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "winget is not installed or not in PATH. Install from https://aka.ms/getwinget"
    exit 1
}

Write-Host '=== Winget Package Update ===' -ForegroundColor Cyan

# Get list of installed packages
Write-Host '  Fetching installed packages...' -ForegroundColor Gray
$installed = winget list --source winget 2>&1 | Out-String
$upgradable = winget upgrade --source winget 2>&1 | Out-String

# Parse upgradable output
$upgradeLines = $upgradable -split "`n" | Where-Object { $_ -match '^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)' }
$toUpdate = @()

foreach ($line in $upgradeLines) {
    if ($line -match '^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s*$') {
        $pkgId = $matches[1]
        $current = $matches[2]
        $available = $matches[3]
        $source = $matches[4]

        # Skip excluded packages
        if ($Exclude -contains $pkgId) {
            Write-Host "  [EXCLUDE] $pkgId ($current → $available)" -ForegroundColor Yellow
            continue
        }

        # Skip Microsoft Store if not requested
        if ($source -eq 'msstore' -and -not $IncludeMicrosoftStore) {
            Write-Host "  [SKIP-MS] $pkgId ($current → $available) — use -IncludeMicrosoftStore to update" -ForegroundColor Gray
            continue
        }

        $toUpdate += [PSCustomObject]@{
            Id = $pkgId
            Current = $current
            Available = $available
            Source = $source
        }
    }
}

Write-Host ""
Write-Host "  Upgradable packages: $($toUpdate.Count)" -ForegroundColor Cyan

if ($toUpdate.Count -eq 0) {
    Write-Host '  All packages are up-to-date.' -ForegroundColor Green
    exit 0
}

foreach ($pkg in $toUpdate) {
    Write-Host "  [+] $($pkg.Id) ($($pkg.Current) → $($pkg.Available)) [$($pkg.Source)]" -ForegroundColor Cyan
}

Write-Host ''

if ($DryRunOnly) {
    Write-Host '  Dry-run mode — no changes made.' -ForegroundColor Yellow
    exit 0
}

if ($WhatIf) {
    Write-Host '  WhatIf enabled — no changes will be made.' -ForegroundColor Yellow
    foreach ($pkg in $toUpdate) {
        Write-Host "  What if: winget upgrade --id $($pkg.Id) --source $($pkg.Source) --accept-source-agreements --accept-package-agreements"
    }
    exit 0
}

# Perform upgrades
$successCount = 0
$failCount = 0

foreach ($pkg in $toUpdate) {
    $action = "Upgrade $($pkg.Id) to $($pkg.Available)"
    if ($PSCmdlet.ShouldProcess($pkg.Id, 'winget upgrade')) {
        Write-Host "  [RUNNING] $action" -ForegroundColor Cyan
        try {
            winget upgrade --id $pkg.Id --source $pkg.Source --silent --accept-source-agreements --accept-package-agreements --disable-logging | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  [OK]      $action" -ForegroundColor Green
                $successCount++
            } else {
                Write-Host "  [FAIL]    $action (exit code $LASTEXITCODE)" -ForegroundColor Red
                $failCount++
            }
        } catch {
            Write-Host "  [ERROR]   $action — $_" -ForegroundColor Red
            $failCount++
        }
    }
}

Write-Host ''
Write-Host "  Summary: $successCount upgraded, $failCount failed" -ForegroundColor $(if ($failCount -eq 0) { 'Green' } else { 'Red' })
exit ($failCount -eq 0 ? 0 : 1)
