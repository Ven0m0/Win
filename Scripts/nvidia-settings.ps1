# nvidia-settings.ps1 - Unified NVIDIA GPU Registry Settings Manager
# Combines P0-State and HDCP settings in one optimized script

#Requires -RunAsAdministrator

# Import common functions
. "$PSScriptRoot\Common.ps1"

# Request admin elevation
Request-AdminElevation

# Initialize console UI
Initialize-ConsoleUI -Title "NVIDIA GPU Settings Manager (Administrator)"

# Main menu
function Show-MainMenu {
    Show-Menu -Title "NVIDIA GPU Settings" -Options @(
        "P0 State (Highest Performance): On"
        "P0 State (Highest Performance): Default"
        "HDCP (Content Protection): Off"
        "HDCP (Content Protection): Default"
        "View Current Settings"
        "Exit"
    )
}

function Set-P0State {
    param([string]$Value)

    $gpuPaths = Set-NvidiaGpuRegistryValue -Name "DisableDynamicPstate" -Type REG_DWORD -Data $Value
    Clear-Host
    Write-Host "P0 State: $(if ($Value -eq '1') { 'On' } else { 'Default' })" -ForegroundColor $(if ($Value -eq '1') { 'Green' } else { 'Cyan' })
    Show-NvidiaGpuSettings -Setting "P0State" -GpuPaths $gpuPaths -Title "Current GPU Settings:"
}

function Set-HDCP {
    param([string]$Value)

    $gpuPaths = Set-NvidiaGpuRegistryValue -Name "RMHdcpKeyglobZero" -Type REG_DWORD -Data $Value
    Clear-Host
    Write-Host "HDCP: $(if ($Value -eq '1') { 'Off' } else { 'Default' })" -ForegroundColor $(if ($Value -eq '1') { 'Green' } else { 'Cyan' })
    Show-NvidiaGpuSettings -Setting "HDCP" -GpuPaths $gpuPaths -Title "Current GPU Settings:"
}

function Show-CurrentSettings {
    param([string]$Setting = "All")

    Show-NvidiaGpuSettings -Title "Current GPU Settings:" -Setting $Setting
}

# Main loop
while ($true) {
    Show-MainMenu
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
            Show-CurrentSettings
            Wait-ForKeyPress -Message "Press any key to continue..." -UseReadHost
        }
        6 {
            exit
        }
    }
}
