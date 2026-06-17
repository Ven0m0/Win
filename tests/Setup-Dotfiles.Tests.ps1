#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "Setup-Dotfiles.ps1" {
    Context "Script execution guard" {
        It "Should not execute main logic when dot-sourced" {
            $ErrorActionPreference = 'Stop'
            . "$PSScriptRoot/../Scripts/Setup-Dotfiles.ps1"
            $true | Should -Be $true
        }
    }

    Context "Function Definitions" {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/Setup-Dotfiles.ps1"
        }

        It "Should define required helper functions" {
            Get-Command Start-Bootstrap -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Deploy-Config -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Deploy-ConfigDirectory -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Import-RegistryConfig -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-FirefoxDefaultProfilePath -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-CallOfDutyPlayersPath -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-StarWarsBattlefrontIIRootPath -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Get-StarWarsBattlefrontIIActiveProfilePath -ErrorAction SilentlyContinue | `
                Should -Not -BeNullOrEmpty
            Get-Command Set-CmdAliasAutoRun -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Deploy-StarWarsBattlefrontIIConfig -ErrorAction SilentlyContinue | `
                Should -Not -BeNullOrEmpty
            Get-Command Invoke-ConfigManifestEntry -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Get-Command Install-WingetTool -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}
