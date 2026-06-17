#Requires -Version 5.1

<#
.SYNOPSIS
  Unified Windows maintenance: volume defrag/MSI cleanup, disk cleanup GUI, shader-cache purge, and safe component maintenance.
.DESCRIPTION
  Consolidates four maintenance tools behind a single -Action switch:
    Defrag  - optimize/retrim volumes (defrag.exe) and clean MSI Afterburner skins/docs (default)
    Disk    - interactive WinForms disk-cleanup GUI (cleanmgr categories + cache/log purge)
    Shader  - clear Steam/GPU shader, log, and crash caches
    Extra   - DISM component cleanup, cache rebuilds, BITS/DNS/temp cleanup, optional restore point
    All     - run Defrag, Shader, then Extra (Disk is interactive and must be selected explicitly)
.PARAMETER Action
  Which maintenance task to run. Defaults to Defrag.
.PARAMETER Volume
  Target volume for Defrag (default: C:). Ignored when -AllVolumes is set.
.PARAMETER AllVolumes
  Run defrag across all volumes.
.PARAMETER NoDefrag
  Skip the defrag/optimization step of the Defrag action.
.PARAMETER NoMsi
  Skip the MSI Afterburner cleanup step of the Defrag action.
.PARAMETER MsiDir
  Override MSI Afterburner install path (default: C:\Program Files (x86)\MSI Afterburner).
.PARAMETER NoRestorePoint
  For the Extra action, skip creating a system restore point.
.PARAMETER DryRun
  Show what would run without executing (Defrag and Extra actions).
.EXAMPLE
  .\system-maintenance.ps1 -Action Defrag -AllVolumes
.EXAMPLE
  .\system-maintenance.ps1 -Action Shader -Verbose
.EXAMPLE
  .\system-maintenance.ps1 -Action Extra -NoRestorePoint -DryRun
.EXAMPLE
  .\system-maintenance.ps1 -Action Disk
#>
# $DryRun is referenced inside nested functions; suppress PSSA cross-scope false-positive.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'DryRun', Justification = 'Used inside nested functions Invoke-DefragCommand and Invoke-MsiCleanup')]
[CmdletBinding(SupportsShouldProcess)]
param(
  [ValidateSet('Defrag', 'Disk', 'Shader', 'Extra', 'All')]
  [string]$Action = 'Defrag',
  [string]$Volume = 'C:',
  [switch]$AllVolumes,
  [switch]$NoDefrag,
  [switch]$NoMsi,
  [string]$MsiDir = "${env:ProgramFiles(x86)}\MSI Afterburner",
  [switch]$NoRestorePoint,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

# Import common functions
. "$PSScriptRoot\Common.ps1"


# ---------------------------------------------------------------------------
# Defrag action: volume optimization + MSI Afterburner cleanup
# ---------------------------------------------------------------------------
function Invoke-DefragCommand {
  param(
    [Parameter(Mandatory)]
    [string]$Arguments
  )
  if ($DryRun) {
    Write-Information "DRY: defrag $Arguments" -InformationAction Continue
    return
  }
  Write-Verbose "Run: defrag $Arguments"
  Invoke-CommandChecked -FilePath 'defrag.exe' -ArgumentList $Arguments
}

function Invoke-Defrag {
  [CmdletBinding()]
  param(
    [string]$TargetVolume,
    [switch]$All
  )
  if ($All) {
    Write-Verbose "Defrag: all volumes full pass (/C)"
    Invoke-DefragCommand -Arguments '/C'
    Write-Verbose "Defrag: all volumes optimize (/C /O)"
    Invoke-DefragCommand -Arguments '/C /O'
    Write-Verbose "Defrag: all volumes retrim (/C /L)"
    Invoke-DefragCommand -Arguments '/C /L'
  } else {
    Write-Verbose "Defrag: optimize $TargetVolume (/O)"
    Invoke-DefragCommand -Arguments "$TargetVolume /O"
    Write-Verbose "Defrag: retrim $TargetVolume (/L)"
    Invoke-DefragCommand -Arguments "$TargetVolume /L"
    Write-Verbose "Defrag: free-space consolidate $TargetVolume (/X)"
    Invoke-DefragCommand -Arguments "$TargetVolume /X"
    Write-Verbose "Defrag: storage tier optimize $TargetVolume (/G)"
    Invoke-DefragCommand -Arguments "$TargetVolume /G"
    Write-Verbose "Defrag: boot optimization $TargetVolume (/B)"
    Invoke-DefragCommand -Arguments "$TargetVolume /B"
  }
}

function Invoke-MsiCleanup {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory)]
    [string]$Root
  )

  if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw "MSI Afterburner not found at: $Root"
  }
  Write-Verbose "MSI cleanup at: $Root"

  $skinsDir  = Join-Path -Path $Root -ChildPath 'Skins'
  $keepSkins = @('MSIMystic.usf', 'MSIWin11Dark.usf', 'defaultX.uxf')

  # Stage keepers outside Skins, wipe Skins, recreate, move them back.
  foreach ($skin in $keepSkins) {
    $source = Join-Path -Path $skinsDir -ChildPath $skin
    $temp   = Join-Path -Path $Root     -ChildPath $skin
    if (Test-Path -LiteralPath $source -PathType Leaf) {
      if ($DryRun) {
        Write-Information "DRY: Copy-Item '$source' -> '$temp'" -InformationAction Continue
      } elseif ($PSCmdlet.ShouldProcess($source, 'Copy to temp')) {
        Copy-Item -LiteralPath $source -Destination $temp -Force
      }
    }
  }

  foreach ($subDir in @('Skins', 'Localization', 'Doc', 'SDK\Doc')) {
    $target = Join-Path -Path $Root -ChildPath $subDir
    if (Test-Path -LiteralPath $target -PathType Container) {
      if ($DryRun) {
        Write-Information "DRY: Remove-Item '$target'" -InformationAction Continue
      } elseif ($PSCmdlet.ShouldProcess($target, 'Remove directory')) {
        Remove-Item -LiteralPath $target -Recurse -Force
      }
    }
  }

  if ($DryRun) {
    Write-Information "DRY: New-Item '$skinsDir' -ItemType Directory" -InformationAction Continue
  } elseif ($PSCmdlet.ShouldProcess($skinsDir, 'Create directory')) {
    $null = New-Item -Path $skinsDir -ItemType Directory -Force
  }

  foreach ($skin in $keepSkins) {
    $temp = Join-Path -Path $Root -ChildPath $skin
    if (Test-Path -LiteralPath $temp -PathType Leaf) {
      $dest = Join-Path -Path $skinsDir -ChildPath $skin
      if ($DryRun) {
        Write-Information "DRY: Move-Item '$temp' -> '$dest'" -InformationAction Continue
      } elseif ($PSCmdlet.ShouldProcess($temp, 'Move to Skins')) {
        Move-Item -LiteralPath $temp -Destination $dest -Force
      }
    }
  }

  $startMenu  = Join-Path -Path $env:APPDATA -ChildPath 'Microsoft\Windows\Start Menu\Programs\MSI Afterburner'
  $sdkLink    = Join-Path -Path $startMenu -ChildPath 'SDK'
  $readmeLink = Join-Path -Path $startMenu -ChildPath 'ReadMe.lnk'

  if (Test-Path -LiteralPath $sdkLink -PathType Container) {
    if ($DryRun) {
      Write-Information "DRY: Remove-Item '$sdkLink'" -InformationAction Continue
    } elseif ($PSCmdlet.ShouldProcess($sdkLink, 'Remove SDK shortcut folder')) {
      Remove-Item -LiteralPath $sdkLink -Recurse -Force
    }
  }

  if (Test-Path -LiteralPath $readmeLink -PathType Leaf) {
    if ($DryRun) {
      Write-Information "DRY: Remove-Item '$readmeLink'" -InformationAction Continue
    } elseif ($PSCmdlet.ShouldProcess($readmeLink, 'Remove ReadMe shortcut')) {
      Remove-Item -LiteralPath $readmeLink -Force
    }
  }

  Write-Verbose "MSI cleanup done."
}


# ---------------------------------------------------------------------------
# Extra action: DISM component cleanup, cache rebuilds, BITS/DNS/temp cleanup
# ---------------------------------------------------------------------------
function Start-AdditionalMaintenance {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [switch]$DryRun,
    [switch]$NoRestorePoint
  )

  Initialize-ConsoleUI -Title "Additional Safe Windows Maintenance"
  Clear-Log
  $Results = @{}
  $StartTime = Get-Date

  Write-Header "Additional Safe Windows Maintenance"

  # 1. Create System Restore Point (optional but recommended)
  if ($NoRestorePoint) {
    Write-Info "Skipping restore point creation"
    $Results['SystemRestorePoint'] = 'SKIPPED'
  } else {
    Invoke-Operation -Name 'SystemRestorePoint' -Results $Results -DryRun:$DryRun `
      -Result 'CREATED' -Action {
        New-RestorePoint -Description "Pre-Maintenance-$(Get-Date -Format 'yyyyMMdd')"
      }
  }

  # 2. DISM Component Store Analysis
  Write-Info "=== DISM Component Store Analysis ==="
  Invoke-Operation -Name 'DISM_ComponentAnalysis' -Results $Results -DryRun:$DryRun -Result 'COMPLETE' `
    -Action {} -Command 'DISM' -ArgumentList '/Online /Cleanup-Image /AnalyzeComponentStore'

  # 2a. DISM Component Cleanup
  Invoke-Operation -Name 'DISM_ComponentCleanup' -Results $Results -DryRun:$DryRun -Result 'COMPLETE' `
    -Action {} -Command 'DISM' -ArgumentList '/Online /Cleanup-Image /StartComponentCleanup'

  # 2b. DISM RestoreHealth (aggressive - use when system corruption or update issues occur)
  # WARNING: This operation can take 30+ minutes and requires a reboot
  # Only run this if you are experiencing system issues, not for regular maintenance
  Write-Info "=== DISM RestoreHealth ==="
  Write-Warn "NOTE: /RestoreHealth may take 30+ minutes and may require a reboot."
  Invoke-Operation -Name 'DISM_RestoreHealth' -Results $Results -DryRun:$DryRun -Result 'COMPLETE' `
    -Action {} -Command 'DISM' -ArgumentList '/Online /Cleanup-Image /RestoreHealth'

  # 3. Clear Windows Store Cache
  Invoke-Operation -Name 'StoreCacheClear' -Results $Results -DryRun:$DryRun -Result 'CLEARED' `
    -Action {} -Command 'wsreset.exe' -ArgumentList '-i'

  # 4. Clear BITS Queue
  Invoke-Operation -Name 'BITSClear' -Results $Results -DryRun:$DryRun -Result 'CLEARED' -Action {
    Import-Module -Name BitsTransfer -ErrorAction SilentlyContinue
    Get-BitsTransfer -AllUsers | Remove-BitsTransfer -ErrorAction SilentlyContinue
  }

  # 5. Rebuild Font Cache
  Invoke-Operation -Name 'FontCache' -Results $Results -DryRun:$DryRun -Result 'REBUILT' -Action {
    Invoke-ServiceOperation -Name 'FontCache' -Action {
      $fontCachePath = "$env:SystemRoot\ServiceProfiles\LocalService\AppData\Local\FontCache"
      if (Test-Path -Path $fontCachePath) {
        Clear-PathSafe -Path "$fontCachePath\*"
      }
    }
  }

  # 6. Clear Icon Cache
  Invoke-Operation -Name 'IconCache' -Results $Results -DryRun:$DryRun -Result 'CLEARED' -Action {
    Stop-Process -Name 'explorer' -Force -ErrorAction SilentlyContinue
    $iconCachePath = "$env:LOCALAPPDATA\IconCache.db"
    if (Test-Path -Path $iconCachePath) {
      Clear-PathSafe -Path $iconCachePath
    }
    Clear-PathSafe -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db"
    Start-Process -FilePath 'explorer.exe'
  }

  # 7. Clear Thumbnail Cache
  Invoke-Operation -Name 'ThumbCache' -Results $Results -DryRun:$DryRun -Result 'CLEARED' -Action {
    Clear-PathSafe -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db"
  }

  # 8. Clear DNS Client Cache
  Invoke-Operation -Name 'DNSCache' -Results $Results -DryRun:$DryRun -Result 'CLEARED' -Action {
    Clear-DnsClientCache -ErrorAction Stop
  }

  # 9. Clear Temp Files
  Invoke-Operation -Name 'TempFiles' -Results $Results -DryRun:$DryRun -Result 'CLEARED' -Action {
    $tempPaths = @(
      $env:TEMP,
      "$env:SystemRoot\Temp",
      "$env:LOCALAPPDATA\Temp"
    )
    $cleared = 0
    foreach ($path in $tempPaths) {
      if (Test-Path -Path $path) {
        Clear-PathSafe -Path $path
        $cleared++
      }
    }
    Write-Success "Temp files cleaned from $cleared locations"
  }

  # Display summary
  Show-Summary -Results $Results -StartTime $StartTime

  # Write log file
  $logFileName = "maintenance-log-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
  $logFile = Join-Path -Path $PSScriptRoot -ChildPath $logFileName
  Get-Log | Out-File -FilePath $logFile
  Write-Info "Log written to: $logFile"

  Write-Warn "NOTE: Some changes may require a restart to take full effect."
}


# ---------------------------------------------------------------------------
# Disk action: interactive WinForms disk cleanup GUI
# ---------------------------------------------------------------------------
function Start-UltimateDiskCleanup {
  [CmdletBinding(SupportsShouldProcess)]
  param()

  Add-Type -AssemblyName System.Windows.Forms
  Add-Type -AssemblyName System.Drawing
  [System.Windows.Forms.Application]::EnableVisualStyles()

  # Build form
  $form = New-Object System.Windows.Forms.Form
  $form.Text          = 'Ultimate Cleanup'
  $form.Size          = New-Object System.Drawing.Size(450, 400)
  $form.StartPosition = 'CenterScreen'
  $form.BackColor     = 'Black'

  $label          = New-Object System.Windows.Forms.Label
  $label.Location = New-Object System.Drawing.Point(60, 10)
  $label.Size     = New-Object System.Drawing.Size(250, 25)
  $label.Text     = 'Disk Cleanup Options'
  $label.ForeColor = 'White'
  $label.Font     = New-Object System.Drawing.Font('segoe ui', 10)
  $form.Controls.Add($label)

  $checkedListBox          = New-Object System.Windows.Forms.CheckedListBox
  $checkedListBox.Location = New-Object System.Drawing.Point(40, 60)
  $checkedListBox.Size     = New-Object System.Drawing.Size(200, 300)
  $checkedListBox.BackColor = 'Black'
  $checkedListBox.ForeColor = 'White'

  $options = @(
    'Active Setup Temp Folders'
    'Thumbnail Cache'
    'Delivery Optimization Files'
    'D3D Shader Cache'
    'Downloaded Program Files'
    'Internet Cache Files'
    'Setup Log Files'
    'Temporary Files'
    'Windows Error Reporting Files'
    'Offline Pages Files'
    'Recycle Bin'
    'Temporary Setup Files'
    'Update Cleanup'
    'Upgrade Discarded Files'
    'Windows Defender'
    'Windows ESD installation files'
    'Windows Reset Log Files'
    'Windows Upgrade Log Files'
    'Previous Installations'
    'Old ChkDsk Files'
    'Feedback Hub Archive log files'
    'Diagnostic Data Viewer database files'
    'Device Driver Packages'
  )

  foreach ($option in $options) {
    $null = $checkedListBox.Items.Add($option, $false)
  }

  $checkBox1          = New-Object System.Windows.Forms.CheckBox
  $checkBox1.Text     = 'Clear Event Viewer Logs'
  $checkBox1.Location = New-Object System.Drawing.Point(250, 70)
  $checkBox1.ForeColor = 'White'
  $checkBox1.AutoSize = $true

  $checkBox2          = New-Object System.Windows.Forms.CheckBox
  $checkBox2.Text     = 'Clear Windows Logs'
  $checkBox2.Location = New-Object System.Drawing.Point(250, 100)
  $checkBox2.ForeColor = 'White'
  $checkBox2.AutoSize = $true

  $checkBox3          = New-Object System.Windows.Forms.CheckBox
  $checkBox3.Text     = 'Clear TEMP Cache'
  $checkBox3.Location = New-Object System.Drawing.Point(250, 130)
  $checkBox3.ForeColor = 'White'
  $checkBox3.AutoSize = $true

  $buttonClean              = New-Object System.Windows.Forms.Button
  $buttonClean.Text         = 'Clean'
  $buttonClean.Location     = New-Object System.Drawing.Point(250, 200)
  $buttonClean.Size         = New-Object System.Drawing.Size(100, 30)
  $buttonClean.ForeColor    = 'White'
  $buttonClean.BackColor    = [System.Drawing.Color]::FromArgb(30, 30, 30)
  $buttonClean.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $buttonClean.Add_MouseEnter({
    $buttonClean.BackColor = [System.Drawing.Color]::FromArgb(64, 64, 64)
  })
  $buttonClean.Add_MouseLeave({
    $buttonClean.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
  })

  $checkALL          = New-Object System.Windows.Forms.CheckBox
  $checkALL.Text     = 'Check All'
  $checkALL.Location = New-Object System.Drawing.Point(40, 40)
  $checkALL.ForeColor = 'White'
  $checkALL.AutoSize = $true
  $checkALL.add_CheckedChanged({
    for ($i = 0; $i -lt $options.Count; $i++) {
      $checkedListBox.SetItemChecked($i, $checkALL.Checked)
    }
  })

  $form.Controls.Add($checkALL)
  $form.Controls.Add($checkedListBox)
  $form.Controls.Add($checkBox1)
  $form.Controls.Add($checkBox2)
  $form.Controls.Add($checkBox3)
  $form.Controls.Add($buttonClean)

  $result = $form.ShowDialog()

  if ($result -ne [System.Windows.Forms.DialogResult]::OK) {
    return
  }

  $driveLetter = $env:SystemDrive -replace ':', ''
  $drive       = Get-PSDrive -Name $driveLetter
  $usedBefore  = [math]::Round($drive.Used / 1GB, 4)
  Write-Verbose "BEFORE CLEANING - Used space on $($drive.Name):\ $usedBefore GB"

  # Clear common cache directories
  Write-Verbose 'Clearing cache...'
  Write-Verbose 'Clearing Windows Prefetch...'
  Clear-PathSafe -Path "$env:SystemRoot\Prefetch\*"

  Write-Verbose 'Clearing Windows Temp...'
  Clear-DirectorySafe -Path "$env:SystemRoot\Temp"

  Write-Verbose 'Clearing User Temp...'
  Clear-DirectorySafe -Path $env:TEMP

  Write-Verbose 'Clearing Internet Explorer Cache...'
  Clear-PathSafe -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*"

  Write-Verbose 'Cache clearing completed.'

  if ($checkBox1.Checked) {
    Write-Verbose 'Clearing Event Viewer Logs...'
    & wevtutil.exe el | ForEach-Object { $null = & wevtutil.exe cl "$_" 2>&1 }
  }

  if ($checkBox2.Checked) {
    Write-Verbose 'Clearing Windows Log Files...'

    $logPaths = @(
      "$env:SystemRoot\DtcInstall.log"
      "$env:SystemRoot\comsetup.log"
      "$env:SystemRoot\PFRO.log"
      "$env:SystemRoot\setupact.log"
      "$env:SystemRoot\setuperr.log"
      "$env:SystemRoot\setupapi.log"
      "$env:SystemRoot\Panther\*"
      "$env:SystemRoot\inf\setupapi.app.log"
      "$env:SystemRoot\inf\setupapi.dev.log"
      "$env:SystemRoot\inf\setupapi.offline.log"
      "$env:SystemRoot\Performance\WinSAT\winsat.log"
      "$env:SystemRoot\debug\PASSWD.LOG"
      "$env:SystemRoot\Logs\CBS\CBS.log"
      "$env:SystemRoot\Logs\DISM\DISM.log"
      "$env:SystemRoot\Logs\SIH\*"
      "$env:LOCALAPPDATA\Microsoft\CLR_v4.0\UsageTraces\*"
      "$env:LOCALAPPDATA\Microsoft\CLR_v4.0_32\UsageTraces\*"
      "$env:SystemRoot\Logs\NetSetup\*"
      "$env:SystemRoot\System32\LogFiles\setupcln\*"
      "$env:SystemRoot\Temp\CBS\*"
      "$env:SystemRoot\System32\catroot2\dberr.txt"
      "$env:SystemRoot\System32\catroot2.log"
      "$env:SystemRoot\System32\catroot2.jrs"
      "$env:SystemRoot\System32\catroot2.edb"
      "$env:SystemRoot\System32\catroot2.chk"
      "$env:SystemRoot\Traces\WindowsUpdate\*"
    )

    foreach ($logPath in $logPaths) {
      Clear-PathSafe -Path $logPath
    }

    # WaasMedic log requires ownership change before removal
    $waasPath = "$env:SystemRoot\Logs\waasmedic"
    if (Test-Path -Path $waasPath) {
      $null = & takeown.exe /f $waasPath /r /d y 2>&1
      $null = & icacls.exe $waasPath /grant 'administrators:F' /t 2>&1
      Clear-DirectorySafe -Path $waasPath
    }
  }

  if ($checkBox3.Checked) {
    Write-Verbose 'Clearing TEMP Files...'
    Clear-DirectorySafe -Path "$env:SystemRoot\Temp"
    Clear-DirectorySafe -Path $env:TEMP
  }

  if ($checkedListBox.CheckedItems.Count -gt 0) {
    $key = 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    foreach ($item in $checkedListBox.CheckedItems) {
      Set-RegistryValue -Path "$key\$item" -Name 'StateFlags0069' -Type 'REG_DWORD' -Data '2'
    }
    Write-Verbose 'Running Disk Cleanup...'
    Start-Process -FilePath 'cleanmgr.exe' -ArgumentList '/sagerun:69 /autoclean' -Wait
  }

  $drive    = Get-PSDrive -Name $driveLetter
  $usedAfter = [math]::Round($drive.Used / 1GB, 4)
  Write-Verbose "AFTER CLEANING - Used space on $($drive.Name):\ $usedAfter GB"
}


# ---------------------------------------------------------------------------
# Shader action: clear Steam/GPU shader, log, and crash caches
# ---------------------------------------------------------------------------
function Invoke-ShaderCacheCleanup {
  <#
  .SYNOPSIS
      Clears shader caches and game logs.
  #>
  [CmdletBinding()]
  param()

  #--- Detect Steam
  try {
    $STEAM = (Get-ItemProperty -Path 'HKCU:\SOFTWARE\Valve\Steam').SteamPath
    if (-not (Test-Path -Path "$STEAM\steam.exe") -or -not (Test-Path -Path "$STEAM\steamapps\libraryfolders.vdf")) {
      Write-Warning 'Steam not found!'
      Start-Sleep -Seconds 5
      return
    }
  } catch {
    Write-Warning 'Steam not found in registry!'
    return
  }

  #--- Targeted Apps
  $apps = @(
    @{ id = 730; name = 'cs2'; mod = 'csgo'; installdir = 'Counter-Strike Global Offensive' }
  )

  #--- Find per-app install locations (using Common.ps1 VDF parser)
  $vdf = Get-Content -Path "$STEAM\steamapps\libraryfolders.vdf" -Force -ErrorAction SilentlyContinue
  if (-not $vdf) { $vdf = @('"libraryfolders"', '{', '}') }
  $vdfParsed = (ConvertFrom-VDF -Content $vdf).Item(0)
  $rootsList = [System.Collections.Generic.List[string]]::new()
  foreach ($nr in $vdfParsed.Keys) {
    $entry = $vdfParsed[$nr]
    if ($entry -and $entry['path']) {
      $rootsList.Add($entry['path'].Trim('"'))
    }
  }
  $roots = $rootsList.ToArray()

  foreach ($app in $apps) {
    foreach ($root in $roots) {
      $i = "$root\steamapps\common\$($app.installdir)"
      if (Test-Path -Path "$i\game\$($app.mod)\steam.inf") {
        $app.gameroot  = "$i\game"
        $app.game      = "$i\game\$($app.mod)"
        $app.exe       = "$i\game\bin\win64\$($app.name).exe"
        $app.steamapps = "$root\steamapps"
      }
    }
  }

  #--- Graceful/forced Steam & app shutdown
  $gameProcesses = $apps.name
  $stopParts    = foreach ($app in $apps) { "+app_stop $($app.id)" }
  $appStopArgs  = $stopParts -join ' '

  Stop-SteamGracefully -AppStopArgs $appStopArgs

  foreach ($proc in $gameProcesses) {
    Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
  }
  Remove-Item -Path "$STEAM\.crash" -Force -ErrorAction SilentlyContinue

  Write-Verbose 'Clearing Steam logs...'
  Clear-DirectorySafe -Path "$STEAM\logs"

  Write-Verbose 'Clearing Steam dumps...'
  Clear-DirectorySafe -Path "$STEAM\dumps"

  Write-Verbose 'Clearing app crash dumps...'
  foreach ($app in $apps) {
    if ($app.exe) {
      $dir = Split-Path -Path $app.exe
      Get-ChildItem -Path "$dir\*.mdmp" -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
    }
  }

  Write-Verbose 'Clearing app shader cache...'
  $allTargets = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($app in $apps) {
    if ($app.game)      { $null = $allTargets.Add("$($app.game)\shadercache") }
    if ($app.steamapps) { $null = $allTargets.Add("$($app.steamapps)\shadercache\$($app.id)") }
    if ($app.steamapps -ne "$STEAM\steamapps") {
      $null = $allTargets.Add("$STEAM\steamapps\shadercache\$($app.id)")
    }
  }
  foreach ($t in $allTargets) { Clear-DirectorySafe -Path $t }

  Write-Verbose 'Clearing NVIDIA Compute cache...'
  Clear-DirectorySafe -Path "$env:APPDATA\NVIDIA\ComputeCache"

  Write-Verbose 'Clearing NV_Cache...'
  Clear-DirectorySafe -Path "$env:ProgramData\NVIDIA Corporation\NV_Cache"

  Write-Verbose 'Clearing local shader caches...'
  foreach ($entry in @(
    'D3DSCache', 'NVIDIA\GLCache', 'NVIDIA\DXCache', 'NVIDIA\OptixCache',
    'NVIDIA Corporation\NV_Cache', 'AMD\DX9Cache', 'AMD\DxCache', 'AMD\DxcCache',
    'AMD\GLCache', 'AMD\OglCache', 'AMD\VkCache', 'Intel\ShaderCache'
  )) {
    Clear-DirectorySafe -Path "$env:LOCALAPPDATA\$entry"
  }

  Write-Verbose 'Clearing LocalLow shader caches...'
  $localLow = Join-Path -Path $env:LOCALAPPDATA -ChildPath '..\LocalLow'
  foreach ($entry in @(
    'NVIDIA\PerDriverVersion\DXCache', 'NVIDIA\PerDriverVersion\GLCache', 'Intel\ShaderCache'
  )) {
    Clear-DirectorySafe -Path "$localLow\$entry"
  }

  Write-Verbose 'Clearing driver temp dirs...'
  foreach ($entry in @("$env:SystemDrive\AMD", "$env:SystemDrive\NVIDIA", "$env:SystemDrive\Intel")) {
    Clear-DirectorySafe -Path $entry
  }

  Write-Host 'All relevant shader/log/crash caches cleaned.'
}


# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------
if ($MyInvocation.InvocationName -ne '.') {
  try {
    Request-AdminElevation

    switch ($Action) {
      'Defrag' {
        if (-not $NoDefrag) {
          Invoke-Defrag -TargetVolume $Volume -All:$AllVolumes
        } else {
          Write-Verbose "Skip defrag (-NoDefrag)."
        }
        if (-not $NoMsi) {
          Invoke-MsiCleanup -Root $MsiDir
        } else {
          Write-Verbose "Skip MSI cleanup (-NoMsi)."
        }
      }
      'Disk' {
        Start-UltimateDiskCleanup
      }
      'Shader' {
        Invoke-ShaderCacheCleanup
      }
      'Extra' {
        Start-AdditionalMaintenance -DryRun:$DryRun -NoRestorePoint:$NoRestorePoint
      }
      'All' {
        if (-not $NoDefrag) {
          Invoke-Defrag -TargetVolume $Volume -All:$AllVolumes
        }
        if (-not $NoMsi) {
          Invoke-MsiCleanup -Root $MsiDir
        }
        Invoke-ShaderCacheCleanup
        Start-AdditionalMaintenance -DryRun:$DryRun -NoRestorePoint:$NoRestorePoint
      }
    }

    Write-Verbose "Complete."
  } catch {
    Write-Error $_.Exception.Message
    exit 1
  }
}
