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
  Show-NvidiaGpuSettings -Title "Current NVIDIA GPU Settings:" -Setting "P0State" -GpuPaths $gpuPaths
}

function Set-HDCP {
  param([string]$Value)

  $gpuPaths = Set-NvidiaGpuRegistryValue -Name "RMHdcpKeyglobZero" -Type REG_DWORD -Data $Value

  Clear-Host
  Write-Host "HDCP: $(if ($Value -eq '1') { 'Off' } else { 'Default' })" -ForegroundColor $(if ($Value -eq '1') { 'Green' } else { 'Cyan' })
  Show-NvidiaGpuSettings -Title "Current NVIDIA GPU Settings:" -Setting "HDCP" -GpuPaths $gpuPaths
}
#endregion

#region Gaming Display Settings
# Gaming display functions available from Common.ps1:
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
    $sigStatus = Get-NvidiaSignatureStatus
    $isSigEnabled = $sigStatus.GlobalOverride -and $sigStatus.ServiceOverride

    Show-Menu -Title "NVIDIA GPU Settings" -Options @(
      "P0 State (Highest Performance): On"
      "P0 State (Highest Performance): Default"
      "HDCP (Content Protection): Off"
      "HDCP (Content Protection): Default"
      "Driver Signature Override: $(if ($isSigEnabled) { 'Enabled' } else { 'Disabled' })"
      "XtremeG Custom Driver Installer"
      "View Current Settings"
      "Back to Main Menu"
    )

    $choice = Get-MenuChoice -Min 1 -Max 8

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
        Set-NvidiaSignatureOverride -Enabled (-not $isSigEnabled)
        Show-RestartRequired
      }
      6 {
        $installerPath = "$PSScriptRoot\..\user\.dotfiles\config\nvidia\xtremeg-installer.ps1"
        if (Test-Path $installerPath) {
          Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $installerPath) -Verb RunAs
        } else {
          Write-Host "XtremeG Installer not found at: $installerPath" -ForegroundColor Red
          Wait-ForKeyPress
        }
      }
      7 {
        Clear-Host
        Show-NvidiaGpuSettings
        Write-Host "Driver Signature Override Status:" -ForegroundColor Yellow
        Write-Host "  Global Override: $(if ($sigStatus.GlobalOverride) { 'Enabled' } else { 'Disabled' })" -ForegroundColor $(if ($sigStatus.GlobalOverride) { 'Green' } else { 'Gray' })
        Write-Host "  Service Override: $(if ($sigStatus.ServiceOverride) { 'Enabled' } else { 'Disabled' })" -ForegroundColor $(if ($sigStatus.ServiceOverride) { 'Green' } else { 'Gray' })
        Write-Host ""
        Wait-ForKeyPress -Message "Press any key to continue..." -UseReadHost
      }
      8 { return }
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
