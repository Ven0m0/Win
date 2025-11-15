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

function Get-GpuPaths {
    Get-NvidiaGpuRegistryPaths
}

function Set-P0State {
    param([string]$Value)

    $gpuPaths = Get-GpuPaths
    foreach ($path in $gpuPaths) {
        Set-RegistryValue -Path $path -Name "DisableDynamicPstate" -Type REG_DWORD -Data $Value
    }

    Clear-Host
    Write-Host "P0 State: $(if ($Value -eq '1') { 'On' } else { 'Default' })" -ForegroundColor $(if ($Value -eq '1') { 'Green' } else { 'Cyan' })
    Show-CurrentSettings -Setting "P0State"
}

function Set-HDCP {
    param([string]$Value)

    $gpuPaths = Get-GpuPaths
    foreach ($path in $gpuPaths) {
        Set-RegistryValue -Path $path -Name "RMHdcpKeyglobZero" -Type REG_DWORD -Data $Value
    }

    Clear-Host
    Write-Host "HDCP: $(if ($Value -eq '1') { 'Off' } else { 'Default' })" -ForegroundColor $(if ($Value -eq '1') { 'Green' } else { 'Cyan' })
    Show-CurrentSettings -Setting "HDCP"
}

function Show-CurrentSettings {
    param([string]$Setting = "All")

    $gpuPaths = Get-GpuPaths

    Write-Host ""
    Write-Host "Current GPU Settings:" -ForegroundColor Yellow
    Write-Host ""

    foreach ($path in $gpuPaths) {
        $gpuName = ($path -split '\\')[-1]
        Write-Host "GPU: $gpuName" -ForegroundColor Cyan

        if ($Setting -eq "All" -or $Setting -eq "P0State") {
            try {
                $p0Value = (Get-ItemProperty -Path "Registry::$path" -Name 'DisableDynamicPstate' -ErrorAction Stop).DisableDynamicPstate
                Write-Host "  P0 State (DisableDynamicPstate): $p0Value" -ForegroundColor Green
            } catch {
                Write-Host "  P0 State: Not configured" -ForegroundColor Gray
            }
        }

        if ($Setting -eq "All" -or $Setting -eq "HDCP") {
            try {
                $hdcpValue = (Get-ItemProperty -Path "Registry::$path" -Name 'RMHdcpKeyglobZero' -ErrorAction Stop).RMHdcpKeyglobZero
                Write-Host "  HDCP (RMHdcpKeyglobZero): $hdcpValue" -ForegroundColor Green
            } catch {
                Write-Host "  HDCP: Not configured" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }
}

# Main loop
while ($true) {
    Show-MainMenu
    $choice = Get-MenuChoice -Min 1 -Max 6

    switch ($choice) {
        1 {
            Set-P0State -Value "1"
            Write-Host "Restart required to apply changes..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        2 {
            Set-P0State -Value "0"
            Write-Host "Restart required to apply changes..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        3 {
            Set-HDCP -Value "1"
            Write-Host "Restart required to apply changes..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        4 {
            Set-HDCP -Value "0"
            Write-Host "Restart required to apply changes..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        5 {
            Clear-Host
            Show-CurrentSettings
            Write-Host "Press any key to continue..." -ForegroundColor Cyan
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        6 {
            exit
        }
    }
}
