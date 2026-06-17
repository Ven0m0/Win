#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    Mock Write-Host { }
    Mock Write-Warning { }
    Mock Test-Path { $true }
    # Load merged script once; main block is gated on InvocationName
    . "$PSScriptRoot/../Scripts/Optimize-Steam.ps1"
}

Describe "Optimize-Steam.ps1 — Get-SteamPath" {
    Context "Get-SteamPath — HKLM registry" {
        BeforeAll {
            Mock Get-ItemProperty {
                [PSCustomObject]@{ InstallPath = 'C:\FakeSteam' }
            } -ParameterFilter { $Path -like '*Wow6432Node*' }
        }

        It "Returns path from HKLM Wow6432Node when available" {
            Get-SteamPath | Should -Be 'C:\FakeSteam'
        }
    }

    Context "Get-SteamPath — HKCU fallback" {
        BeforeAll {
            Mock Get-ItemProperty { $null } -ParameterFilter { $Path -like '*HKLM*' }
            Mock Get-ItemProperty {
                [PSCustomObject]@{ SteamPath = 'C:\UserSteam' }
            } -ParameterFilter { $Path -like '*HKCU*' }
        }

        It "Returns HKCU SteamPath when HKLM is absent" {
            Get-SteamPath | Should -Be 'C:\UserSteam'
        }
    }

    Context "Get-SteamPath — ProgramFiles default" {
        BeforeAll {
            Mock Get-ItemProperty { throw 'no registry entry' }
        }

        It "Falls back to ProgramFiles Steam when registry throws" {
            Get-SteamPath | Should -BeLike '*Steam*'
        }
    }

    Context "Get-SteamPath — explicit -Override param" {
        It "Returns the override path directly without registry lookup" {
            Get-SteamPath -Override 'D:\Override' | Should -Be 'D:\Override'
        }
    }
}

Describe "Optimize-Steam.ps1 — Invoke-CreateShortcut" {
    Context "DryRun suppresses COM shortcut creation" {
        It "Does not instantiate WScript.Shell when -DryRun is set" {
            Mock New-Object { } -ParameterFilter { $ComObject -eq 'WScript.Shell' }
            Invoke-CreateShortcut -SteamPath 'C:\FakeSteam' -DryRun
            Should -Not -Invoke New-Object -ParameterFilter { $ComObject -eq 'WScript.Shell' }
        }

        It "Writes at least one status message in DryRun mode" {
            Mock Write-ColorOutput { }
            Invoke-CreateShortcut -SteamPath 'C:\FakeSteam' -DryRun
            Should -Invoke Write-ColorOutput -Times 1 -Exactly:$false
        }
    }
}
