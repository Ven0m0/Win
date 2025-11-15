# keyboard-shortcuts.ps1 - Windows Keyboard Shortcuts Manager
# Enables or disables keyboard shortcuts to prevent accidental game interruptions

#Requires -RunAsAdministrator

# Import common functions
. "$PSScriptRoot\Common.ps1"

# Request admin elevation
Request-AdminElevation

# Initialize console UI
Initialize-ConsoleUI -Title "Keyboard Shortcuts Manager (Administrator)"

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
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
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
    Write-Host ""
    Write-Host "Restart required to apply changes..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
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
    Write-Host ""
    Write-Host "Restart required to apply changes..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Main menu
Show-Menu -Title "" -Options @(
    "Keyboard Shortcuts: Off"
    "Keyboard Shortcuts: Default"
)

$choice = Get-MenuChoice -Min 1 -Max 2

switch ($choice) {
    1 { Disable-KeyboardShortcuts }
    2 { Enable-KeyboardShortcuts }
}
