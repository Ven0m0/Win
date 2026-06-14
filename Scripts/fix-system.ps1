#Requires -Version 5.1
#Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

. "$PSScriptRoot\Common.ps1"

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
.PARAMETER NoReport
    Skip writing report file.
#>
function Start-SystemFix {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [switch]$QuickScan,
    [switch]$SkipDiskCheck,
    [switch]$SkipNetworkFix,
    [switch]$SkipWUReset,
    [switch]$ScheduleChkdsk,
    [switch]$DryRun,
    [switch]$NoReboot,
    [switch]$NoReport
  )

  Clear-Log
  $results = @{
    DISM    = 'SKIPPED'
    SFC1    = 'SKIPPED'
    CHKDSK  = 'SKIPPED'
    Network = 'SKIPPED'
    WMI     = 'SKIPPED'
    WUReset = 'SKIPPED'
    Cleanup = 'SKIPPED'
    SFC2    = 'SKIPPED'
  }

  $startTime = Get-Date

  Write-Header "Windows System Repair"
  Write-Info "Start Time: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))"
  Write-Info "Parameters: QuickScan=$QuickScan, SkipDiskCheck=$SkipDiskCheck, SkipNetworkFix=$SkipNetworkFix, SkipWUReset=$SkipWUReset"
  if ($DryRun) {
    Write-Warn "DRY RUN MODE - No commands will be executed"
  }
  Add-Log "Repair started: QuickScan=$QuickScan, SkipDiskCheck=$SkipDiskCheck, SkipNetworkFix=$SkipNetworkFix, SkipWUReset=$SkipWUReset"

  # Step 1: DISM Health Check
  Write-Info "=== Step 1: DISM Health Check ==="

  if ($DryRun) {
    $results.DISM = 'DRY RUN'
    Write-Warn "[DRY RUN] Would run DISM commands"
  }
  else {
    Write-Info "DISM /Online /Cleanup-Image /CheckHealth"
    $dismOutput = & DISM.exe /Online /Cleanup-Image /CheckHealth 2>&1
    $exitCode = $LASTEXITCODE
    Add-Log "CheckHealth output: $dismOutput"
    Write-Info "Exit code: $exitCode"

    if ($exitCode -eq 0 -or $exitCode -eq 3010) {
      Write-Success "DISM CheckHealth: No corruption found or already scheduled"
      $results.DISM = 'HEALTHY'
    }
    elseif ($exitCode -eq 2) {
      Write-Warn "DISM CheckHealth: Corruption detected, running ScanHealth..."
      Write-Info "DISM /Online /Cleanup-Image /ScanHealth"
      $null = & DISM.exe /Online /Cleanup-Image /ScanHealth 2>&1

      Write-Info "DISM /Online /Cleanup-Image /RestoreHealth"
      $restoreOutput = & DISM.exe /Online /Cleanup-Image /RestoreHealth 2>&1
      $restoreExitCode = $LASTEXITCODE
      Add-Log "RestoreHealth output: $restoreOutput"

      if ($restoreExitCode -eq 0 -or $restoreExitCode -eq 3010) {
        Write-Success "DISM RestoreHealth completed"
        $results.DISM = 'REPAIRED'
      }
      elseif ($restoreExitCode -eq 1392) {
        Write-Warn "DISM RestoreHealth failed: File corruption, trying /LimitAccess..."
        $limitOutput = & DISM.exe /Online /Cleanup-Image /RestoreHealth /LimitAccess 2>&1
        Add-Log "RestoreHealth /LimitAccess: $limitOutput"
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3010) {
          $results.DISM = 'REPAIRED (LimitAccess)'
        }
        else {
          $results.DISM = "PARTIAL (Exit: $restoreExitCode)"
        }
      }
      else {
        Write-Warn "DISM RestoreHealth exit code: $restoreExitCode"
        $results.DISM = "Exit Code: $restoreExitCode"
      }
    }
    else {
      Write-Warn "DISM CheckHealth exit code: $exitCode"
      $results.DISM = "Exit Code: $exitCode"
    }
  }

  # Step 2: SFC System File Check (Pass 1)
  Write-Info "=== Step 2: SFC System File Check (Pass 1) ==="

  if ($DryRun) {
    $results.SFC1 = 'DRY RUN'
    Write-Warn "[DRY RUN] Would run: sfc /scannow"
  }
  else {
    Write-Info "Running SFC /scannow (this may take 10-30 minutes)..."
    $sfcOutput = & cmd.exe /c "sfc /scannow 2>&1"
    $sfcExitCode = $LASTEXITCODE
    Add-Log "SFC Output: $sfcOutput"

    if ($sfcExitCode -eq 0) {
      Write-Success "SFC found no integrity violations"
      $results.SFC1 = 'CLEAN'
    }
    elseif ($sfcExitCode -eq 1) {
      Write-Success "SFC found and repaired integrity violations"
      $results.SFC1 = 'REPAIRED'
    }
    elseif ($sfcExitCode -eq 2) {
      Write-Warn "SFC found integrity violations but could not repair them all"
      $results.SFC1 = 'PARTIAL'
    }
    else {
      Write-Warn "SFC exit code: $sfcExitCode"
      $results.SFC1 = "Exit Code: $sfcExitCode"
    }
  }

  if (-not $QuickScan) {
    if (-not $SkipDiskCheck) {
      # Step 3: CHKDSK Disk Repair
      Write-Info "=== Step 3: CHKDSK Disk Repair ==="

      if ($DryRun) {
        $results.CHKDSK = 'DRY RUN'
        Write-Warn "[DRY RUN] Would run: chkdsk C: /scan"
      }
      else {
        Write-Info "Running CHKDSK /scan (online, non-disruptive)..."
        $chkdskOutput = & chkdsk.exe C: /scan 2>&1
        $chkdskExitCode = $LASTEXITCODE
        Add-Log "CHKDSK /scan: $chkdskOutput"

        if ($chkdskExitCode -eq 0) {
          Write-Success "CHKDSK: No errors found"
          $results.CHKDSK = 'CLEAN'
        }
        elseif ($chkdskExitCode -eq 1) {
          Write-Success "CHKDSK: Errors found and fixed"
          $results.CHKDSK = 'FIXED'
        }
        elseif ($chkdskExitCode -eq 2) {
          Write-Warn "CHKDSK: Scheduled for next reboot (requires /f)"
          $results.CHKDSK = 'SCHEDULED'

          if ($ScheduleChkdsk) {
            Write-Info "Scheduling CHKDSK /f /r for next reboot..."
            $null = & chkdsk.exe C: /f /r 2>&1
            Write-Warn "CHKDSK /f /r scheduled for next reboot"
            $results.CHKDSK = 'SCHEDULED (reboot)'
          }
        }
        else {
          Write-Warn "CHKDSK exit code: $chkdskExitCode"
          $results.CHKDSK = "Exit Code: $chkdskExitCode"
        }
      }
    }
    else {
      Write-Info "Skipping CHKDSK (SkipDiskCheck parameter)"
    }

    if (-not $SkipNetworkFix) {
      # Step 4: Network Repairs
      Write-Info "=== Step 4: Network Repairs ==="

      if ($DryRun) {
        $results.Network = 'DRY RUN'
        Write-Warn "[DRY RUN] Would run: netsh winsock reset, netsh int ip reset, ipconfig /flushdns"
      }
      else {
        Invoke-Operation -Name 'WinsockReset' -Results $results -Command 'netsh' -ArgumentList 'winsock reset'
        Invoke-Operation -Name 'TCPIPReset' -Results $results -Command 'netsh' -ArgumentList 'int ip reset'
        Invoke-Operation -Name 'DNSFlush' -Results $results -Command 'ipconfig' -ArgumentList '/flushdns'
        Write-Success "Network repairs complete"
        $results.Network = 'COMPLETE'
        Write-Warn "NOTE: A reboot is required for network changes to take effect"
      }
    }
    else {
      Write-Info "Skipping Network repairs (SkipNetworkFix parameter)"
    }

    # Step 5: WMI Repository Check
    Write-Info "=== Step 5: WMI Repository Check ==="

    if ($DryRun) {
      $results.WMI = 'DRY RUN'
      Write-Warn "[DRY RUN] Would run: winmgmt /verifyrepository"
    }
    else {
      Write-Info "Verifying WMI repository..."
      $wmiOutput = & winmgmt.exe /verifyrepository 2>&1
      $wmiExitCode = $LASTEXITCODE
      Add-Log "WMI Verify: $wmiOutput"

      if ($wmiOutput -match 'consistent|ok|OK') {
        Write-Success "WMI repository is consistent"
        $results.WMI = 'CONSISTENT'
      }
      elseif ($wmiOutput -match 'inconsistent|ERROR') {
        Write-Warn "WMI repository is inconsistent, attempting repair..."
        $salvageOutput = & winmgmt.exe /salvagerepository 2>&1
        $salvageExitCode = $LASTEXITCODE
        Add-Log "WMI Salvage: $salvageOutput"

        if ($salvageExitCode -eq 0) {
          Write-Success "WMI repository repaired"
          $results.WMI = 'REPAIRED'
        }
        else {
          Write-Warn "WMI salvage exit code: $salvageExitCode"
          $results.WMI = "Exit Code: $salvageExitCode"
        }
      }
      else {
        Write-Warn "WMI verify exit code: $wmiExitCode"
        $results.WMI = "Exit Code: $wmiExitCode"
      }
    }

    if (-not $SkipWUReset) {
      # Step 6: Windows Update Service Reset
      Write-Info "=== Step 6: Windows Update Service Reset ==="

      if ($DryRun) {
        $results.WUReset = 'DRY RUN'
        Write-Warn "[DRY RUN] Would reset Windows Update services"
      }
      else {
        Invoke-ServiceOperation -Name 'wuauserv' -Action {
          Invoke-ServiceOperation -Name 'BITS' -Action {
            $swDistribPath = "$env:SystemRoot\SoftwareDistribution"
            $catRootPath = "$env:SystemRoot\System32\CatRoot2"

            if (Test-Path -Path $swDistribPath) {
              $backupName = "SoftwareDistribution-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
              Write-Info "Renaming SoftwareDistribution to $backupName"
              Rename-Item -Path $swDistribPath -NewName $backupName -Force -ErrorAction SilentlyContinue
            }

            if (Test-Path -Path $catRootPath) {
              $backupName = "CatRoot2-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
              Write-Info "Renaming CatRoot2 to $backupName"
              Rename-Item -Path $catRootPath -NewName $backupName -Force -ErrorAction SilentlyContinue
            }

            Write-Info "Triggering Windows Update scan..."
            $null = & USOClient.exe ScanDownloadBranch 2>&1
          }
        }
        $results.WUReset = 'COMPLETE'
        Write-Success "Windows Update service reset complete"
      }
    }
    else {
      Write-Info "Skipping Windows Update reset (SkipWUReset parameter)"
    }

    # Step 7: SFC System File Check (Pass 2 - after network fixes)
    Write-Info "=== Step 7: SFC System File Check (Pass 2 - after network fixes) ==="

    if ($DryRun) {
      $results.SFC2 = 'DRY RUN'
      Write-Warn "[DRY RUN] Would run: sfc /scannow"
    }
    else {
      Write-Info "Running SFC /scannow (second pass)..."
      $sfcOutput = & cmd.exe /c "sfc /scannow 2>&1"
      $sfcExitCode = $LASTEXITCODE
      Add-Log "SFC Pass 2: $sfcOutput"

      if ($sfcExitCode -eq 0) {
        Write-Success "SFC Pass 2: No integrity violations"
        $results.SFC2 = 'CLEAN'
      }
      elseif ($sfcExitCode -eq 1) {
        Write-Success "SFC Pass 2: Repaired additional files"
        $results.SFC2 = 'REPAIRED'
      }
      else {
        Write-Warn "SFC Pass 2 exit code: $sfcExitCode"
        $results.SFC2 = "Exit Code: $sfcExitCode"
      }
    }

    # Step 8: Component Store Cleanup
    Write-Info "=== Step 8: Component Store Cleanup ==="

    if ($DryRun) {
      $results.Cleanup = 'DRY RUN'
      Write-Warn "[DRY RUN] Would run: DISM /Online /Cleanup-Image /StartComponentCleanup"
    }
    else {
      Write-Info "Running DISM StartComponentCleanup (may take 15-30 minutes)..."
      $null = & DISM.exe /Online /Cleanup-Image /StartComponentCleanup 2>&1
      $cleanupExitCode = $LASTEXITCODE

      if ($cleanupExitCode -eq 0 -or $cleanupExitCode -eq 3010) {
        Write-Success "Component cleanup complete"
        $results.Cleanup = 'COMPLETED'
      }
      else {
        Write-Warn "Cleanup exit code: $cleanupExitCode"
        $results.Cleanup = "Exit Code: $cleanupExitCode"
      }
    }
  }

  # Display summary
  Show-Summary -Results $results -StartTime $startTime

  # Write report file
  if (-not $NoReport -and -not $DryRun) {
    $reportFile = Join-Path -Path $PSScriptRoot -ChildPath "fix-system-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $durationInfo = Measure-Execution -StartTime $startTime
    $resultLines = $results.GetEnumerator() | Sort-Object -Property Name | ForEach-Object { "$($_.Key) = $($_.Value)" }

    $report = @"
Windows System Repair Report
=====================
Start Time: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))
End Time: $($durationInfo.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))
Duration: $($durationInfo.Duration)
DryRun: $DryRun
QuickScan: $QuickScan

RESULTS SUMMARY
==========
$($resultLines -join "`n")

LOG OUTPUT
========
$((Get-Log) -join "`n")
"@

    Set-Content -Path $reportFile -Value $report -Encoding UTF8
    Write-Info "Report written to: $reportFile"
  }

  if (-not $NoReboot -and (-not $DryRun) -and ($results.Network -eq 'COMPLETE' -or $results.WUReset -eq 'COMPLETE')) {
    Write-Warn "A system REBOOT is recommended to complete network and Windows Update changes."
    Write-Warn "Run: shutdown /r /t 0"
  }

  Write-Success "Done!"
}

if ($MyInvocation.InvocationName -ne '.') {
  Start-SystemFix @PSBoundParameters
}
