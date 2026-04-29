#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0

    # Dot source Common.ps1 first so we get the real commands, then we mock them
    . "$PSScriptRoot/Common.ps1"

    # Mock Common.ps1 functions that might get executed during dot sourcing or function calls
    Mock Set-RegistryValue { }
    Mock Remove-RegistryValue { }
    Mock Write-Host { }
    Mock Clear-Host { }
    Mock Wait-ForKeyPress { }
    Mock Request-AdminElevation { }
    Mock Initialize-ConsoleUI { }
    Mock Show-Menu { }
    Mock Get-MenuChoice { return 3 } # Exit loop or menu
    Mock Show-RestartRequired { }

    # Mock other commands
    function Disable-NetAdapterBinding { param($Name, $ComponentID, $ErrorAction) }
    function Enable-NetAdapterBinding { param($Name, $ComponentID, $ErrorAction) }
    Mock Disable-NetAdapterBinding { }
    Mock Enable-NetAdapterBinding { }

    function powercfg {}
    Mock powercfg { }

    # Safely dot source the script now that we use the execution guard pattern
    . "$PSScriptRoot/system-settings-manager.ps1"
}

Describe "System Settings Manager" {

    Context "Performance Settings" {
        It "Should call Set-RegistryValue multiple times for gaming optimization" {
            Set-PerformanceSettings

            # Check a few specific registry values
            Should -Invoke Set-RegistryValue -ParameterFilter { $Name -eq "HibernateEnabled" -and $Data -eq "0" }
            Should -Invoke Set-RegistryValue -ParameterFilter { $Name -eq "PowerThrottlingOff" -and $Data -eq "1" }
            Should -Invoke Set-RegistryValue -ParameterFilter { $Name -eq "WHQLSettings" -and $Data -eq "1" }

            # Check network binding
            Should -Invoke Disable-NetAdapterBinding \
                -ParameterFilter { $Name -eq "*" -and $ComponentID -eq "ms_server" }
        }

        It "Should call Set-RegistryValue to restore defaults" {
            Restore-DefaultPerformanceSettings

            Should -Invoke Set-RegistryValue -ParameterFilter { $Name -eq "HibernateEnabled" -and $Data -eq "1" }
            Should -Invoke Remove-RegistryValue -ParameterFilter { $Name -eq "PowerThrottlingOff" }

            # Check network binding
            Should -Invoke Enable-NetAdapterBinding -ParameterFilter { $Name -eq "*" -and $ComponentID -eq "ms_server" }
        }
    }

    Context "Keyboard Shortcuts" {
        It "Should disable keyboard shortcuts" {
            Disable-KeyboardShortcuts

            Should -Invoke Set-RegistryValue -ParameterFilter { $Path -match "hidserv$" -and $Data -eq "4" }
            Should -Invoke Set-RegistryValue -ParameterFilter { $Name -eq "NoWinKeys" -and $Data -eq "1" }
            Should -Invoke Set-RegistryValue -ParameterFilter { $Name -eq "DisabledHotkeys" -and $Data -eq "1" }
            Should -Invoke Set-RegistryValue -ParameterFilter { $Name -eq "Scancode Map" }
        }

        It "Should enable keyboard shortcuts" {
            Enable-KeyboardShortcuts

            Should -Invoke Set-RegistryValue -ParameterFilter { $Path -match "hidserv$" -and $Data -eq "3" }
            Should -Invoke Remove-RegistryValue -ParameterFilter { $Name -eq "NoWinKeys" }
            Should -Invoke Remove-RegistryValue -ParameterFilter { $Name -eq "DisabledHotkeys" }
            Should -Invoke Remove-RegistryValue -ParameterFilter { $Name -eq "Scancode Map" }
        }
    }
}
