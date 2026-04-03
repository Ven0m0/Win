# gaming-display.ps1 - Gaming Display Optimizations Manager
# Manages Fullscreen Optimizations (FSO/FSE) and Multiplane Overlay (MPO) settings

#Requires -RunAsAdministrator

# Import common functions
. "$PSScriptRoot\Common.ps1"

# Request admin elevation
Request-AdminElevation

# Initialize console UI
Initialize-ConsoleUI -Title "Gaming Display Optimizations (Administrator)"

# Main menu loop
while ($true) {
    Show-Menu -Title "Gaming Display Optimizations" -Options @(
        "Fullscreen Optimizations: FSO (Default)"
        "Fullscreen Exclusive: FSE"
        "Multiplane Overlay: On"
        "Multiplane Overlay: Off"
        "Multiplane Overlay: Default"
        "View Current Settings"
        "Exit"
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
        7 {
            exit
        }
    }
}
