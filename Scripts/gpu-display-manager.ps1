# gpu-display-manager.ps1 - Unified GPU and Display Settings Manager
# Combines NVIDIA GPU settings, EDID overrides, gaming display optimizations, and MSI mode
# Replaces: nvidia-settings.ps1, edid-manager.ps1, gaming-display.ps1, msi-mode.ps1

#Requires -RunAsAdministrator

# Import common functions
. "$PSScriptRoot\Common.ps1"

# Request admin elevation
Request-AdminElevation

# Initialize console UI
Initialize-ConsoleUI -Title "GPU & Display Manager (Administrator)"

#region NVIDIA GPU Settings
function Set-P0State {
  param([string]$Value)

  $gpuPaths = Set-NvidiaGpuRegistryValue -Name "DisableDynamicPstate" -Type REG_DWORD -Data $Value

  Clear-Host
  Write-Host "P0 State: $(if ($Value -eq '1') { 'On' } else { 'Default' })" -ForegroundColor $(if ($Value -eq '1') { 'Green' } else { 'Cyan' })
  Show-NvidiaSettings -Setting "P0State" -GpuPaths $gpuPaths
}

function Set-HDCP {
  param([string]$Value)

  $gpuPaths = Set-NvidiaGpuRegistryValue -Name "RMHdcpKeyglobZero" -Type REG_DWORD -Data $Value

  Clear-Host
  Write-Host "HDCP: $(if ($Value -eq '1') { 'Off' } else { 'Default' })" -ForegroundColor $(if ($Value -eq '1') { 'Green' } else { 'Cyan' })
  Show-NvidiaSettings -Setting "HDCP" -GpuPaths $gpuPaths
}

function Show-NvidiaSettings {
  param(
    [string]$Setting = "All",
    [string[]]$GpuPaths
  )

  Show-NvidiaGpuSettings -Title "Current NVIDIA GPU Settings:" -Setting $Setting -GpuPaths $GpuPaths
}
#endregion

#region MSI Mode
function Set-MSIMode {
  param([bool]$Enable)

  Clear-Host

  # Get all GPU display devices
  $gpuDevices = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue

  if ($gpuDevices.Count -eq 0) {
    Write-Host "No display adapters found!" -ForegroundColor Yellow
    return
  }

  $msiValue = if ($Enable) { "1" } else { "0" }
  $status = if ($Enable) { "Enabling" } else { "Disabling" }

  Write-Host "$status MSI Mode for all GPUs..." -ForegroundColor Cyan
  Write-Host ""

  # Set MSI mode for all GPUs
  foreach ($gpu in $gpuDevices) {
    $instanceID = $gpu.InstanceId
    $regPath = "HKLM\SYSTEM\ControlSet001\Enum\$instanceID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
    Set-RegistryValue -Path $regPath -Name "MSISupported" -Type REG_DWORD -Data $msiValue
  }

  # Display MSI mode status
  Write-Host "MSI Mode Status:" -ForegroundColor Cyan
  Write-Host ""

  foreach ($gpu in $gpuDevices) {
    $instanceID = $gpu.InstanceId
    $regPath = "Registry::HKLM\SYSTEM\ControlSet001\Enum\$instanceID\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"

    Write-Host "Device: $($gpu.FriendlyName)" -ForegroundColor Yellow
    Write-Host "  Instance ID: $instanceID" -ForegroundColor Gray

    try {
      $msiSupported = (Get-ItemProperty -Path $regPath -Name "MSISupported" -ErrorAction Stop).MSISupported
      $statusColor = if ($msiSupported -eq 1) { "Green" } else { "Yellow" }
      $statusText = if ($msiSupported -eq 1) { "Enabled (1)" } else { "Disabled (0)" }
      Write-Host "  MSI Mode: $statusText" -ForegroundColor $statusColor
    } catch {
      Write-Host "  MSI Mode: Not configured or error accessing registry" -ForegroundColor Red
    }
    Write-Host ""
  }
}
#endregion

#region EDID Override
$REG_LOCATION = 'HKLM\SYSTEM\CurrentControlSet\Enum\'
$EDID_HEX = '02030400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f7'

function Set-EDIDOverride {
  $monitors = Get-MonitorInstances

  if ($monitors.Count -eq 0) {
    Write-Host "No monitors detected!" -ForegroundColor Yellow
    return
  }

  Write-Host "Applying EDID Override..." -ForegroundColor Cyan
  Write-Host ""

  foreach ($monitor in $monitors) {
    $name = $monitor -split '\\'
    Write-Host "  Applying override for: $($name[1])" -ForegroundColor Green
    $regPath = "$REG_LOCATION$monitor\Device Parameters\EDID_OVERRIDE"
    Set-RegistryValue -Path $regPath -Name '1' -Type REG_BINARY -Data $EDID_HEX
  }

  Write-Host ""
  Write-Host "EDID override applied successfully to $($monitors.Count) monitor(s)." -ForegroundColor Green
}

function Remove-EDIDOverride {
  $monitors = Get-MonitorInstances

  if ($monitors.Count -eq 0) {
    Write-Host "No monitors detected!" -ForegroundColor Yellow
    return
  }

  Write-Host "Removing EDID Override..." -ForegroundColor Cyan
  Write-Host ""

  foreach ($monitor in $monitors) {
    $name = $monitor -split '\\'
    Write-Host "  Removing override for: $($name[1])" -ForegroundColor Green
    $regPath = "$REG_LOCATION$monitor\Device Parameters\EDID_OVERRIDE"
    Remove-RegistryValue -Path $regPath
  }

  Write-Host ""
  Write-Host "EDID override removed successfully from $($monitors.Count) monitor(s)." -ForegroundColor Green
}

function Show-EDIDStatus {
  $monitors = Get-MonitorInstances

  if ($monitors.Count -eq 0) {
    Write-Host "No monitors detected!" -ForegroundColor Yellow
    return
  }

  Write-Host "Current EDID Override Status:" -ForegroundColor Cyan
  Write-Host ""

  foreach ($monitor in $monitors) {
    $name = $monitor -split '\\'
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$monitor\Device Parameters\EDID_OVERRIDE"

    Write-Host "Monitor: $($name[1])" -ForegroundColor Yellow

    if (Test-Path $regPath) {
      try {
        $override = Get-ItemProperty -Path $regPath -Name '1' -ErrorAction Stop
        Write-Host "  Status: Override applied" -ForegroundColor Green
        Write-Host "  Value: Present" -ForegroundColor Green
      } catch {
        Write-Host "  Status: No override" -ForegroundColor Gray
      }
    } else {
      Write-Host "  Status: No override" -ForegroundColor Gray
    }
    Write-Host ""
  }
}
#endregion

#region Gaming Display Settings
# Gaming display functions now available from Common.ps1:
# - Set-FullscreenMode
# - Set-MultiPlaneOverlay
# - Show-GamingDisplayStatus
#endregion

#region Menu System
function Show-MainMenu {
  Show-Menu -Title "GPU & Display Manager - Select Category" -Options @(
    "NVIDIA GPU Settings"
    "MSI Mode Configuration"
    "EDID Override Manager"
    "Gaming Display Optimizations"
    "Exit"
  )
}

function Show-NvidiaMenu {
  while ($true) {
    Show-Menu -Title "NVIDIA GPU Settings" -Options @(
      "P0 State (Highest Performance): On"
      "P0 State (Highest Performance): Default"
      "HDCP (Content Protection): Off"
      "HDCP (Content Protection): Default"
      "View Current Settings"
      "Back to Main Menu"
    )

    $choice = Get-MenuChoice -Min 1 -Max 6

    switch ($choice) {
      1 {
        Set-P0State -Value "1"
        Show-RestartRequired
      }
      2 {
        Set-P0State -Value "0"
        Show-RestartRequired
      }
      3 {
        Set-HDCP -Value "1"
        Show-RestartRequired
      }
      4 {
        Set-HDCP -Value "0"
        Show-RestartRequired
      }
      5 {
        Clear-Host
        Show-NvidiaSettings
        Wait-ForKeyPress -Message "Press any key to continue..." -UseReadHost
      }
      6 { return }
    }
  }
}

function Show-MSIMenu {
  Show-Menu -Title "MSI Mode Configuration" -Options @(
    "MSI Mode: On (Recommended)"
    "MSI Mode: Off"
    "Back to Main Menu"
  )

  $choice = Get-MenuChoice -Min 1 -Max 3

  switch ($choice) {
    1 {
      Set-MSIMode -Enable $true
      Write-Host ""
      Show-RestartRequired
    }
    2 {
      Set-MSIMode -Enable $false
      Write-Host ""
      Show-RestartRequired
    }
    3 { return }
  }
}

function Show-EDIDMenu {
  while ($true) {
    Show-Menu -Title "EDID Override Manager" -Options @(
      "Apply EDID Override (Fix stuttering)"
      "Remove EDID Override"
      "View Current Status"
      "Back to Main Menu"
    )

    $choice = Get-MenuChoice -Min 1 -Max 4

    Clear-Host

    switch ($choice) {
      1 {
        Set-EDIDOverride
        Write-Host ""
        Show-RestartRequired
      }
      2 {
        Remove-EDIDOverride
        Write-Host ""
        Show-RestartRequired
      }
      3 {
        Show-EDIDStatus
        Wait-ForKeyPress -Message "Press Enter to continue..." -UseReadHost
      }
      4 { return }
    }
  }
}

function Show-GamingDisplayMenu {
  while ($true) {
    Show-Menu -Title "Gaming Display Optimizations" -Options @(
      "Fullscreen Optimizations: FSO (Default)"
      "Fullscreen Exclusive: FSE"
      "Multiplane Overlay: On"
      "Multiplane Overlay: Off"
      "Multiplane Overlay: Default"
      "View Current Settings"
      "Back to Main Menu"
    )

    $choice = Get-MenuChoice -Min 1 -Max 7

    switch ($choice) {
      1 {
        Set-FullscreenMode -Mode 'FSO'
        Write-Host ""
        Wait-ForKeyPress -Message "Press any key to continue..."
      }
      2 {
        Set-FullscreenMode -Mode 'FSE'
        Write-Host ""
        Wait-ForKeyPress -Message "Press any key to continue..."
      }
      3 {
        Set-MultiPlaneOverlay -Mode 'Enabled'
        Write-Host ""
        Show-RestartRequired
      }
      4 {
        Set-MultiPlaneOverlay -Mode 'Disabled'
        Write-Host ""
        Show-RestartRequired
      }
      5 {
        Set-MultiPlaneOverlay -Mode 'Default'
        Write-Host ""
        Show-RestartRequired
      }
      6 {
        Show-GamingDisplayStatus
        Wait-ForKeyPress -Message "Press any key to continue..."
      }
      7 { return }
    }
  }
}
#endregion

# Main program loop
while ($true) {
  Show-MainMenu
  $choice = Get-MenuChoice -Min 1 -Max 5

  switch ($choice) {
    1 { Show-NvidiaMenu }
    2 { Show-MSIMenu }
    3 { Show-EDIDMenu }
    4 { Show-GamingDisplayMenu }
    5 { exit }
  }
}
