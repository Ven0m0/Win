# gaming-display.ps1 - Gaming Display Optimizations Manager
# Manages Fullscreen Optimizations (FSO/FSE) and Multiplane Overlay (MPO) settings

#Requires -RunAsAdministrator

# Import common functions
. "$PSScriptRoot\Common.ps1"

# Request admin elevation
Request-AdminElevation

# Initialize console UI
Initialize-ConsoleUI -Title "Gaming Display Optimizations (Administrator)"

function Set-FullscreenMode {
    <#
    .SYNOPSIS
        Configures fullscreen mode (FSO or FSE)
    .PARAMETER Mode
        'FSO' for Fullscreen Optimizations or 'FSE' for Fullscreen Exclusive
    #>
    param([string]$Mode)

    Clear-Host

    if ($Mode -eq 'FSO') {
        # Fullscreen Optimizations (Default)
        Set-RegistryValue -Path "HKCU\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Type REG_DWORD -Data "0"
        Set-RegistryValue -Path "HKCU\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Type REG_DWORD -Data "0"
        Remove-RegistryValue -Path "HKCU\System\GameConfigStore" -Name "GameDVR_FSEBehavior"
        Set-RegistryValue -Path "HKCU\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Type REG_DWORD -Data "0"

        Write-Host "Fullscreen Optimizations (FSO) enabled." -ForegroundColor Green
    } else {
        # Fullscreen Exclusive
        Set-RegistryValue -Path "HKCU\System\GameConfigStore" -Name "GameDVR_DXGIHonorFSEWindowsCompatible" -Type REG_DWORD -Data "1"
        Set-RegistryValue -Path "HKCU\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -Type REG_DWORD -Data "2"
        Set-RegistryValue -Path "HKCU\System\GameConfigStore" -Name "GameDVR_FSEBehavior" -Type REG_DWORD -Data "2"
        Set-RegistryValue -Path "HKCU\System\GameConfigStore" -Name "GameDVR_HonorUserFSEBehaviorMode" -Type REG_DWORD -Data "1"

        Write-Host "Fullscreen Exclusive (FSE) enabled." -ForegroundColor Green
        Write-Host ""
        Write-Host "Additional steps may be required:" -ForegroundColor Yellow
        Write-Host "  1. Right-click game.exe"
        Write-Host "  2. Select Properties"
        Write-Host "  3. Go to Compatibility tab"
        Write-Host "  4. Check 'Disable fullscreen optimizations'"
        Write-Host "  5. Click Apply"
        Write-Host ""
        Write-Host "Note: DX12 engines do not support fullscreen exclusive mode." -ForegroundColor Cyan
    }
}

function Set-MultiPlaneOverlay {
    <#
    .SYNOPSIS
        Configures Multiplane Overlay and windowed game optimizations
    .PARAMETER Mode
        'Enabled', 'Disabled', or 'Default'
    #>
    param([string]$Mode)

    Clear-Host

    switch ($Mode) {
        'Enabled' {
            # Enable multiplane overlay
            Remove-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode"

            # Enable optimizations for windowed games
            Set-RegistryValue -Path "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -Type REG_SZ -Data "VRROptimizeEnable=0;SwapEffectUpgradeEnable=1;"

            Write-Host "Multiplane Overlay: Enabled" -ForegroundColor Green
            Write-Host "Windowed Game Optimizations: Enabled" -ForegroundColor Green
        }
        'Disabled' {
            # Disable multiplane overlay
            Set-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode" -Type REG_DWORD -Data "5"

            # Disable optimizations for windowed games
            Set-RegistryValue -Path "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -Type REG_SZ -Data "VRROptimizeEnable=0;SwapEffectUpgradeEnable=0;"

            Write-Host "Multiplane Overlay: Disabled" -ForegroundColor Yellow
            Write-Host "Windowed Game Optimizations: Disabled" -ForegroundColor Yellow
        }
        'Default' {
            # Enable multiplane overlay (default)
            Remove-RegistryValue -Path "HKLM\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode"

            # Disable optimizations for windowed games
            Set-RegistryValue -Path "HKCU\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -Type REG_SZ -Data "VRROptimizeEnable=0;SwapEffectUpgradeEnable=0;"

            Write-Host "Multiplane Overlay: Default (Enabled)" -ForegroundColor Cyan
            Write-Host "Windowed Game Optimizations: Disabled" -ForegroundColor Cyan
        }
    }
}

function Show-CurrentStatus {
    <#
    .SYNOPSIS
        Displays current gaming display settings
    #>
    Clear-Host
    Write-Host "Current Gaming Display Settings:" -ForegroundColor Cyan
    Write-Host ""

    # Check FSO/FSE settings
    try {
        $fseMode = (Get-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_FSEBehaviorMode" -ErrorAction Stop).GameDVR_FSEBehaviorMode
        if ($fseMode -eq 2) {
            Write-Host "Fullscreen Mode: FSE (Fullscreen Exclusive)" -ForegroundColor Green
        } else {
            Write-Host "Fullscreen Mode: FSO (Fullscreen Optimizations)" -ForegroundColor Green
        }
    } catch {
        Write-Host "Fullscreen Mode: Not configured" -ForegroundColor Gray
    }

    # Check MPO settings
    try {
        $mpoTest = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\Dwm" -Name "OverlayTestMode" -ErrorAction Stop).OverlayTestMode
        if ($mpoTest -eq 5) {
            Write-Host "Multiplane Overlay: Disabled" -ForegroundColor Yellow
        } else {
            Write-Host "Multiplane Overlay: Enabled" -ForegroundColor Green
        }
    } catch {
        Write-Host "Multiplane Overlay: Default (Enabled)" -ForegroundColor Green
    }

    # Check DirectX settings
    try {
        $dxSettings = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -Name "DirectXUserGlobalSettings" -ErrorAction Stop).DirectXUserGlobalSettings
        if ($dxSettings -like '*SwapEffectUpgradeEnable=1*') {
            Write-Host "Windowed Game Optimizations: Enabled" -ForegroundColor Green
        } else {
            Write-Host "Windowed Game Optimizations: Disabled" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Windowed Game Optimizations: Not configured" -ForegroundColor Gray
    }

    Write-Host ""
}

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
            Write-Host "Press any key to continue..." -ForegroundColor Cyan
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        2 {
            Set-FullscreenMode -Mode 'FSE'
            Write-Host ""
            Write-Host "Press any key to continue..." -ForegroundColor Cyan
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        3 {
            Set-MultiPlaneOverlay -Mode 'Enabled'
            Write-Host ""
            Write-Host "Restart required to apply changes..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        4 {
            Set-MultiPlaneOverlay -Mode 'Disabled'
            Write-Host ""
            Write-Host "Restart required to apply changes..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        5 {
            Set-MultiPlaneOverlay -Mode 'Default'
            Write-Host ""
            Write-Host "Restart required to apply changes..." -ForegroundColor Yellow
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        6 {
            Show-CurrentStatus
            Write-Host "Press any key to continue..." -ForegroundColor Cyan
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        }
        7 {
            exit
        }
    }
}
