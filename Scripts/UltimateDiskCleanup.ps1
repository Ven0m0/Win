#Requires -Version 5.1
#Requires -RunAsAdministrator
# Ultimate Disk Cleanup - GUI tool for comprehensive disk cleanup
# Provides user-friendly interface for Windows cleanup utilities

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

. "$PSScriptRoot\Common.ps1"

function Start-UltimateDiskCleanup {
  [CmdletBinding(SupportsShouldProcess)]
  param()

  Request-AdminElevation

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

if ($MyInvocation.InvocationName -ne '.') {
  Start-UltimateDiskCleanup @PSBoundParameters
  exit $LASTEXITCODE
}
