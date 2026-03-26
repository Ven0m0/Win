﻿#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Comprehensive Windows debloating and optimization script
.DESCRIPTION
  Removes bloatware apps, disables unnecessary services, tasks, and features,
  applies privacy registry tweaks, and cleans the system.
  Ported and adapted from obra/debloat-windows-vm.
#>

# Import common functions
. "$PSScriptRoot\Common.ps1"

# Request admin elevation
Request-AdminElevation

# Initialize console UI
Initialize-ConsoleUI -Title "Windows Debloater (Administrator)"

#region Phase 1: App Removal
function Remove-BloatwareApps {
  Write-Host "=== Phase 1: Removing Bloatware Apps ===" -ForegroundColor Cyan

  $appsToRemove = @(
    "Clipchamp.Clipchamp"
    "Microsoft.BingNews"
    "Microsoft.BingWeather"
    "Microsoft.BingSearch"
    "Microsoft.Copilot"
    "Microsoft.GetHelp"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.OutlookForWindows"
    "Microsoft.Todos"
    "Microsoft.YourPhone"
    "Microsoft.ZuneMusic"
    "MicrosoftCorporationII.MicrosoftFamily"
    "MSTeams"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.XboxGameCallableUI"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsCamera"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.Edge.GameAssist"
    "MicrosoftCorporationII.QuickAssist"
    "Microsoft.People"
    "Microsoft.Windows.DevHome"
    "Microsoft.549981C3F5F10"
  )

  foreach ($app in $appsToRemove) {
    Remove-AppxPackageSafe -AppName $app
  }

  Write-Host "`n=== Phase 1 Complete ===" -ForegroundColor Green
}
#endregion

#region Phase 2: Service Management
function Disable-UnnecessaryServices {
  Write-Host "=== Phase 2: Disabling Unnecessary Services ===" -ForegroundColor Cyan

  $servicesToDisable = @(
    @{ Name = "DiagTrack"; Desc = "Connected User Experiences and Telemetry" }
    @{ Name = "dmwappushservice"; Desc = "WAP Push Message Routing" }
    @{ Name = "XblAuthManager"; Desc = "Xbox Live Auth Manager" }
    @{ Name = "XblGameSave"; Desc = "Xbox Live Game Save" }
    @{ Name = "XboxGipSvc"; Desc = "Xbox Accessory Management" }
    @{ Name = "XboxNetApiSvc"; Desc = "Xbox Live Networking" }
    @{ Name = "MapsBroker"; Desc = "Downloaded Maps Manager" }
    @{ Name = "WMPNetworkSvc"; Desc = "Windows Media Player Network Sharing" }
    @{ Name = "WpcMonSvc"; Desc = "Parental Controls" }
    @{ Name = "RetailDemo"; Desc = "Retail Demo Service" }
    @{ Name = "wisvc"; Desc = "Windows Insider Service" }
    @{ Name = "WalletService"; Desc = "Wallet Service" }
    @{ Name = "PhoneSvc"; Desc = "Phone Service" }
    @{ Name = "icssvc"; Desc = "Windows Mobile Hotspot" }
    @{ Name = "lfsvc"; Desc = "Geolocation Service" }
    @{ Name = "WerSvc"; Desc = "Windows Error Reporting" }
    @{ Name = "wercplsupport"; Desc = "Problem Reports Control Panel" }
    @{ Name = "Fax"; Desc = "Fax Service" }
  )

  $servicesToManual = @(
    @{ Name = "SysMain"; Desc = "Superfetch" }
    @{ Name = "WSearch"; Desc = "Windows Search" }
    @{ Name = "BITS"; Desc = "Background Intelligent Transfer" }
    @{ Name = "wuauserv"; Desc = "Windows Update" }
    @{ Name = "TabletInputService"; Desc = "Touch Keyboard" }
    @{ Name = "PcaSvc"; Desc = "Program Compatibility Assistant" }
  )

  Write-Host "`nDisabling services..." -ForegroundColor Yellow
  foreach ($svc in $servicesToDisable) {
    if (Get-Service -Name $svc.Name -ErrorAction SilentlyContinue) {
      Write-Host "  Disabling: $($svc.Name) ($($svc.Desc))" -ForegroundColor Yellow
      Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
      Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
    }
  }

  Write-Host "`nSetting services to Manual..." -ForegroundColor Yellow
  foreach ($svc in $servicesToManual) {
    if (Get-Service -Name $svc.Name -ErrorAction SilentlyContinue) {
      Write-Host "  Setting Manual: $($svc.Name) ($($svc.Desc))" -ForegroundColor Yellow
      Set-Service -Name $svc.Name -StartupType Manual -ErrorAction SilentlyContinue
    }
  }

  Write-Host "`n=== Phase 2 Complete ===" -ForegroundColor Green
}
#endregion

#region Phase 3: Windows Features
function Disable-WindowsFeatures {
  Write-Host "=== Phase 3: Disabling Windows Optional Features ===" -ForegroundColor Cyan

  $featuresToDisable = @(
    @{ Name = "WorkFolders-Client"; Desc = "Work Folders Client" }
    @{ Name = "WindowsMediaPlayer"; Desc = "Windows Media Player" }
    @{ Name = "Printing-Foundation-InternetPrinting-Client"; Desc = "Internet Printing Client" }
  )

  foreach ($feature in $featuresToDisable) {
    $state = Get-WindowsOptionalFeature -Online -FeatureName $feature.Name -ErrorAction SilentlyContinue
    if ($state -and $state.State -eq "Enabled") {
      Write-Host "  Disabling: $($feature.Name) ($($feature.Desc))" -ForegroundColor Yellow
      Disable-WindowsOptionalFeature -Online -FeatureName $feature.Name -NoRestart -ErrorAction SilentlyContinue | Out-Null
    }
  }

  Write-Host "`n=== Phase 3 Complete ===" -ForegroundColor Green
}
#endregion

#region Phase 4: Scheduled Tasks
function Disable-ScheduledTasks {
  Write-Host "=== Phase 4: Disabling Scheduled Tasks ===" -ForegroundColor Cyan

  $tasksToDisable = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
    "\Microsoft\Windows\Application Experience\StartupAppTask"
    "\Microsoft\Windows\Application Experience\AitAgent"
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
    "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask"
    "\Microsoft\Windows\Autochk\Proxy"
    "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask"
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver"
    "\Microsoft\Windows\Feedback\Siuf\DmClient"
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
    "\Microsoft\Windows\Maps\MapsToastTask"
    "\Microsoft\Windows\Maps\MapsUpdateTask"
    "\Microsoft\Windows\Mobile Broadband Accounts\MNO Metadata Parser"
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting"
    "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"
    "\Microsoft\Windows\DiskFootprint\Diagnostics"
    "\Microsoft\Windows\DiskFootprint\StorageSense"
    "\Microsoft\Windows\RetailDemo\CleanupOfflineContent"
    "\Microsoft\Windows\Speech\SpeechModelDownloadTask"
    "\Microsoft\Windows\FileHistory\File History (maintenance mode)"
    "\Microsoft\Windows\Shell\FamilySafetyMonitor"
    "\Microsoft\Windows\Shell\FamilySafetyRefresh"
    "\Microsoft\Windows\Shell\FamilySafetyRefreshTask"
    "\Microsoft\Windows\Subscription\LicenseAcquisition"
    "\Microsoft\Windows\Subscription\EnableLicenseAcquisition"
    "\Microsoft\Windows\Flighting\FeatureConfig\ReconcileFeatures"
    "\Microsoft\Windows\Flighting\FeatureConfig\UsageDataReporting"
    "\Microsoft\Windows\Flighting\FeatureConfig\UsageDataFlushing"
    "\Microsoft\Windows\Flighting\OneSettings\RefreshCache"
    "\Microsoft\Windows\PI\Sqm-Tasks"
    "\Microsoft\Windows\NetTrace\GatherNetworkInfo"
  )

  foreach ($taskPath in $tasksToDisable) {
    $parent = Split-Path $taskPath -Parent
    $leaf = Split-Path $taskPath -Leaf
    $task = Get-ScheduledTask -TaskPath "$parent\" -TaskName $leaf -ErrorAction SilentlyContinue
    if ($task -and $task.State -ne "Disabled") {
      Write-Host "  Disabling: $taskPath" -ForegroundColor Yellow
      Disable-ScheduledTask -TaskPath "$parent\" -TaskName $leaf -ErrorAction SilentlyContinue | Out-Null
    }
  }

  $taskFoldersToDisable = @(
    "\Microsoft\Windows\Customer Experience Improvement Program"
    "\Microsoft\Windows\Feedback\Siuf"
  )

  foreach ($folder in $taskFoldersToDisable) {
    $tasks = Get-ScheduledTask -TaskPath "$folder\" -ErrorAction SilentlyContinue
    foreach ($task in $tasks) {
      if ($task.State -ne "Disabled") {
        Write-Host "  Disabling folder task: $($task.TaskName)" -ForegroundColor Yellow
        Disable-ScheduledTask -TaskPath $task.TaskPath -TaskName $task.TaskName -ErrorAction SilentlyContinue | Out-Null
      }
    }
  }

  Write-Host "`n=== Phase 4 Complete ===" -ForegroundColor Green
}
#endregion

#region Phase 5: Registry Tweaks
function Apply-RegistryTweaks {
  Write-Host "=== Phase 5: Applying Registry Tweaks ===" -ForegroundColor Cyan

  $tweaks = @(
    # Telemetry
    @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "AllowTelemetry"; Value = 0; Type = "REG_DWORD"; Desc = "Disable telemetry" }
    @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name = "DoNotShowFeedbackNotifications"; Value = 1; Type = "REG_DWORD"; Desc = "Disable feedback notifications" }
    # Cortana/Search
    @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "AllowCortana"; Value = 0; Type = "REG_DWORD"; Desc = "Disable Cortana" }
    @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search"; Name = "DisableWebSearch"; Value = 1; Type = "REG_DWORD"; Desc = "Disable web search in Start" }
    # Suggestions
    @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SystemPaneSuggestionsEnabled"; Value = 0; Type = "REG_DWORD"; Desc = "Disable Start menu suggestions" }
    @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name = "SilentInstalledAppsEnabled"; Value = 0; Type = "REG_DWORD"; Desc = "Disable silent app installs" }
    # Privacy
    @{ Path = "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"; Name = "Enabled"; Value = 0; Type = "REG_DWORD"; Desc = "Disable advertising ID" }
    @{ Path = "HKLM\SOFTWARE\Policies\Microsoft\Windows\System"; Name = "EnableActivityFeed"; Value = 0; Type = "REG_DWORD"; Desc = "Disable activity feed" }
    # Performance
    @{ Path = "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name = "ClearPageFileAtShutdown"; Value = 0; Type = "REG_DWORD"; Desc = "Don't clear pagefile at shutdown" }
    @{ Path = "HKCU\Control Panel\Desktop"; Name = "MenuShowDelay"; Value = "50"; Type = "REG_SZ"; Desc = "Reduce menu show delay" }
  )

  foreach ($tweak in $tweaks) {
    Write-Host "  Setting: $($tweak.Desc)" -ForegroundColor Yellow
    Set-RegistryValue -Path $tweak.Path -Name $tweak.Name -Type $tweak.Type -Data $tweak.Value
  }

  Write-Host "`n=== Phase 5 Complete ===" -ForegroundColor Green
}
#endregion

#region Phase 6: System Cleanup
function Get-FolderSize {
  param ([string]$Path)
  if (Test-Path $Path) {
    return (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
  }
  return 0
}

function Format-Size {
  param ([long]$Size)
  if ($Size -gt 1GB) { return "{0:N2} GB" -f ($Size / 1GB) }
  if ($Size -gt 1MB) { return "{0:N2} MB" -f ($Size / 1MB) }
  if ($Size -gt 1KB) { return "{0:N2} KB" -f ($Size / 1KB) }
  return "$Size bytes"
}

function Run-SystemCleanup {
  Write-Host "=== Phase 6: System Cleanup ===" -ForegroundColor Cyan
  $freedSpace = 0

  $systemRoot = $env:SystemRoot
  $cleanupPaths = @(
    @{ Path = $env:TEMP; Desc = "User Temp Files" }
    @{ Path = (Join-Path -Path $systemRoot -ChildPath "Temp"); Desc = "Windows Temp Files" }
    @{ Path = (Join-Path -Path $systemRoot -ChildPath "Prefetch"); Desc = "Prefetch" }
    @{ Path = (Join-Path -Path $systemRoot -ChildPath "SoftwareDistribution\Download"); Desc = "Windows Update Cache" }
  )

  foreach ($cp in $cleanupPaths) {
    $sizeBefore = Get-FolderSize $cp.Path
    if ($sizeBefore -gt 0) {
      Write-Host "  Cleaning: $($cp.Desc) ($(Format-Size $sizeBefore))" -ForegroundColor Yellow
      if ($cp.Desc -eq "Windows Update Cache") {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
      }
      Clear-DirectorySafe -Path $cp.Path
      if ($cp.Desc -eq "Windows Update Cache") {
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
      }
      $sizeAfter = Get-FolderSize $cp.Path
      $freedSpace += ($sizeBefore - $sizeAfter)
    }
  }

  Write-Host "`n  Flushing DNS Cache..." -ForegroundColor Yellow
  ipconfig /flushdns | Out-Null

  Write-Host "  Emptying Recycle Bin..." -ForegroundColor Yellow
  Clear-RecycleBin -Force -ErrorAction SilentlyContinue

  Write-Host "`n=== Phase 6 Complete ===" -ForegroundColor Green
  Write-Host "Total space freed: $(Format-Size $freedSpace)" -ForegroundColor Green
}
#endregion

function Run-AllPhases {
  New-RestorePoint -Description "Before Debloating"
  Remove-BloatwareApps
  Disable-UnnecessaryServices
  Disable-WindowsFeatures
  Disable-ScheduledTasks
  Apply-RegistryTweaks
  Run-SystemCleanup
  Show-RestartRequired -CustomMessage "Debloating complete. Restart recommended to apply all changes."
}

# Main menu loop
while ($true) {
  Show-Menu -Title "Windows Debloater - Main Menu" -Options @(
    "Run All Phases (Recommended)"
    "Phase 1: Remove Bloatware Apps"
    "Phase 2: Disable Unnecessary Services"
    "Phase 3: Disable Windows Features"
    "Phase 4: Disable Scheduled Tasks"
    "Phase 5: Apply Registry Tweaks"
    "Phase 6: System Cleanup"
    "Exit"
  )

  $choice = Get-MenuChoice -Min 1 -Max 8

  switch ($choice) {
    1 { Run-AllPhases }
    2 { Remove-BloatwareApps }
    3 { Disable-UnnecessaryServices }
    4 { Disable-WindowsFeatures }
    5 { Disable-ScheduledTasks }
    6 { Apply-RegistryTweaks }
    7 { Run-SystemCleanup }
    8 { exit }
  }

  if ($choice -ne 8) {
    Wait-ForKeyPress -Message "`nPress any key to return to menu..."
  }
}
