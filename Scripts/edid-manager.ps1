# edid-manager.ps1 - EDID Override Manager
# Manages EDID overrides for all monitors to fix display driver stuttering bugs

#Requires -RunAsAdministrator

# Import common functions
. "$PSScriptRoot\Common.ps1"

# Request admin elevation
Request-AdminElevation

# Initialize console UI
Initialize-ConsoleUI -Title "EDID Override Manager (Administrator)"

# Main menu
while ($true) {
    Show-Menu -Title "EDID Override Manager" -Options @(
        "Apply EDID Override (Fix stuttering)"
        "Remove EDID Override"
        "View Current Status"
        "Exit"
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
        4 {
            exit
        }
    }
}
