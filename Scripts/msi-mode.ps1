# msi-mode.ps1 - MSI (Message Signaled Interrupts) Mode Manager for GPUs
# Enables or disables MSI mode for all display adapters to improve interrupt handling

#Requires -RunAsAdministrator

# Import common functions
. "$PSScriptRoot\Common.ps1"

# Request admin elevation
Request-AdminElevation

# Initialize console UI
Initialize-ConsoleUI -Title "MSI Mode Manager (Administrator)"

function Set-MSIMode {
    <#
    .SYNOPSIS
        Configures MSI mode for all GPU devices
    .PARAMETER Enable
        $true to enable MSI mode, $false to disable
    #>
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

# Main menu
Show-Menu -Title "MSI Mode Configuration" -Options @(
    "MSI Mode: On (Recommended)"
    "MSI Mode: Off"
    "Exit"
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
    3 {
        exit
    }
}
