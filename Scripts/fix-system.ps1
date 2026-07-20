#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Unified Windows repair: system integrity (DISM/SFC/CHKDSK/network/WMI) and Windows Update component reset.
.DESCRIPTION
    Consolidates repair and diagnostic tools behind a single -Action switch:
      System         - DISM, SFC (x2), CHKDSK, network, WMI, WU service reset, component cleanup (default)
      WindowsUpdate  - reset WU services/caches/catroot2, re-register DLLs
      Health         - read-only diagnostics: disk health, pending updates, service anomalies,
                       large temp dirs, startup items (no repairs; not included in All)
      All            - run System, then WindowsUpdate
      Restart        - restart the system now
      RestartToBios  - restart the system directly into firmware/BIOS setup
.PARAMETER Action
    Which repair to run. Defaults to System.
.PARAMETER QuickScan
    System action: only run DISM + SFC (skip CHKDSK, network, WMI, WU resets).
.PARAMETER SkipDiskCheck
    System action: don't run CHKDSK (avoids reboot requirement).
.PARAMETER SkipNetworkFix
    System action: don't reset network adapters.
.PARAMETER SkipWUReset
    System action: don't reset Windows Update service.
.PARAMETER ScheduleChkdsk
    System action: auto-schedule CHKDSK /f /r on next reboot.
.PARAMETER DryRun
    System action: show what would run without executing.
.PARAMETER NoReboot
    System action: don't prompt about rebooting after network/WU resets.
.PARAMETER NoReport
    System action: skip writing report file.
.EXAMPLE
    .\fix-system.ps1 -Action System -DryRun
.EXAMPLE
    .\fix-system.ps1 -Action WindowsUpdate -WhatIf
.EXAMPLE
    .\fix-system.ps1 -Action All
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [ValidateSet('System', 'WindowsUpdate', 'Health', 'All', 'Restart', 'RestartToBios')]
  [string]$Action = 'System',
  [switch]$QuickScan,
  [switch]$SkipDiskCheck,
  [switch]$SkipNetworkFix,
  [switch]$SkipWUReset,
  [switch]$ScheduleChkdsk,
  [switch]$DryRun,
  [switch]$NoReboot,
  [switch]$NoReport
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

. "$PSScriptRoot\Common.ps1"


# ===========================================================================
# System repair: DISM, SFC, CHKDSK, network, WMI, WU reset, component cleanup
# ===========================================================================
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


# ===========================================================================
# Windows Update repair helpers
# ===========================================================================

# Run an external command and surface non-zero exits as warnings (does NOT throw,
# unlike Common.ps1's Invoke-CommandChecked - WU repair should continue best-effort).
function Invoke-ExternalCommand {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)]
    [string]$FilePath,

    [string]$ArgumentList = ''
  )

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $FilePath
  $psi.Arguments = $ArgumentList
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $proc = New-Object System.Diagnostics.Process
  $proc.StartInfo = $psi
  $null = $proc.Start()
  $proc.WaitForExit()

  if ($proc.ExitCode -ne 0) {
    $stderr = $proc.StandardError.ReadToEnd()
    Write-Warning "$FilePath exited $($proc.ExitCode) : $stderr"
  }
}

function Reset-WUService {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [string]$Name,

    [string]$StartupType = 'auto'
  )

  if (-not $Name) {
    return
  }

  $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
  if (-not $svc) {
    Write-Verbose "Service '$Name' not found; skipping."
    return
  }

  if ($PSCmdlet.ShouldProcess($Name, 'Stop service')) {
    Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
  }

  if ($PSCmdlet.ShouldProcess($Name, "Set startup type to $StartupType")) {
    $null = sc.exe config $Name start= $StartupType
  }
}

function Clear-UpdateCache {
  [CmdletBinding(SupportsShouldProcess)]
  param()

  $paths = @(
    'C:\Windows\Temp'
    'C:\Windows\Prefetch'
    "$env:ALLUSERSPROFILE\application data\Microsoft\Network\downloader"
  )

  foreach ($path in $paths) {
    if (Test-Path $path) {
      if ($PSCmdlet.ShouldProcess($path, 'Clear directory')) {
        try {
          Remove-Item "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
          Write-Warning "Could not fully clear $path : $_"
        }
      }
    }
  }

  # Rename (not delete) so SoftwareDistribution matches the recoverable backup
  # Start-SystemFix already produces for the same directory.
  $swDistribPath = "$env:SystemRoot\SoftwareDistribution"
  if (Test-Path -Path $swDistribPath) {
    $backupName = "SoftwareDistribution-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if ($PSCmdlet.ShouldProcess($swDistribPath, "Rename to $backupName")) {
      Rename-Item -Path $swDistribPath -NewName $backupName -Force -ErrorAction SilentlyContinue
    }
  }
}

function Reset-Catroot2 {
  [CmdletBinding(SupportsShouldProcess)]
  param()

  $catroot = "$env:SystemRoot\system32\catroot2"
  if (Test-Path $catroot) {
    $backupName = "CatRoot2-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    if ($PSCmdlet.ShouldProcess($catroot, "Rename to $backupName")) {
      Rename-Item -Path $catroot -NewName $backupName -Force -ErrorAction SilentlyContinue
    }
  }
}

function Register-WuDll {
  [CmdletBinding(SupportsShouldProcess)]
  param()

  $dlls = @(
    'atl.dll'
    'urlmon.dll'
    'mshtml.dll'
    'msxml2.dll'
    'msxml3.dll'
    'msxml.dll'
    'wuaueng1.dll'
    'wuaueng.dll'
    'wucltui.dll'
    'wups2.dll'
    'wups.dll'
    'wuweb.dll'
  )

  foreach ($dll in $dlls) {
    $full = Join-Path $env:SystemRoot "System32\$dll"
    if (Test-Path $full) {
      if ($PSCmdlet.ShouldProcess($dll, 'regsvr32 /s')) {
        Invoke-ExternalCommand -FilePath 'regsvr32.exe' -ArgumentList "/s `"$full`""
      }
    }
  }
}

function Start-WindowsUpdateFix {
  [CmdletBinding(SupportsShouldProcess)]
  param()

  Set-StrictMode -Version Latest

  Write-Information 'Fixing Windows Update components...'

  # 1. Stop services
  Reset-WUService -Name 'BITS' -StartupType 'delayed-auto'
  Reset-WUService -Name 'wuauserv' -StartupType 'auto'
  Reset-WUService -Name 'AppReadiness' -StartupType 'manual'
  Reset-WUService -Name 'CryptSvc' -StartupType 'auto'

  foreach ($svcName in @('msiserver', 'appidsvc')) {
    $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
    if ($svc -and $PSCmdlet.ShouldProcess($svcName, 'Stop service')) {
      Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
    }
  }

  if ($PSCmdlet.ShouldProcess('TrustedInstaller', 'Set start=auto and start service')) {
    $null = sc.exe config trustedinstaller start= auto
    Start-Service -Name 'TrustedInstaller' -ErrorAction SilentlyContinue
  }

  # 2. Clear caches
  Clear-UpdateCache

  # 3. Reset catroot2
  Reset-Catroot2

  # 4. Re-register DLLs
  Register-WuDll

  # 5. Reset BITS & winsock
  if ($PSCmdlet.ShouldProcess('BITS', 'Reset')) {
    Invoke-ExternalCommand -FilePath 'bitsadmin.exe' -ArgumentList '/reset /allusers'
  }
  if ($PSCmdlet.ShouldProcess('winsock', 'Reset')) {
    Invoke-ExternalCommand -FilePath 'netsh.exe' -ArgumentList 'winsock reset'
  }

  # 6. gpupdate
  if ($PSCmdlet.ShouldProcess('Group Policy', 'Update')) {
    Invoke-ExternalCommand -FilePath 'gpupdate.exe' -ArgumentList '/force'
  }

  Write-Information ''
  Write-Information 'Windows Update repair complete. A reboot is recommended.'
  Write-Information 'Run this script with -WhatIf to preview changes.'
}


# ===========================================================================
# Health diagnostics: disk, updates, services, temp dirs, startup items
# ===========================================================================

# Local to fix-system.ps1 - flags fixed volumes under a free-space threshold.
# Not promoted to Common.ps1 until another caller needs it (YAGNI).
function Test-VolumeFreeSpace {
  [CmdletBinding()]
  param(
    [double]$MinFreePercent = 10
  )

  $flagged = [System.Collections.Generic.List[string]]::new()
  foreach ($volume in Get-Volume | Where-Object { $_.DriveType -eq 'Fixed' -and $_.DriveLetter -and $_.Size -gt 0 }) {
    $freePercent = ($volume.SizeRemaining / $volume.Size) * 100
    if ($freePercent -lt $MinFreePercent) {
      $flagged.Add("$($volume.DriveLetter): $([math]::Round($freePercent, 1))% free")
    }
  }
  return $flagged
}

function Start-SystemHealthCheck {
  [CmdletBinding()]
  param(
    [switch]$DryRun,
    [switch]$NoReport
  )

  Clear-Log
  $results = @{
    DiskHealth     = 'SKIPPED'
    DiskFreeSpace  = 'SKIPPED'
    PendingUpdates = 'SKIPPED'
    Services       = 'SKIPPED'
    TempDirs       = 'SKIPPED'
    StartupItems   = 'SKIPPED'
  }

  $startTime = Get-Date

  Write-Header "Windows System Health Check"
  Write-Info "Start Time: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))"
  Write-Info "This is a read-only diagnostic pass - no repairs are made."
  Add-Log "Health check started"

  if ($DryRun) {
    Write-Warn "[DRY RUN] Would run all health checks"
    foreach ($key in @($results.Keys)) { $results[$key] = 'DRY RUN' }
    Show-Summary -Results $results -StartTime $startTime
    return
  }

  # Check 1: Disk/Volume Health
  Write-Info "=== Check 1: Disk/Volume Health ==="
  try {
    $unhealthy = @(Get-PhysicalDisk -ErrorAction Stop | Where-Object { $_.HealthStatus -ne 'Healthy' })
    if ($unhealthy.Count -eq 0) {
      Write-Success "All physical disks report Healthy"
      $results.DiskHealth = 'HEALTHY'
    }
    else {
      foreach ($disk in $unhealthy) {
        Write-Warn "Disk '$($disk.FriendlyName)' reports $($disk.HealthStatus)"
      }
      $results.DiskHealth = "PARTIAL ($($unhealthy.Count) disk(s) flagged)"
    }
  }
  catch {
    Write-Warn "Could not query physical disk health: $_"
    $results.DiskHealth = "ERROR: $_"
  }

  $lowSpace = Test-VolumeFreeSpace
  if ($lowSpace.Count -eq 0) {
    Write-Success "All fixed volumes have sufficient free space"
    $results.DiskFreeSpace = 'HEALTHY'
  }
  else {
    foreach ($line in $lowSpace) {
      Write-Warn "Low free space: $line"
    }
    $results.DiskFreeSpace = "PARTIAL ($($lowSpace.Count) volume(s) flagged)"
  }

  # Check 2: Pending Windows Updates
  Write-Info "=== Check 2: Pending Windows Updates ==="
  try {
    $session = New-Object -ComObject Microsoft.Update.Session
    $searcher = $session.CreateUpdateSearcher()
    $searchResult = $searcher.Search("IsInstalled=0 and IsHidden=0")
    $pendingCount = $searchResult.Updates.Count
    if ($pendingCount -eq 0) {
      Write-Success "No pending Windows updates"
      $results.PendingUpdates = 'HEALTHY'
    }
    else {
      Write-Warn "$pendingCount Windows update(s) pending"
      $results.PendingUpdates = "PARTIAL ($pendingCount pending)"
    }
  }
  catch {
    Write-Warn "Could not query Windows Update: $_"
    $results.PendingUpdates = "ERROR: $_"
  }

  # Check 3: Service Anomalies (Automatic services that aren't running)
  Write-Info "=== Check 3: Service Anomalies ==="
  $stopped = @(Get-Service | Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' })
  if ($stopped.Count -eq 0) {
    Write-Success "All automatic services are running"
    $results.Services = 'HEALTHY'
  }
  else {
    foreach ($svc in $stopped) {
      Write-Warn "Service '$($svc.Name)' ($($svc.DisplayName)) is $($svc.Status) but StartType is Automatic"
    }
    $results.Services = "PARTIAL ($($stopped.Count) service(s) flagged)"
  }

  # Check 4: Large Temp Directories
  Write-Info "=== Check 4: Large Temp Directories ==="
  $tempThresholdGb = 5
  $tempPaths = @(
    $env:TEMP
    "$env:windir\Temp"
    "$env:windir\SoftwareDistribution\Download"
  )
  $largeTempDirs = [System.Collections.Generic.List[string]]::new()
  foreach ($path in $tempPaths) {
    if (Test-Path $path) {
      $sizeGb = Get-FolderSize -Path $path -Unit GB
      if ($sizeGb -gt $tempThresholdGb) {
        $largeTempDirs.Add("$path : $([math]::Round($sizeGb, 2)) GB")
      }
    }
  }
  if ($largeTempDirs.Count -eq 0) {
    Write-Success "No temp directories over $tempThresholdGb GB"
    $results.TempDirs = 'HEALTHY'
  }
  else {
    foreach ($line in $largeTempDirs) {
      Write-Warn "Large temp directory: $line"
    }
    $results.TempDirs = "PARTIAL ($($largeTempDirs.Count) dir(s) flagged)"
  }

  # Check 5: Startup Items (informational only)
  Write-Info "=== Check 5: Startup Items ==="
  $startupNames = [System.Collections.Generic.List[string]]::new()
  foreach ($runKey in @(
      'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
      'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run'
    )) {
    if (Test-Path $runKey) {
      $props = Get-ItemProperty -Path $runKey -ErrorAction SilentlyContinue
      if ($props) {
        $props.PSObject.Properties |
          Where-Object { $_.Name -notmatch '^PS(Path|ParentPath|ChildName|Provider)$' } |
          ForEach-Object { $startupNames.Add($_.Name) }
      }
    }
  }
  $startupFolder = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
  if (Test-Path $startupFolder) {
    Get-ChildItem -Path $startupFolder -File -ErrorAction SilentlyContinue |
      ForEach-Object { $startupNames.Add($_.Name) }
  }
  Write-Info "$($startupNames.Count) startup item(s): $($startupNames -join ', ')"
  $results.StartupItems = "COMPLETE ($($startupNames.Count) item(s))"

  # Display summary
  Show-Summary -Results $results -StartTime $startTime

  # Write report file
  if (-not $NoReport) {
    $reportFile = Join-Path -Path $PSScriptRoot -ChildPath "fix-system-health-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $durationInfo = Measure-Execution -StartTime $startTime
    $resultLines = $results.GetEnumerator() | Sort-Object -Property Name | ForEach-Object { "$($_.Key) = $($_.Value)" }

    $report = @"
Windows System Health Report
=====================
Start Time: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))
End Time: $($durationInfo.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))
Duration: $($durationInfo.Duration)

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

  Write-Success "Done!"
}

# ===========================================================================
# Dispatcher
# ===========================================================================
if ($MyInvocation.InvocationName -ne '.') {
  switch ($Action) {
    'System' {
      Start-SystemFix -QuickScan:$QuickScan -SkipDiskCheck:$SkipDiskCheck -SkipNetworkFix:$SkipNetworkFix `
        -SkipWUReset:$SkipWUReset -ScheduleChkdsk:$ScheduleChkdsk -DryRun:$DryRun -NoReboot:$NoReboot -NoReport:$NoReport
    }
    'WindowsUpdate' {
      Start-WindowsUpdateFix
    }
    'Health' {
      Start-SystemHealthCheck -DryRun:$DryRun -NoReport:$NoReport
    }
    'All' {
      Start-SystemFix -QuickScan:$QuickScan -SkipDiskCheck:$SkipDiskCheck -SkipNetworkFix:$SkipNetworkFix `
        -SkipWUReset:$SkipWUReset -ScheduleChkdsk:$ScheduleChkdsk -DryRun:$DryRun -NoReboot:$NoReboot -NoReport:$NoReport
      Start-WindowsUpdateFix
    }
    'Restart' {
      if ($PSCmdlet.ShouldProcess('System', 'Restart')) {
        Restart-Computer -Force
      }
    }
    'RestartToBios' {
      if ($PSCmdlet.ShouldProcess('System', 'Restart to firmware/BIOS')) {
        shutdown.exe /r /fw /t 0
      }
    }
  }
}
