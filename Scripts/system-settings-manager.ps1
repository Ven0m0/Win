# system-settings-manager.ps1 - Unified System Settings Manager
# Combines performance settings and keyboard shortcuts management
# Replaces: settings.ps1, keyboard-shortcuts.ps1

#Requires -RunAsAdministrator

# Import common functions
. "$PSScriptRoot\Common.ps1"

# Request admin elevation
Request-AdminElevation

# Initialize console UI
Initialize-ConsoleUI -Title "System Settings Manager (Administrator)"

#region Performance Settings
function Set-PerformanceSettings {
  <#
  .SYNOPSIS
      Applies optimized performance settings for gaming
  #>
  Clear-Host
  Write-Host "Applying Performance Settings..." -ForegroundColor Cyan
  Write-Host ""

  # Disable hibernate
  Write-Host "  [*] Disabling hibernate..." -ForegroundColor Gray
  powercfg /hibernate off 2>&1 | Out-Null
  Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled" -Type REG_DWORD -Data "0"
  Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabledDefault" -Type REG_DWORD -Data "0"

  # Disable lock option
  Write-Host "  [*] Disabling lock option..." -ForegroundColor Gray
  Set-RegistryValue -Path "HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name "ShowLockOption" -Type REG_DWORD -Data "0"

  # Disable sleep option
  Write-Host "  [*] Disabling sleep option..." -ForegroundColor Gray
  Set-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name "ShowSleepOption" -Type REG_DWORD -Data "0"

  # Disable fast boot
  Write-Host "  [*] Disabling fast boot..." -ForegroundColor Gray
  Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Type REG_DWORD -Data "0"

  # Disable power throttling
  Write-Host "  [*] Disabling power throttling..." -ForegroundColor Gray
  Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Type REG_DWORD -Data "1"

  # Enable USB overclock with secure boot
  Write-Host "  [*] Enabling USB overclock compatibility..." -ForegroundColor Gray
  Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy" -Name "WHQLSettings" -Type REG_DWORD -Data "1"

  # Disable raw mouse throttling
  Write-Host "  [*] Disabling raw mouse throttling..." -ForegroundColor Gray
  Set-RegistryValue -Path "HKCU\Control Panel\Mouse" -Name "RawMouseThrottleEnabled" -Type REG_DWORD -Data "0"

  # Optimize network adapter (disable server binding)
  Write-Host "  [*] Optimizing network adapter..." -ForegroundColor Gray
  $ProgressPreference = 'SilentlyContinue'
  Disable-NetAdapterBinding -Name "*" -ComponentID ms_server -ErrorAction SilentlyContinue

  Write-Host ""
  Write-Host "Performance settings applied successfully!" -ForegroundColor Green
  Write-Host ""
  Write-Host "Note: Some settings require a system restart to take effect." -ForegroundColor Yellow
}

function Restore-DefaultPerformanceSettings {
  <#
  .SYNOPSIS
      Restores default Windows performance settings
  #>
  Clear-Host
  Write-Host "Restoring Default Performance Settings..." -ForegroundColor Cyan
  Write-Host ""

  # Enable hibernate
  Write-Host "  [*] Enabling hibernate..." -ForegroundColor Gray
  Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabled" -Type REG_DWORD -Data "1"
  Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power" -Name "HibernateEnabledDefault" -Type REG_DWORD -Data "1"

  # Enable lock option
  Write-Host "  [*] Enabling lock option..." -ForegroundColor Gray
  Set-RegistryValue -Path "HKLM\Software\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name "ShowLockOption" -Type REG_DWORD -Data "1"

  # Enable sleep option
  Write-Host "  [*] Enabling sleep option..." -ForegroundColor Gray
  Set-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings" -Name "ShowSleepOption" -Type REG_DWORD -Data "1"

  # Enable fast boot
  Write-Host "  [*] Enabling fast boot..." -ForegroundColor Gray
  Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -Type REG_DWORD -Data "1"

  # Remove power throttling override
  Write-Host "  [*] Removing power throttling override..." -ForegroundColor Gray
  Remove-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff"

  # Restore USB settings
  Write-Host "  [*] Restoring USB settings..." -ForegroundColor Gray
  Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\CI\Policy" -Name "WHQLSettings" -Type REG_DWORD -Data "0"

  # Re-enable raw mouse throttling
  Write-Host "  [*] Re-enabling raw mouse throttling..." -ForegroundColor Gray
  Remove-RegistryValue -Path "HKCU\Control Panel\Mouse" -Name "RawMouseThrottleEnabled"

  # Restore network adapter
  Write-Host "  [*] Restoring network adapter..." -ForegroundColor Gray
  $ProgressPreference = 'SilentlyContinue'
  Enable-NetAdapterBinding -Name "*" -ComponentID ms_server -ErrorAction SilentlyContinue

  Write-Host ""
  Write-Host "Default performance settings restored successfully!" -ForegroundColor Green
  Write-Host ""
  Write-Host "Note: Some settings require a system restart to take effect." -ForegroundColor Yellow
}
#endregion

#region Keyboard Shortcuts
function Disable-KeyboardShortcuts {
  <#
  .SYNOPSIS
      Disables all keyboard shortcuts for gaming
  #>
  Clear-Host
  Write-Host "Keyboard Shortcuts: Off" -ForegroundColor Red
  Write-Host ""
  Write-Host "  - Disables all keyboard shortcuts" -ForegroundColor Red
  Write-Host "  - Prevents tabbing out of games" -ForegroundColor Red
  Write-Host "  - Cut/copy/paste will still function" -ForegroundColor Red
  Write-Host "  - ESC key rebound to =" -ForegroundColor Red
  Write-Host ""
  Wait-ForKeyPress
  Clear-Host

  # Disable media keys (Human Interface Device Service)
  Set-RegistryValue -Path "HKLM\SYSTEM\ControlSet001\Services\hidserv" -Name "Start" -Type REG_DWORD -Data "4"

  # Disable Windows key hotkeys
  Set-RegistryValue -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoWinKeys" -Type REG_DWORD -Data "1"

  # Disable shortcut keys
  Set-RegistryValue -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DisabledHotkeys" -Type REG_DWORD -Data "1"

  # Disable Win, Alt, ESC keys (ESC rebound to =)
  Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "Scancode Map" -Type REG_BINARY -Data "00000000000000000700000000005be000005ce000003800000038e00000010001000d0000000000"

  Clear-Host
  Write-Host "Keyboard shortcuts disabled successfully!" -ForegroundColor Green
}

function Enable-KeyboardShortcuts {
  <#
  .SYNOPSIS
      Restores default keyboard shortcuts
  #>
  Clear-Host

  # Enable media keys (Human Interface Device Service)
  Set-RegistryValue -Path "HKLM\SYSTEM\ControlSet001\Services\hidserv" -Name "Start" -Type REG_DWORD -Data "3"

  # Enable Windows key hotkeys
  Remove-RegistryValue -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoWinKeys"

  # Enable shortcut keys
  Remove-RegistryValue -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "DisabledHotkeys"

  # Enable Win, Alt, ESC keys
  Remove-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layout" -Name "Scancode Map"

  Clear-Host
  Write-Host "Keyboard shortcuts restored to default!" -ForegroundColor Green
}
#endregion

#region Menu System
function Show-MainMenu {
  Show-Menu -Title "System Settings Manager - Select Category" -Options @(
    "Performance Optimizations"
    "Keyboard Shortcuts"
    "Exit"
  )
}

function Show-PerformanceMenu {
  Show-Menu -Title "Performance Optimizations" -Options @(
    "Apply Performance Optimizations"
    "Restore Default Settings"
    "Back to Main Menu"
  )

  $choice = Get-MenuChoice -Min 1 -Max 3

  switch ($choice) {
    1 {
      Set-PerformanceSettings
      Wait-ForKeyPress -Message "Press Enter to continue..." -UseReadHost
    }
    2 {
      Restore-DefaultPerformanceSettings
      Wait-ForKeyPress -Message "Press Enter to continue..." -UseReadHost
    }
    3 { return }
  }
}

function Show-KeyboardMenu {
  Show-Menu -Title "Keyboard Shortcuts" -Options @(
    "Keyboard Shortcuts: Off"
    "Keyboard Shortcuts: Default"
    "Back to Main Menu"
  )

  $choice = Get-MenuChoice -Min 1 -Max 3

  switch ($choice) {
    1 {
      Disable-KeyboardShortcuts
      Write-Host ""
      Show-RestartRequired
    }
    2 {
      Enable-KeyboardShortcuts
      Write-Host ""
      Show-RestartRequired
    }
    3 { return }
  }
}
#endregion

# Main program loop
while ($true) {
  Show-MainMenu
  $choice = Get-MenuChoice -Min 1 -Max 3

  switch ($choice) {
    1 { Show-PerformanceMenu }
    2 { Show-KeyboardMenu }
    3 { exit }
  }
}
