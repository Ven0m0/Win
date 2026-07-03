#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    # Stub Common.ps1 helpers before any dot-source to prevent real downloads/ops
    function Get-FileFromWeb { param([string]$URL, [string]$File) }
    function Wait-ForWinget { }
    function Invoke-CommandChecked { }
}

Describe "Optimize-Steam.ps1" {

    # -------------------------------------------------------------------------
    # Get-SteamPath — HKLM path present
    # -------------------------------------------------------------------------
    Context "Get-SteamPath — HKLM registry" {
        BeforeAll {
            Mock Write-Host { }
            Mock Write-Warning { }
            # Only Steam.exe exists; redist subdirs don't, so Get-ChildItem is never called
            Mock Test-Path { $Path -like '*Steam.exe' }
            Mock Get-ItemProperty {
                [PSCustomObject]@{ InstallPath = 'C:\FakeSteam' }
            } -ParameterFilter { $Path -like '*Wow6432Node*' }
            . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1" -WhatIf
        }

        It "Returns path from HKLM Wow6432Node when available" {
            Get-SteamPath | Should -Be 'C:\FakeSteam'
        }
    }

    # -------------------------------------------------------------------------
    # Get-SteamPath — HKLM absent, HKCU fallback
    # -------------------------------------------------------------------------
    Context "Get-SteamPath — HKCU fallback" {
        BeforeAll {
            Mock Write-Host { }
            Mock Write-Warning { }
            Mock Test-Path { $Path -like '*Steam.exe' }
            Mock Get-ItemProperty { $null } -ParameterFilter { $Path -like '*HKLM*' }
            Mock Get-ItemProperty {
                [PSCustomObject]@{ SteamPath = 'C:\HkcuSteam' }
            } -ParameterFilter { $Path -like '*HKCU*' }
            . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1" -WhatIf
        }

        It "Returns HKCU SteamPath when HKLM is absent" {
            Get-SteamPath | Should -Be 'C:\HkcuSteam'
        }
    }

    # -------------------------------------------------------------------------
    # Get-SteamPath — both registry keys missing, ProgramFiles fallback
    # -------------------------------------------------------------------------
    Context "Get-SteamPath — ProgramFiles fallback" {
        BeforeAll {
            Mock Write-Host { }
            Mock Write-Warning { }
            Mock Test-Path { $Path -like '*Steam.exe' }
            Mock Get-ItemProperty { $null }
            . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1" -WhatIf
        }

        It "Falls back to ProgramFiles Steam when both registry keys are missing" {
            Get-SteamPath | Should -BeLike '*Steam*'
        }
    }

    # -------------------------------------------------------------------------
    # Get-SteamPath — explicit -SteamPath override
    # -------------------------------------------------------------------------
    Context "Get-SteamPath — explicit override" {
        BeforeAll {
            Mock Write-Host { }
            Mock Write-Warning { }
            Mock Test-Path { $Path -like '*Steam.exe' }
            Mock Get-ItemProperty { $null }
            . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1" -SteamPath 'C:\CustomSteam' -WhatIf
        }

        It "Returns the override path directly without registry lookup" {
            Get-SteamPath -Override 'C:\CustomSteam' | Should -Be 'C:\CustomSteam'
        }
    }

    # -------------------------------------------------------------------------
    # Invoke-CleanRedist
    # -------------------------------------------------------------------------
    Context "Invoke-CleanRedist — WhatIf suppresses deletions" {
        BeforeAll {
            Mock Write-Host { }
            Mock Write-Warning { }
            Mock Test-Path { $Path -like '*Steam.exe' }
            Mock Remove-Item { }
            Mock Get-ItemProperty {
                [PSCustomObject]@{ InstallPath = 'C:\FakeSteam' }
            } -ParameterFilter { $Path -like '*Wow6432Node*' }
            . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1" -WhatIf
            # Mock after dot-source: Write-ColorOutput comes from Common.ps1 and
            # must exist to be mockable; Write-Host mocks don't catch it
            Mock Write-ColorOutput { }
        }

        It "Does not call Remove-Item when WhatIfPreference is set" {
            Invoke-CleanRedist -SteamPath 'C:\FakeSteam' -WhatIf
            Should -Not -Invoke Remove-Item
        }

        It "Reports no files to clean when redist dirs are absent" {
            # Test-Path returns false for redist paths (only Steam.exe returns true)
            Invoke-CleanRedist -SteamPath 'C:\FakeSteam' -WhatIf
            Should -Invoke Write-ColorOutput -ParameterFilter { $Object -match 'No installer files' } -Scope It
        }
    }

    # -------------------------------------------------------------------------
    # Invoke-RestoreNoSteamWebHelper
    # -------------------------------------------------------------------------
    Context "Invoke-RestoreNoSteamWebHelper — no backup, DLL absent" {
        BeforeAll {
            Mock Write-Host { }
            Mock Write-Warning { }
            Mock Test-Path { $false }
            Mock Get-ItemProperty {
                [PSCustomObject]@{ InstallPath = 'C:\FakeSteam' }
            } -ParameterFilter { $Path -like '*Wow6432Node*' }
            # Steam.exe check must pass to get past the top-level guard on dot-source
            Mock Test-Path { $Path -like '*Steam.exe' }
            . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1" -WhatIf
            Mock Write-ColorOutput { }
        }

        It "Reports DLL not found when neither backup nor DLL exists" {
            Mock Test-Path { $false }
            Invoke-RestoreNoSteamWebHelper -SteamPath 'C:\FakeSteam'
            Should -Invoke Write-ColorOutput -ParameterFilter { $Object -match 'not found' } -Scope It
        }
    }

    Context "Invoke-RestoreNoSteamWebHelper — backup present, WhatIf" {
        BeforeAll {
            Mock Write-Host { }
            Mock Write-Warning { }
            Mock Test-Path { $Path -like '*Steam.exe' }
            Mock Copy-Item { }
            Mock Remove-Item { }
            Mock Get-ItemProperty {
                [PSCustomObject]@{ InstallPath = 'C:\FakeSteam' }
            } -ParameterFilter { $Path -like '*Wow6432Node*' }
            . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1" -WhatIf
        }

        It "Does not throw when backup exists and WhatIf is set" {
            Mock Test-Path { $true }
            { Invoke-RestoreNoSteamWebHelper -SteamPath 'C:\FakeSteam' -WhatIf } | Should -Not -Throw
        }
    }
}
