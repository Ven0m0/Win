# edid-manager.ps1 - EDID Override Manager
# Manages EDID overrides for all monitors to fix display driver stuttering bugs

#Requires -RunAsAdministrator

# Import common functions
. "$PSScriptRoot\Common.ps1"

# Request admin elevation
Request-AdminElevation

# Initialize console UI
Initialize-ConsoleUI -Title "EDID Override Manager (Administrator)"

# Constants
$REG_LOCATION = 'HKLM\SYSTEM\CurrentControlSet\Enum\'
$EDID_HEX = '02030400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f7'

function Set-EDIDOverride {
    <#
    .SYNOPSIS
        Applies EDID override to all monitors
    #>
    $monitors = Get-MonitorInstances

    if ($monitors.Count -eq 0) {
        Write-Host "No monitors detected!" -ForegroundColor Yellow
        return
    }

    Write-Host "Applying EDID Override..." -ForegroundColor Cyan
    Write-Host ""

    foreach ($monitor in $monitors) {
        $name = $monitor -split '\\'
        Write-Host "  Applying override for: $($name[1])" -ForegroundColor Green
        $regPath = "$REG_LOCATION$monitor\Device Parameters\EDID_OVERRIDE"
        Set-RegistryValue -Path $regPath -Name '1' -Type REG_BINARY -Data $EDID_HEX
    }

    Write-Host ""
    Write-Host "EDID override applied successfully to $($monitors.Count) monitor(s)." -ForegroundColor Green
}

function Remove-EDIDOverride {
    <#
    .SYNOPSIS
        Removes EDID override from all monitors
    #>
    $monitors = Get-MonitorInstances

    if ($monitors.Count -eq 0) {
        Write-Host "No monitors detected!" -ForegroundColor Yellow
        return
    }

    Write-Host "Removing EDID Override..." -ForegroundColor Cyan
    Write-Host ""

    foreach ($monitor in $monitors) {
        $name = $monitor -split '\\'
        Write-Host "  Removing override for: $($name[1])" -ForegroundColor Green
        $regPath = "$REG_LOCATION$monitor\Device Parameters\EDID_OVERRIDE"
        Remove-RegistryValue -Path $regPath
    }

    Write-Host ""
    Write-Host "EDID override removed successfully from $($monitors.Count) monitor(s)." -ForegroundColor Green
}

function Show-EDIDStatus {
    <#
    .SYNOPSIS
        Displays current EDID override status for all monitors
    #>
    $monitors = Get-MonitorInstances

    if ($monitors.Count -eq 0) {
        Write-Host "No monitors detected!" -ForegroundColor Yellow
        return
    }

    Write-Host "Current EDID Override Status:" -ForegroundColor Cyan
    Write-Host ""

    foreach ($monitor in $monitors) {
        $name = $monitor -split '\\'
        $regPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$monitor\Device Parameters\EDID_OVERRIDE"

        Write-Host "Monitor: $($name[1])" -ForegroundColor Yellow

        if (Test-Path $regPath) {
            try {
                $override = Get-ItemProperty -Path $regPath -Name '1' -ErrorAction Stop
                Write-Host "  Status: Override applied" -ForegroundColor Green
                Write-Host "  Value: Present" -ForegroundColor Green
            } catch {
                Write-Host "  Status: No override" -ForegroundColor Gray
            }
        } else {
            Write-Host "  Status: No override" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

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
