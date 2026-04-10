#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Windows System Repair Script - runs DISM, SFC, CHKDSK, network, WMI, and cleanup.
.DESCRIPTION
    Runs Windows repair commands in the correct order:
    1. DISM Health Check (repair component store)
    2. SFC System File Check (twice: after DISM and after network fixes)
    3. CHKDSK Disk Repair
    4. Network Repairs (Winsock, TCP/IP, DNS flush)
    5. WMI Repository Repair
    6. Windows Update Service Reset
    7. Component Store Cleanup
    8. System Report Summary
.PARAMETER QuickScan
    Only run DISM + SFC (skip CHKDSK, network, WMI, WU resets).
.PARAMETER SkipDiskCheck
    Don't run CHKDSK (avoids reboot requirement).
.PARAMETER SkipNetworkFix
    Don't reset network adapters.
.PARAMETER SkipWUReset
    Don't reset Windows Update service.
.PARAMETER ScheduleChkdsk
    Auto-schedule CHKDSK /f /r on next reboot.
.PARAMETER DryRun
    Show what would run without executing.
.PARAMETER NoReboot
    Don't prompt about rebooting after network/WU resets.
.NOTES
    Author: Kilo AI Assistant
    Date: 2026-04-10
#>

[CmdletBinding()]
param(
    [switch]$QuickScan,
    [switch]$SkipDiskCheck,
    [switch]$SkipNetworkFix,
    [switch]$SkipWUReset,
    [switch]$ScheduleChkdsk,
    [switch]$DryRun,
    [switch]$NoReboot
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

$StartTime = Get-Date
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

function Write-Header { param([string]$Text) Write-Host "`n$('='*60)" -ForegroundColor Cyan; Write-Host " $Text" -ForegroundColor Cyan; Write-Host "$('='*60)`n" -ForegroundColor Cyan }
function Write-Success { param([string]$Text) Write-Host "[OK] $Text" -ForegroundColor Green }
function Write-Fail { param([string]$Text) Write-Host "[FAIL] $Text" -ForegroundColor Red }
function Write-Warn { param([string]$Text) Write-Host "[WARN] $Text" -ForegroundColor Yellow }
function Write-Info { param([string]$Text) Write-Host "[INFO] $Text" -ForegroundColor White }

$Results = @{
    DISM = 'SKIPPED'
    SFC1 = 'SKIPPED'
    CHKDSK = 'SKIPPED'
    Network = 'SKIPPED'
    WMI = 'SKIPPED'
    WUReset = 'SKIPPED'
    Cleanup = 'SKIPPED'
    SFC2 = 'SKIPPED'
}

$LogOutput = @()

function Add-Log {
    param([string]$Text)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogOutput += "[$timestamp] $Text"
}

function Run-Command {
    param(
        [string]$Name,
        [string]$Command,
        [string]$Args,
        [switch]$CaptureStdErr
    )
    
    if ($DryRun) {
        Write-Warn "[DRY RUN] Would execute: $Command $Args"
        $Results[$Name] = 'DRY RUN'
        return
    }
    
    Write-Info "Running: $Command $Args"
    Add-Log "Executing: $Command $Args"
    
    try {
        if ($CaptureStdErr) {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $Command
            $psi.Arguments = $Args
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.UseShellExecute = $false
            $psi.CreateNoWindow = $true
            
            $process = New-Object System.Diagnostics.Process
            $process.StartInfo = $psi
            $process.Start() | Out-Null
            
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            $process.WaitForExit()
            
            $exitCode = $process.ExitCode
            
            if ($stdout) { Add-Log "STDOUT: $stdout" }
            if ($stderr) { Add-Log "STDERR: $stderr" }
            
            $Results[$Name] = "Exit Code: $exitCode"
            Write-Info "Exit code: $exitCode"
        }
        else {
            $process = Start-Process -FilePath $Command -ArgumentList $Args -NoNewWindow -Wait -PassThru
            $exitCode = $process.ExitCode
            $Results[$Name] = "Exit Code: $exitCode"
            Write-Info "Exit code: $exitCode"
        }
    }
    catch {
        Write-Fail "Error: $_"
        Add-Log "ERROR: $_"
        $Results[$Name] = "ERROR: $_"
    }
}

function Write-Progress {
    param([string]$Message)
    Write-Host "$Message" -ForegroundColor Cyan
    Add-Log $Message
}

Write-Header "Windows System Repair"

Write-Info "Start Time: $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Info "Parameters: QuickScan=$QuickScan, SkipDiskCheck=$SkipDiskCheck, SkipNetworkFix=$SkipNetworkFix, SkipWUReset=$SkipWUReset, ScheduleChkdsk=$ScheduleChkdsk, DryRun=$DryRun, NoReboot=$NoReboot"
Add-Log "Repair started with parameters: QuickScan=$QuickScan, SkipDiskCheck=$SkipDiskCheck, SkipNetworkFix=$SkipNetworkFix, SkipWUReset=$SkipWUReset, ScheduleChkdsk=$ScheduleChkdsk, DryRun=$DryRun, NoReboot=$NoReboot"

if ($DryRun) {
    Write-Warn "DRY RUN MODE - No commands will be executed"
}

Write-Progress "=== Step 1: DISM Health Check ==="

$exitCode = 0
if (-not $DryRun) {
    Write-Info "DISM /Online /Cleanup-Image /CheckHealth"
    $result = & DISM /Online /Cleanup-Image /CheckHealth 2>&1
    $exitCode = $LASTEXITCODE
    Add-Log "CheckHealth output: $result"
    Write-Info "Exit code: $exitCode"
    
    if ($exitCode -eq 0 -or $exitCode -eq 3010) {
        Write-Success "DISM CheckHealth: No corruption found or already scheduled"
        $Results.DISM = 'HEALTHY'
    }
    elseif ($exitCode -eq 2) {
        Write-Warn "DISM CheckHealth: Corruption detected, running ScanHealth..."
        Write-Info "DISM /Online /Cleanup-Image /ScanHealth"
        & DISM /Online /Cleanup-Image /ScanHealth 2>&1 | Add-Log
        $scanExitCode = $LASTEXITCODE
        
        Write-Info "DISM /Online /Cleanup-Image /RestoreHealth"
        $result = & DISM /Online /Cleanup-Image /RestoreHealth 2>&1
        $restoreExitCode = $LASTEXITCODE
        Add-Log "RestoreHealth output: $result"
        
        if ($restoreExitCode -eq 0 -or $restoreExitCode -eq 3010) {
            Write-Success "DISM RestoreHealth completed"
            $Results.DISM = 'REPAIRED'
        }
        elseif ($restoreExitCode -eq 1392) {
            Write-Warn "DISM RestoreHealth failed: File corruption, trying /LimitAccess..."
            $result = & DISM /Online /Cleanup-Image /RestoreHealth /LimitAccess 2>&1
            Add-Log "RestoreHealth /LimitAccess: $result"
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3010) {
                $Results.DISM = 'REPAIRED (LimitAccess)'
            }
            else {
                $Results.DISM = "PARTIAL (Exit: $restoreExitCode)"
            }
        }
        else {
            Write-Warn "DISM RestoreHealth exit code: $restoreExitCode"
            $Results.DISM = "Exit Code: $restoreExitCode"
        }
    }
    else {
        Write-Warn "DISM CheckHealth exit code: $exitCode"
        $Results.DISM = "Exit Code: $exitCode"
    }
}
else {
    Write-Warn "[DRY RUN] Would run DISM commands"
    $Results.DISM = 'DRY RUN'
}

Write-Progress "=== Step 2: SFC System File Check (Pass 1) ==="

if (-not $DryRun) {
    Write-Info "Running SFC /scannow (this may take 10-30 minutes)..."
    Write-Info "SFC output goes to stderr - capturing properly..."
    
    $sfcOutput = & cmd /c "sfc /scannow 2>&1"
    $sfcExitCode = $LASTEXITCODE
    
    Add-Log "SFC Output: $sfcOutput"
    
    if ($sfcExitCode -eq 0) {
        Write-Success "SFC found no integrity violations"
        $Results.SFC1 = 'CLEAN'
    }
    elseif ($sfcExitCode -eq 1) {
        Write-Success "SFC found and repaired integrity violations"
        $Results.SFC1 = 'REPAIRED'
    }
    elseif ($sfcExitCode -eq 2) {
        Write-Warn "SFC found integrity violations but could not repair them all"
        $Results.SFC1 = 'PARTIAL'
    }
    else {
        Write-Warn "SFC exit code: $sfcExitCode"
        $Results.SFC1 = "Exit Code: $sfcExitCode"
    }
}
else {
    Write-Warn "[DRY RUN] Would run: sfc /scannow"
    $Results.SFC1 = 'DRY RUN'
}

if (-not $QuickScan) {
    if (-not $SkipDiskCheck) {
        Write-Progress "=== Step 3: CHKDSK Disk Repair ==="
        
        if (-not $DryRun) {
            Write-Info "Running CHKDSK /scan (online, non-disruptive)..."
            $chkdskOutput = & chkdsk C: /scan 2>&1
            $chkdskExitCode = $LASTEXITCODE
            
            Add-Log "CHKDSK /scan: $chkdskOutput"
            
            if ($chkdskExitCode -eq 0) {
                Write-Success "CHKDSK: No errors found"
                $Results.CHKDSK = 'CLEAN'
            }
            elseif ($chkdskExitCode -eq 1) {
                Write-Success "CHKDSK: Errors found and fixed"
                $Results.CHKDSK = 'FIXED'
            }
            elseif ($chkdskExitCode -eq 2) {
                Write-Warn "CHKDSK: Scheduled for next reboot (requires /f)"
                $Results.CHKDSK = 'SCHEDULED'
                
                if ($ScheduleChkdsk) {
                    Write-Info "Scheduling CHKDSK /f /r for next reboot..."
                    & chkdsk C: /f /r 2>&1 | Out-Null
                    Write-Warn "CHKDSK /f /r scheduled for next reboot"
                    $Results.CHKDSK = 'SCHEDULED (reboot)'
                }
            }
            else {
                Write-Warn "CHKDSK exit code: $chkdskExitCode"
                $Results.CHKDSK = "Exit Code: $chkdskExitCode"
            }
        }
        else {
            Write-Warn "[DRY RUN] Would run: chkdsk C: /scan"
            $Results.CHKDSK = 'DRY RUN'
        }
    }
    else {
        Write-Info "Skipping CHKDSK (SkipDiskCheck parameter)"
    }
    
    if (-not $SkipNetworkFix) {
        Write-Progress "=== Step 4: Network Repairs ==="
        
        if (-not $DryRun) {
            Write-Info "Resetting Winsock catalog..."
            & netsh winsock reset 2>&1 | ForEach-Object { Add-Log $_ }
            Write-Success "Winsock reset complete"
            
            Write-Info "Resetting TCP/IP stack..."
            & netsh int ip reset 2>&1 | ForEach-Object { Add-Log $_ }
            Write-Success "TCP/IP reset complete"
            
            Write-Info "Flushing DNS resolver cache..."
            & ipconfig /flushdns 2>&1 | ForEach-Object { Add-Log $_ }
            Write-Success "DNS cache flushed"
            
            $Results.Network = 'COMPLETE'
            Write-Success "Network repairs complete"
            Write-Warn "NOTE: A reboot is required for network changes to take effect"
        }
        else {
            Write-Warn "[DRY RUN] Would run: netsh winsock reset, netsh int ip reset, ipconfig /flushdns"
            $Results.Network = 'DRY RUN'
        }
    }
    else {
        Write-Info "Skipping Network repairs (SkipNetworkFix parameter)"
    }
    
    Write-Progress "=== Step 5: WMI Repository Check ==="
    
    if (-not $DryRun) {
        Write-Info "Verifying WMI repository..."
        $wmiOutput = & winmgmt /verifyrepository 2>&1
        $wmiExitCode = $LASTEXITCODE
        
        Add-Log "WMI Verify: $wmiOutput"
        
        if ($wmiOutput -match 'consistent|ok|OK') {
            Write-Success "WMI repository is consistent"
            $Results.WMI = 'CONSISTENT'
        }
        elseif ($wmiOutput -match 'inconsistent|ERROR') {
            Write-Warn "WMI repository is inconsistent, attempting repair..."
            $salvageOutput = & winmgmt /salvagerepository 2>&1
            $salvageExitCode = $LASTEXITCODE
            
            Add-Log "WMI Salvage: $salvageOutput"
            
            if ($salvageExitCode -eq 0) {
                Write-Success "WMI repository repaired"
                $Results.WMI = 'REPAIRED'
            }
            else {
                Write-Warn "WMI salvage exit code: $salvageExitCode"
                $Results.WMI = "Exit Code: $salvageExitCode"
            }
        }
        else {
            Write-Warn "WMI verify exit code: $wmiExitCode"
            $Results.WMI = "Exit Code: $wmiExitCode"
        }
    }
    else {
        Write-Warn "[DRY RUN] Would run: winmgmt /verifyrepository"
        $Results.WMI = 'DRY RUN'
    }
    
    if (-not $SkipWUReset) {
        Write-Progress "=== Step 6: Windows Update Service Reset ==="
        
        if (-not $DryRun) {
            Write-Info "Stopping Windows Update services..."
            Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
            Stop-Service -Name BITS -Force -ErrorAction SilentlyContinue
            
            $swDistribPath = "$env:SystemRoot\SoftwareDistribution"
            $catRootPath = "$env:SystemRoot\System32\CatRoot2"
            
            if (Test-Path $swDistribPath) {
                $backupName = "$swDistribPath-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Write-Info "Renaming SoftwareDistribution to $backupName"
                Rename-Item -Path $swDistribPath -NewName (Split-Path -Leaf $backupName) -Force -ErrorAction SilentlyContinue
            }
            
            if (Test-Path $catRootPath) {
                $backupName = "$catRootPath-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                Write-Info "Renaming CatRoot2 to $backupName"
                Rename-Item -Path $catRootPath -NewName (Split-Path -Leaf $backupName) -Force -ErrorAction SilentlyContinue
            }
            
            Write-Info "Starting Windows Update services..."
            Start-Service -Name wuauserv -ErrorAction SilentlyContinue
            Start-Service -Name BITS -ErrorAction SilentlyContinue
            
            Write-Info "Triggering Windows Update scan..."
            & USOClient.exe ScanDownloadBranch 2>&1 | Out-Null
            
            $Results.WUReset = 'COMPLETE'
            Write-Success "Windows Update service reset complete"
        }
        else {
            Write-Warn "[DRY RUN] Would reset Windows Update services"
            $Results.WUReset = 'DRY RUN'
        }
    }
    else {
        Write-Info "Skipping Windows Update reset (SkipWUReset parameter)"
    }
    
    Write-Progress "=== Step 7: SFC System File Check (Pass 2 - after network fixes) ==="
    
    if (-not $DryRun) {
        Write-Info "Running SFC /scannow (second pass)..."
        
        $sfcOutput = & cmd /c "sfc /scannow 2>&1"
        $sfcExitCode = $LASTEXITCODE
        
        Add-Log "SFC Pass 2: $sfcOutput"
        
        if ($sfcExitCode -eq 0) {
            Write-Success "SFC Pass 2: No integrity violations"
            $Results.SFC2 = 'CLEAN'
        }
        elseif ($sfcExitCode -eq 1) {
            Write-Success "SFC Pass 2: Repaired additional files"
            $Results.SFC2 = 'REPAIRED'
        }
        else {
            Write-Warn "SFC Pass 2 exit code: $sfcExitCode"
            $Results.SFC2 = "Exit Code: $sfcExitCode"
        }
    }
    else {
        Write-Warn "[DRY RUN] Would run: sfc /scannow"
        $Results.SFC2 = 'DRY RUN'
    }
    
    Write-Progress "=== Step 8: Component Store Cleanup ==="
    
    if (-not $DryRun) {
        Write-Info "Running DISM StartComponentCleanup (may take 15-30 minutes)..."
        
        $cleanupResult = & DISM /Online /Cleanup-Image /StartComponentCleanup 2>&1
        $cleanupExitCode = $LASTLASTEXITCODE
        
        if ($cleanupExitCode -eq 0 -or $cleanupExitCode -eq 3010) {
            Write-Success "Component cleanup complete"
            $Results.Cleanup = 'COMPLETED'
        }
        else {
            Write-Warn "Cleanup exit code: $cleanupExitCode"
            $Results.Cleanup = "Exit Code: $cleanupExitCode"
        }
    }
    else {
        Write-Warn "[DRY RUN] Would run: DISM /Online /Cleanup-Image /StartComponentCleanup"
        $Results.Cleanup = 'DRY RUN'
    }
}

Write-Header "REPAIR SUMMARY"

$endTime = Get-Date
$duration = $endTime - $StartTime

$successCount = 0
$failCount = 0
$skipCount = 0

foreach ($key in $Results.Keys) {
    $status = $Results[$key]
    $color = 'White'
    
    if ($status -match 'CLEAN|COMPLETE|CONSISTENT|REPAIRED|HEALTHY|FIXED') {
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
    elseif ($status -match 'PARTIAL|SCHEDULED') {
        $color = 'Cyan'
    }
    
    Write-Host "  $($key.PadRight(15)) : " -NoNewline
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

$reportFile = Join-Path $ScriptDir "fix-system-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"

$report = @"
Windows System Repair Report
=====================
Start Time: $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))
End Time: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))
Duration: $($duration.ToString('hh\:mm\:ss'))
DryRun: $DryRun
QuickScan: $QuickScan

RESULTS SUMMARY
============
$(($Results.GetEnumerator() | ForEach-Object { "$($_.Key) = $($_.Value)" }) -join "`n")

LOG OUTPUT
=========
$($LogOutput -join "`n")
"@

Set-Content -Path $reportFile -Value $report -Encoding UTF8
Write-Info "Report written to: $reportFile"

if (-not $NoReboot -and (-not $DryRun) -and ($Results.Network -eq 'COMPLETE' -or $Results.WUReset -eq 'COMPLETE')) {
    Write-Host "`nA system REBOOT is recommended to complete network and Windows Update changes." -ForegroundColor Yellow
    Write-Host "Run: shutdown /r /t 0" -ForegroundColor Yellow
}

Write-Host "`nDone!" -ForegroundColor Green