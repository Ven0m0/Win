#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Additional Safe Windows Maintenance Script
.DESCRIPTION
    Additional safe Windows maintenance tasks that can always be run:
    1. DISM Component Store Analysis and Cleanup
    2. System Cache Rebuilds (Font, Icon, Thumbnail)
    3. Store Cache Clear
    4. BITS Queue Cleanup
    5. Temp File Cleanup
    6. DNS Client Cache Clear
    7. System Restore Point Creation
.PARAMETER DryRun
    Show what would run without executing
.PARAMETER NoRestorePoint
    Don't create a system restore point
#>

[CmdletBinding()]
param(

    [switch]$DryRun,
    [switch]$NoRestorePoint
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

function Write-Header { param([string]$Text) Write-Host "`n$('='*60)" -ForegroundColor Cyan; Write-Host " $Text" -ForegroundColor Cyan; Write-Host "$('='*60)`n" -ForegroundColor Cyan }
function Write-Success { param([string]$Text) Write-Host "[OK] $Text" -ForegroundColor Green }
function Write-Fail { param([string]$Text) Write-Host "[FAIL] $Text" -ForegroundColor Red }
function Write-Warn { param([string]$Text) Write-Host "[WARN] $Text" -ForegroundColor Yellow }
function Write-Info { param([string]$Text) Write-Host "[INFO] $Text" -ForegroundColor White }

$Results = @{}
$StartTime = Get-Date

Write-Header "Additional Safe Windows Maintenance"

# 1. Create System Restore Point (optional but recommended)
if (-not $NoRestorePoint -and -not $DryRun) {
    Write-Progress "=== Creating System Restore Point ==="
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "Pre-Maintenance-$(Get-Date -Format 'yyyyMMdd')" -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Success "System restore point created"
        $Results['RestorePoint'] = 'CREATED'
    }
    catch {
        Write-Warn "Could not create restore point: $_"
        $Results['RestorePoint'] = 'FAILED'
    }
}
elseif ($DryRun) {
    Write-Warn "[DRY RUN] Would create system restore point"
    $Results['RestorePoint'] = 'DRY RUN'
}
else {
    Write-Info "Skipping restore point creation"
    $Results['RestorePoint'] = 'SKIPPED'
}

# 2. DISM Component Store Analysis
Write-Progress "=== DISM Component Store Analysis ==="
if (-not $DryRun) {
    $analysis = & DISM /Online /Cleanup-Image /AnalyzeComponentStore 2>&1
    Write-Info $analysis
    $Results['ComponentAnalysis'] = 'COMPLETE'
    
    # Cleanup if needed
    Write-Info "Running DISM StartComponentCleanup..."
    & DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1 | Out-Null
    Write-Success "Component cleanup initiated"
    $Results['ComponentCleanup'] = 'COMPLETE'
}
else {
    Write-Warn "[DRY RUN] Would analyze and cleanup component store"
    $Results['ComponentAnalysis'] = 'DRY RUN'
    $Results['ComponentCleanup'] = 'DRY RUN'
}

# 3. Clear Windows Store Cache
Write-Progress "=== Clearing Windows Store Cache ==="
if (-not $DryRun) {
    try {
        Start-Process -FilePath "wsreset.exe" -ArgumentList "-i" -NoNewWindow -Wait -ErrorAction Stop
        Write-Success "Windows Store cache cleared"
        $Results['StoreCache'] = 'CLEARED'
    }
    catch {
        Write-Warn "Store cache clear: $_"
        $Results['StoreCache'] = 'FAILED'
    }
}
else {
    Write-Warn "[DRY RUN] Would clear Windows Store cache"
    $Results['StoreCache'] = 'DRY RUN'
}

# 4. Clear BITS Queue
Write-Progress "=== BITS Queue Cleanup ==="
if (-not $DryRun) {
    try {
        Import-Module BitsTransfer -ErrorAction SilentlyContinue
        Get-BitsTransfer -AllUsers | Remove-BitsTransfer -ErrorAction SilentlyContinue
        Write-Success "BITS queue cleared"
        $Results['BITSClear'] = 'CLEARED'
    }
    catch {
        Write-Warn "BITS cleanup: $_"
        $Results['BITSClear'] = 'FAILED'
    }
}
else {
    Write-Warn "[DRY RUN] Would clear BITS queue"
    $Results['BITSClear'] = 'DRY RUN'
}

# 5. Rebuild Font Cache
Write-Progress "=== Rebuilding Font Cache ==="
if (-not $DryRun) {
    try {
        Stop-Service -Name FontCache -Force -ErrorAction SilentlyContinue
        $fontCachePath = "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\FontCache"
        if (Test-Path $fontCachePath) {
            Remove-Item -Path "$fontCachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
        Start-Service -Name FontCache -ErrorAction SilentlyContinue
        Write-Success "Font cache rebuilt"
        $Results['FontCache'] = 'REBUILT'
    }
    catch {
        Write-Warn "Font cache rebuild: $_"
        $Results['FontCache'] = 'FAILED'
    }
}
else {
    Write-Warn "[DRY RUN] Would rebuild font cache"
    $Results['FontCache'] = 'DRY RUN'
}

# 6. Clear Icon Cache
Write-Progress "=== Clearing Icon Cache ==="
if (-not $DryRun) {
    try {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        $iconCachePath = "$env:LOCALAPPDATA\IconCache.db"
        if (Test-Path $iconCachePath) {
            Remove-Item -Path $iconCachePath -Force -ErrorAction SilentlyContinue
        }
        $thumbCachePath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db"
        Remove-Item -Path $thumbCachePath -Force -ErrorAction SilentlyContinue
        Start-Process explorer
        Write-Success "Icon cache cleared"
        $Results['IconCache'] = 'CLEARED'
    }
    catch {
        Write-Warn "Icon cache clear: $_"
        $Results['IconCache'] = 'FAILED'
    }
}
else {
    Write-Warn "[DRY RUN] Would clear icon cache"
    $Results['IconCache'] = 'DRY RUN'
}

# 7. Clear Thumbnail Cache
Write-Progress "=== Clearing Thumbnail Cache ==="
if (-not $DryRun) {
    try {
        $thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
        Remove-Item -Path "$thumbPath\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
        Write-Success "Thumbnail cache cleared"
        $Results['ThumbCache'] = 'CLEARED'
    }
    catch {
        Write-Warn "Thumbnail cache clear: $_"
        $Results['ThumbCache'] = 'FAILED'
    }
}
else {
    Write-Warn "[DRY RUN] Would clear thumbnail cache"
    $Results['ThumbCache'] = 'DRY RUN'
}

# 8. Clear DNS Client Cache
Write-Progress "=== Clearing DNS Client Cache ==="
if (-not $DryRun) {
    try {
        Clear-DnsClientCache -ErrorAction Stop
        Write-Success "DNS client cache cleared"
        $Results['DNSCache'] = 'CLEARED'
    }
    catch {
        Write-Warn "DNS cache clear: $_"
        $Results['DNSCache'] = 'FAILED'
    }
}
else {
    Write-Warn "[DRY RUN] Would clear DNS client cache"
    $Results['DNSCache'] = 'DRY RUN'
}

# 9. Clear Temp Files
Write-Progress "=== Cleaning Temp Files ==="
if (-not $DryRun) {
    try {
        $tempPaths = @(
            $env:TEMP,
            "$env:SystemRoot\Temp",
            "$env:LOCALAPPDATA\Temp"
        )
        $cleared = 0
        foreach ($path in $tempPaths) {
            if (Test-Path $path) {
                Get-ChildItem -Path $path -Recurse -ErrorAction SilentlyContinue | 
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                $cleared++
            }
        }
        Write-Success "Temp files cleaned from $cleared locations"
        $Results['TempFiles'] = 'CLEARED'
    }
    catch {
        Write-Warn "Temp file cleanup: $_"
        $Results['TempFiles'] = 'FAILED'
    }
}
else {
    Write-Warn "[DRY RUN] Would clean temp files"
    $Results['TempFiles'] = 'DRY RUN'
}



# Summary
Write-Header "MAINTENANCE SUMMARY"

$endTime = Get-Date
$duration = $endTime - $StartTime

$successCount = 0
$failCount = 0
$skipCount = 0

foreach ($key in $Results.Keys | Sort-Object) {
    $status = $Results[$key]
    $color = 'White'
    
    if ($status -match 'CREATED|COMPLETE|CLEARED|RESET|REBUILT') {
        $color = 'Green'
        $successCount++
    }
    elseif ($status -match 'FAIL|ERROR') {
        $color = 'Red'
        $failCount++
    }
    elseif ($status -match 'SKIP|DRY RUN') {
        $color = 'Yellow'
        $skipCount++
    }
    
    Write-Host "  $($key.PadRight(20)) : " -NoNewline
    Write-Host $status -ForegroundColor $color
}

Write-Host "`n  Results: " -NoNewline
Write-Host "$successCount succeeded" -ForegroundColor Green -NoNewline
Write-Host ", " -NoNewline
Write-Host "$failCount failed" -ForegroundColor Red -NoNewline
Write-Host ", " -NoNewline
Write-Host "$skipCount skipped" -ForegroundColor Yellow

Write-Host "`n  Duration: $($duration.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
Write-Host "  End Time: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan

Write-Host "`n$('='*60)" -ForegroundColor Cyan
Write-Host "Done! All safe maintenance tasks completed." -ForegroundColor Green
Write-Host "`nNOTE: Some changes may require a restart to take full effect." -ForegroundColor Yellow
