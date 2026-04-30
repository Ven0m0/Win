#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0

    # Load the script to test
    . "$PSScriptRoot/../Scripts/gpu-display-manager.ps1"
}

Describe "gpu-display-manager.ps1 functions" {
    Context "Set-P0State" {
        It "Calls Set-NvidiaGpuRegistryValue with correct parameters" {
            Mock Set-NvidiaGpuRegistryValue { return @("HKLM:\SOFTWARE\NVIDIA\TestPath1") }
            Mock Clear-Host {}
            Mock Write-Host {}
            Mock Show-NvidiaGpuSetting {}

            Set-P0State -Value "1"

            Assert-MockCalled Set-NvidiaGpuRegistryValue -Times 1 -ParameterFilter {
                $Name -eq "DisableDynamicPstate" -and $Type -eq "REG_DWORD" -and $Data -eq "1"
            }
            Assert-MockCalled Show-NvidiaGpuSettings -Times 1
        }
    }

    Context "Set-HDCP" {
        It "Calls Set-NvidiaGpuRegistryValue with correct parameters" {
            Mock Set-NvidiaGpuRegistryValue { return @("HKLM:\SOFTWARE\NVIDIA\TestPath1") }
            Mock Clear-Host {}
            Mock Write-Host {}
            Mock Show-NvidiaGpuSetting {}

            Set-HDCP -Value "0"

            Assert-MockCalled Set-NvidiaGpuRegistryValue -Times 1 -ParameterFilter {
                $Name -eq "RMHdcpKeyglobZero" -and $Type -eq "REG_DWORD" -and $Data -eq "0"
            }
            Assert-MockCalled Show-NvidiaGpuSettings -Times 1
        }
    }
}
