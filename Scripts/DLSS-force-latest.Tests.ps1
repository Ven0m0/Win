#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0

    # Load the script to test.
    . "$PSScriptRoot/DLSS-force-latest.ps1"
}

Describe "DLSS-force-latest.ps1 functions" {
    Context "New-DLSSInspectorConfig" {
        It "Generates XML configuration with DLSS override enabled" {
            $config = New-DLSSInspectorConfig -EnableDLSSOverride $true
            $config | Should -Match "<SettingValue>1</SettingValue>"
            $config | Should -Match "283962569" # SettingID for CUDA Sysmem Fallback Policy or DLSS Force
        }

        It "Generates XML configuration with DLSS override disabled" {
            $config = New-DLSSInspectorConfig -EnableDLSSOverride $false
            # It should have SettingValue 0 or just match the false logic.
            # In the file, logic says:
            # $dlssOverrideSettings = if ($EnableDLSSOverride) { ... }
            $config | Should -Match "<SettingValue>0</SettingValue>"
        }
    }

    Context "Start-DLSSForceLatestMenu" {
        It "Initializes UI and downloads Inspector.exe if it doesn't exist" {
            Mock Request-AdminElevation {}
            Mock Initialize-ConsoleUI {}
            Mock Test-Path { return $false }
            Mock Get-ChildItem { return @() }
            Mock Unblock-File {}
            Mock Get-FileFromWeb {}
            Mock Set-RegistryValue {}
            Mock Clear-Host {}

            Mock Get-MenuChoice { throw "STOP_LOOP" }
            Mock Show-Menu {}
            Mock Write-Host {}

            try { Start-DLSSForceLatestMenu } catch { if ($_.Exception.Message -ne "STOP_LOOP") { throw $_ } }

            Should -Invoke -CommandName Request-AdminElevation -Times 1
            Should -Invoke -CommandName Initialize-ConsoleUI -Times 1
            Should -Invoke -CommandName Get-FileFromWeb -Times 1 -ParameterFilter {
                $URL -eq "https://github.com/FR33THYFR33THY/files/raw/main/Inspector.exe"
            }
            Should -Invoke -CommandName Set-RegistryValue -Times 3
        }

        It "Initializes UI and skips downloading Inspector.exe if it exists" {
            Mock Request-AdminElevation {}
            Mock Initialize-ConsoleUI {}
            Mock Test-Path { return $true }
            Mock Get-FileFromWeb {}
            Mock Set-RegistryValue {}
            Mock Clear-Host {}
            Mock Write-Host {}
            Mock Get-MenuChoice { throw "STOP_LOOP" }
            Mock Show-Menu {}

            try { Start-DLSSForceLatestMenu } catch { if ($_.Exception.Message -ne "STOP_LOOP") { throw $_ } }

            Should -Invoke -CommandName Get-FileFromWeb -Times 0
            Should -Invoke -CommandName Set-RegistryValue -Times 0
        }

        It "Executes choice 1 (DLSS Force Latest: On)" {
            Mock Request-AdminElevation {}
            Mock Initialize-ConsoleUI {}
            Mock Test-Path { return $true }
            Mock Clear-Host {}
            Mock Write-Host {}
            Mock Set-ItemProperty {}
            Mock New-DLSSInspectorConfig { return "MOCKED_CONFIG" }
            Mock Set-Content {}
            Mock Start-Process {}

            # First return 1, then throw to exit loop
            $script:loopCount = 0
            Mock Get-MenuChoice {
                if ($script:loopCount -eq 0) {
                    $script:loopCount++
                    return 1
                }
                throw "STOP_LOOP"
            }
            Mock Show-Menu {}

            try { Start-DLSSForceLatestMenu } catch { if ($_.Exception.Message -ne "STOP_LOOP") { throw $_ } }

            Should -Invoke -CommandName Set-ItemProperty -Times 2
            Should -Invoke -CommandName New-DLSSInspectorConfig -Times 1 -ParameterFilter {
                $EnableDLSSOverride -eq $true
            }
            Should -Invoke -CommandName Set-Content -Times 1
            Should -Invoke -CommandName Start-Process -Times 1
        }

        It "Executes choice 3 (DLSS Overlay: On)" {
            Mock Request-AdminElevation {}
            Mock Initialize-ConsoleUI {}
            Mock Test-Path { return $true }
            Mock Clear-Host {}
            Mock Write-Host {}
            Mock Write-Info {}
            Mock Set-RegistryValue {}
            Mock Wait-ForKeyPress {}

            $script:loopCount = 0
            Mock Get-MenuChoice {
                if ($script:loopCount -eq 0) {
                    $script:loopCount++
                    return 3
                }
                throw "STOP_LOOP"
            }
            Mock Show-Menu {}

            try { Start-DLSSForceLatestMenu } catch { if ($_.Exception.Message -ne "STOP_LOOP") { throw $_ } }

            Should -Invoke -CommandName Set-RegistryValue -Times 1 -ParameterFilter {
                $Name -eq "ShowDlssIndicator" -and $Type -eq "REG_DWORD" -and $Data -eq 1
            }
            Should -Invoke -CommandName Wait-ForKeyPress -Times 1
        }
    }
}
