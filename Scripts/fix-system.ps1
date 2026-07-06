#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Unified Windows repair: system integrity (DISM/SFC/CHKDSK/network/WMI) and Windows Update component reset.
.DESCRIPTION
    Consolidates two repair tools behind a single -Action switch:
      System         - DISM, SFC (x2), CHKDSK, network, WMI, WU service reset, component cleanup (default)
      WindowsUpdate  - reset WU services/caches/catroot2, re-register DLLs, apply WU registry tweaks
      DriverCleanup  - remove orphaned/unused driver packages from the driver store
      All            - run System, then WindowsUpdate
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
.PARAMETER Restore
    WindowsUpdate action: remove the registry tweaks applied by this script instead of applying them.
.EXAMPLE
    .\fix-system.ps1 -Action System -DryRun
.EXAMPLE
    .\fix-system.ps1 -Action WindowsUpdate -WhatIf
.EXAMPLE
    .\fix-system.ps1 -Action All
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [ValidateSet('System', 'WindowsUpdate', 'DriverCleanup', 'All')]
  [string]$Action = 'System',
  [switch]$QuickScan,
  [switch]$SkipDiskCheck,
  [switch]$SkipNetworkFix,
  [switch]$SkipWUReset,
  [switch]$ScheduleChkdsk,
  [switch]$DryRun,
  [switch]$NoReboot,
  [switch]$NoReport,
  [switch]$Restore
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

function Set-WURegistryTweak {
  [CmdletBinding(SupportsShouldProcess)]
  param()

  $tweaks = @(
    # Disable "Get updates ASAP"
    @{
      Path = 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
      Name = 'IsContinuousInnovationOptedIn'
      Type = 'REG_DWORD'
      Data = '0'
    }
    @{
      Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
      Name = 'AllowOptionalContent'
      Type = 'REG_DWORD'
      Data = '0'
    }
    @{
      Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
      Name = 'SetAllowOptionalContent'
      Type = 'REG_DWORD'
      Data = '0'
    }
  )

  foreach ($tweak in $tweaks) {
    if ($PSCmdlet.ShouldProcess("$($tweak.Path)\$($tweak.Name)", 'Set registry value')) {
      Set-RegistryValue -Path $tweak.Path -Name $tweak.Name -Type $tweak.Type -Data $tweak.Data
    }
  }
}

function Remove-WURegistryTweak {
  [CmdletBinding(SupportsShouldProcess)]
  param()

  $keys = @(
    @{ Path = 'HKLM\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'; Name = 'IsContinuousInnovationOptedIn' }
    @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'AllowOptionalContent' }
    @{ Path = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name = 'SetAllowOptionalContent' }
  )

  foreach ($key in $keys) {
    if ($PSCmdlet.ShouldProcess("$($key.Path)\$($key.Name)", 'Remove registry value')) {
      Remove-RegistryValue -Path $key.Path -Name $key.Name
    }
  }
}

function Remove-TargetReleaseConstraint {
  [CmdletBinding(SupportsShouldProcess)]
  param()

  $values = @(
    'TargetReleaseVersionInfo'
    'TargetReleaseVersion'
    'ProductVersion'
    'DisableOSUpgrade'
    'DisableWindowsUpdateAccess'
    'DoNotConnectToWindowsUpdateInternetLocations'
  )

  foreach ($value in $values) {
    if ($PSCmdlet.ShouldProcess("HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\$value", 'Delete')) {
      Remove-RegistryValue -Path 'HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' -Name $value
    }
  }

  if ($PSCmdlet.ShouldProcess('HKLM\SOFTWARE\Policies\Microsoft\WindowsStore\DisableOSUpgrade', 'Delete')) {
    Remove-RegistryValue -Path 'HKLM\SOFTWARE\Policies\Microsoft\WindowsStore' -Name DisableOSUpgrade
  }

  if ($PSCmdlet.ShouldProcess('HKLM\SYSTEM\Setup\UpgradeNotification\UpgradeAvailable', 'Delete')) {
    Remove-RegistryValue -Path 'HKLM\SYSTEM\Setup\UpgradeNotification' -Name UpgradeAvailable
  }
}

function Start-WindowsUpdateFix {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [switch]$Restore
  )

  Set-StrictMode -Version Latest

  if ($Restore) {
    Write-Information 'Restoring Windows Update registry tweaks...'
    Remove-WURegistryTweak
    Write-Information 'Restore complete.'
    return
  }

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

  # 6. Registry tweaks
  Set-WURegistryTweak
  Remove-TargetReleaseConstraint

  # 7. gpupdate
  if ($PSCmdlet.ShouldProcess('Group Policy', 'Update')) {
    Invoke-ExternalCommand -FilePath 'gpupdate.exe' -ArgumentList '/force'
  }

  Write-Information ''
  Write-Information 'Windows Update repair complete. A reboot is recommended.'
  Write-Information 'Run this script with -WhatIf to preview changes.'
}


# ===========================================================================
# Driver store cleanup
# ===========================================================================
function Start-DriverCleanup {
  [CmdletBinding(SupportsShouldProcess)]
  param()

  Write-Information 'Removing orphaned/unused driver packages from the driver store...'
  if ($PSCmdlet.ShouldProcess('Driver store', 'Clean unused driver packages')) {
    $null = & rundll32.exe pnpclean.dll,RunDLL_PnpClean /DRIVERS /MAXCLEAN
  }
  Write-Information 'Driver cleanup complete.'
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
      Start-WindowsUpdateFix -Restore:$Restore
    }
    'DriverCleanup' {
      Start-DriverCleanup
    }
    'All' {
      Start-SystemFix -QuickScan:$QuickScan -SkipDiskCheck:$SkipDiskCheck -SkipNetworkFix:$SkipNetworkFix `
        -SkipWUReset:$SkipWUReset -ScheduleChkdsk:$ScheduleChkdsk -DryRun:$DryRun -NoReboot:$NoReboot -NoReport:$NoReport
      Start-WindowsUpdateFix -Restore:$Restore
    }
  }
}
