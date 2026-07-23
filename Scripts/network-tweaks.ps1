#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    TCP/IP tuning, NIC power management, and DNS cache tuning.
.DESCRIPTION
    Ported from Windows-Tweaks.ps1's Optimize-Network function (originally
    pulled from Awesome-Windows-Laptop-Network-Optimizer/). NetworkThrottlingIndex
    is intentionally not set here -- Scripts/reg/apply-alchemy-tweaks.ps1 already
    sets it (=10); setting it again here to a different value (0xffffffff, fully
    disabled) would just make the two scripts fight over the same key.
.PARAMETER Restore
    Restore default TCP/IP, NIC power management, and DNS cache settings.
.PARAMETER NoRestorePoint
    Skip creating a restore point before applying changes.
.EXAMPLE
    .\network-tweaks.ps1
    Applies the TCP/IP, NIC power management, and DNS cache tweaks.
#>
param(
    [switch]$Restore,
    [switch]$NoRestorePoint
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

. "$PSScriptRoot/Common.ps1"

function Set-NetworkTweak {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Host "Applying network tweaks (TCP/IP, NIC power saving, DNS)..." -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  [*] Tuning TCP/IP parameters..." -ForegroundColor Gray
    $tcp = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    foreach ($kv in @{
            Tcp1323Opts               = "3"
            EnablePMTUDiscovery       = "1"
            EnableTCPA                = "1"
            TcpMaxDataRetransmissions = "5"
            MaxUserPort               = "65534"
            TcpTimedWaitDelay         = "30"
        }.GetEnumerator()) {
        Set-RegistryValue -Path $tcp -Name $kv.Key -Type REG_DWORD -Data $kv.Value
    }

    Write-Host "  [*] Disabling NIC power management..." -ForegroundColor Gray
    Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
        Disable-NetAdapterPowerManagement -Name $_.Name -ErrorAction SilentlyContinue
        foreach ($prop in 'Energy Efficient Ethernet', 'Green Ethernet') {
            Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName $prop -DisplayValue 'Disabled' -ErrorAction SilentlyContinue
        }
    }

    Write-Host "  [*] Extending DNS cache TTL..." -ForegroundColor Gray
    Set-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" `
        -Name "MaxCacheEntryTtlLimit" -Type REG_DWORD -Data "86400"
    ipconfig /flushdns | Out-Null

    Write-Host ""
    Write-Host "Network tweaks applied." -ForegroundColor Green
    Write-Host "Note: Some settings require a system restart to take effect." -ForegroundColor Yellow
}

function Restore-DefaultNetworkTweak {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Host "Restoring default network settings..." -ForegroundColor Cyan
    Write-Host ""

    $tcp = "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
    foreach ($name in 'Tcp1323Opts', 'EnablePMTUDiscovery', 'EnableTCPA', 'TcpMaxDataRetransmissions', 'MaxUserPort',
        'TcpTimedWaitDelay') {
        Remove-RegistryValue -Path $tcp -Name $name
    }
    Remove-RegistryValue -Path "HKLM\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" -Name "MaxCacheEntryTtlLimit"

    Get-NetAdapter | Where-Object Status -eq 'Up' | ForEach-Object {
        Enable-NetAdapterPowerManagement -Name $_.Name -ErrorAction SilentlyContinue
        foreach ($prop in 'Energy Efficient Ethernet', 'Green Ethernet') {
            Set-NetAdapterAdvancedProperty -Name $_.Name -DisplayName $prop -DisplayValue 'Enabled' -ErrorAction SilentlyContinue
        }
    }

    Write-Host ""
    Write-Host "Default network settings restored." -ForegroundColor Green
}

Request-AdminElevation

if (-not $Restore -and -not $NoRestorePoint) {
    New-RestorePoint -Description "Before network-tweaks"
}

if ($Restore) {
    Restore-DefaultNetworkTweak
}
else {
    Set-NetworkTweak
}
