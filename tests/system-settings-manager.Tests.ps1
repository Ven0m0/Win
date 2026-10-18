#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0

    # Dot source Common.ps1 first so we get the real commands, then we mock them
    . "$PSScriptRoot/../Scripts/Common.ps1"

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
    . "$PSScriptRoot/../Scripts/system-settings-manager.ps1"
}

Describe "System Settings Manager" {

    Context "Performance Settings" {
        It "Should call Set-RegistryValue multiple times for gaming optimization" {
            Set-PerformanceSetting

            # Check a few specific registry values
            Should -Invoke Set-RegistryValue -ParameterFilter { $Name -eq "HibernateEnabled" -and $Data -eq "0" }
            Should -Invoke Set-RegistryValue -ParameterFilter { $Name -eq "PowerThrottlingOff" -and $Data -eq "1" }
            Should -Invoke Set-RegistryValue -ParameterFilter { $Name -eq "WHQLSettings" -and $Data -eq "1" }

            # Check network binding
            Should -Invoke Disable-NetAdapterBinding `
                -ParameterFilter { $Name -eq "*" -and $ComponentID -eq "ms_server" }
        }

        It "Should call Set-RegistryValue to restore defaults" {
            Restore-DefaultPerformanceSetting

            Should -Invoke Set-RegistryValue -ParameterFilter { $Name -eq "HibernateEnabled" -and $Data -eq "1" }
            Should -Invoke Remove-RegistryValue -ParameterFilter { $Name -eq "PowerThrottlingOff" }

            # Check network binding
            Should -Invoke Enable-NetAdapterBinding -ParameterFilter { $Name -eq "*" -and $ComponentID -eq "ms_server" }
        }
    }
}

Describe "System Settings Manager - Explorer settings" {
    It "Set-ExplorerPerformanceSetting disables Start menu suggestions and spotlight" {
        Set-ExplorerPerformanceSetting

        Should -Invoke Set-RegistryValue -ParameterFilter {
            $Path -like '*ContentDeliveryManager' -and $Name -eq 'SilentInstalledAppsEnabled' -and $Data -eq '0'
        }
        Should -Invoke Set-RegistryValue -ParameterFilter {
            $Name -eq 'DisableWindowsSpotlightFeatures' -and $Data -eq '1'
        }
    }

    It "Set-ExplorerPerformanceSetting writes nothing under -WhatIf" {
        Set-ExplorerPerformanceSetting -WhatIf
        Should -Invoke Set-RegistryValue -Times 0 -Exactly
    }

    It "Restore-DefaultExplorerSetting removes the suggestion overrides and resets MenuShowDelay" {
        Restore-DefaultExplorerSetting

        Should -Invoke Remove-RegistryValue -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'SilentInstalledAppsEnabled'
        }
        Should -Invoke Remove-RegistryValue -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'DisableWindowsSpotlightFeatures'
        }
        Should -Invoke Set-RegistryValue -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'MenuShowDelay' -and $Data -eq '400'
        }
    }

    It "Restore-DefaultExplorerSetting writes nothing under -WhatIf" {
        Restore-DefaultExplorerSetting -WhatIf
        Should -Invoke Set-RegistryValue -Times 0 -Exactly
        Should -Invoke Remove-RegistryValue -Times 0 -Exactly
    }
}

Describe "System Settings Manager - Security hardening" {
    It "Disables SMB1, LLMNR and WDigest" {
        Set-SecurityHardening

        Should -Invoke Set-RegistryValue -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'SMB1' -and $Data -eq '0'
        }
        Should -Invoke Set-RegistryValue -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'EnableMulticast' -and $Data -eq '0'
        }
        Should -Invoke Set-RegistryValue -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'UseLogonCredential' -and $Data -eq '0'
        }
    }

    It "Skips the opt-in extras (admin shares, SMB ciphers) by default" {
        Set-SecurityHardening

        Should -Invoke Set-RegistryValue -Times 0 -Exactly -ParameterFilter {
            $Name -in @('AutoShareServer', 'AutoShareWks', 'CipherSuiteOrder')
        }
    }

    It "Applies the opt-in extras with -IncludeOptInExtra" {
        Set-SecurityHardening -IncludeOptInExtra

        Should -Invoke Set-RegistryValue -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'AutoShareServer' -and $Data -eq '0'
        }
        Should -Invoke Set-RegistryValue -Times 2 -Exactly -ParameterFilter { $Name -eq 'CipherSuiteOrder' }
    }

    It "Writes nothing under -WhatIf" {
        Set-SecurityHardening -IncludeOptInExtra -WhatIf
        Should -Invoke Set-RegistryValue -Times 0 -Exactly
    }

    It "Restore-DefaultSecurityHardening only removes values and never sets them" {
        Restore-DefaultSecurityHardening

        Should -Invoke Remove-RegistryValue -Times 1 -Exactly -ParameterFilter { $Name -eq 'SMB1' }
        Should -Invoke Remove-RegistryValue -Times 1 -Exactly -ParameterFilter { $Name -eq 'UseLogonCredential' }
        Should -Invoke Remove-RegistryValue -Times 1 -Exactly -ParameterFilter { $Name -eq 'AutoShareWks' }
        Should -Invoke Set-RegistryValue -Times 0 -Exactly
    }

    It "Restore-DefaultSecurityHardening removes nothing under -WhatIf" {
        Restore-DefaultSecurityHardening -WhatIf
        Should -Invoke Remove-RegistryValue -Times 0 -Exactly
    }
}

Describe "System Settings Manager - System tweaks" {
    It "Applies the QoL tweaks" {
        Set-SystemTweak

        Should -Invoke Set-RegistryValue -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'NoDriveTypeAutoRun' -and $Data -eq '255'
        }
        Should -Invoke Set-RegistryValue -Times 1 -Exactly -ParameterFilter {
            $Name -eq 'RestartApps' -and $Data -eq '0'
        }
    }

    It "Enables sudo only on Windows 11 24H2 (build 26100) or later" {
        $osVersion = [Environment]::OSVersion.Version
        $expected = if ($osVersion.Major -eq 10 -and $osVersion.Build -ge 26100) { 1 } else { 0 }

        Set-SystemTweak

        Should -Invoke Set-RegistryValue -Times $expected -Exactly -ParameterFilter { $Path -like '*\Sudo' }
    }

    It "Set-SystemTweak writes nothing under -WhatIf" {
        Set-SystemTweak -WhatIf
        Should -Invoke Set-RegistryValue -Times 0 -Exactly
    }

    It "Restore-DefaultSystemTweak removes every tweak value and sets none" {
        Restore-DefaultSystemTweak

        Should -Invoke Remove-RegistryValue -Times 8 -Exactly
        Should -Invoke Set-RegistryValue -Times 0 -Exactly
    }

    It "Restore-DefaultSystemTweak removes nothing under -WhatIf" {
        Restore-DefaultSystemTweak -WhatIf
        Should -Invoke Remove-RegistryValue -Times 0 -Exactly
    }
}

Describe "System Settings Manager - GPU display (Set-P0State / Set-HDCP)" {
    BeforeEach {
        Mock Set-NvidiaGpuRegistryValue { return @("HKLM:\SOFTWARE\NVIDIA\TestPath1") }
        Mock Show-NvidiaGpuSetting {}
    }

    Context "Set-P0State" {
        It "Calls Set-NvidiaGpuRegistryValue with correct parameters" {
            Set-P0State -Value "1"

            Should -Invoke Set-NvidiaGpuRegistryValue -Times 1 -ParameterFilter {
                $Name -eq "DisableDynamicPstate" -and $Type -eq "REG_DWORD" -and $Data -eq "1"
            }
            Should -Invoke Show-NvidiaGpuSetting -Times 1
        }

        It "Does not write the GPU registry under -WhatIf" {
            Set-P0State -Value "1" -WhatIf
            Should -Invoke Set-NvidiaGpuRegistryValue -Times 0 -Exactly
        }
    }

    Context "Set-HDCP" {
        It "Calls Set-NvidiaGpuRegistryValue with correct parameters" {
            Set-HDCP -Value "0"

            Should -Invoke Set-NvidiaGpuRegistryValue -Times 1 -ParameterFilter {
                $Name -eq "RMHdcpKeyglobZero" -and $Type -eq "REG_DWORD" -and $Data -eq "0"
            }
            Should -Invoke Show-NvidiaGpuSetting -Times 1
        }

        It "Does not write the GPU registry under -WhatIf" {
            Set-HDCP -Value "0" -WhatIf
            Should -Invoke Set-NvidiaGpuRegistryValue -Times 0 -Exactly
        }
    }
}

Describe "System Settings Manager - menus" {
    It "Show-MainMenu offers nine entries ending in Exit" {
        Show-MainMenu
        Should -Invoke Show-Menu -Times 1 -Exactly -ParameterFilter {
            $Options.Count -eq 9 -and $Options[-1] -eq 'Exit'
        }
    }
}
