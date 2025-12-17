# settings.ps1 - System Performance Settings Manager
# Optimizes various Windows settings for gaming and performance
#
# ⚠️ DEPRECATION NOTICE ⚠️
# This script has been superseded by system-settings-manager.ps1
# Please use: system-settings-manager.ps1 for all system settings

#Requires -RunAsAdministrator

# Import common functions
. "$PSScriptRoot\Common.ps1"

# Request admin elevation
Request-AdminElevation

# Initialize console UI
Initialize-ConsoleUI -Title "System Performance Settings (Administrator)"

# Show deprecation warning
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host "                    DEPRECATION NOTICE                     " -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "This script has been replaced by: " -ForegroundColor Cyan -NoNewline
Write-Host "system-settings-manager.ps1" -ForegroundColor Green
Write-Host ""
Write-Host "The unified System Settings Manager provides performance" -ForegroundColor Cyan
Write-Host "settings along with keyboard shortcut management." -ForegroundColor Cyan
Write-Host ""
Write-Host "Please use system-settings-manager.ps1 for better functionality." -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Enter to continue with this legacy script or Ctrl+C to exit..."
Read-Host

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

function Restore-DefaultSettings {
    <#
    .SYNOPSIS
        Restores default Windows settings
    #>
    Clear-Host
    Write-Host "Restoring Default Settings..." -ForegroundColor Cyan
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
    Write-Host "Default settings restored successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Some settings require a system restart to take effect." -ForegroundColor Yellow
}

# Main menu
Show-Menu -Title "System Performance Settings" -Options @(
    "Apply Performance Optimizations"
    "Restore Default Settings"
    "Exit"
)

$choice = Get-MenuChoice -Min 1 -Max 3

switch ($choice) {
    1 {
        Set-PerformanceSettings
        Wait-ForKeyPress -Message "Press Enter to continue..." -UseReadHost
    }
    2 {
        Restore-DefaultSettings
        Wait-ForKeyPress -Message "Press Enter to continue..." -UseReadHost
    }
    3 {
        exit
    }
}
