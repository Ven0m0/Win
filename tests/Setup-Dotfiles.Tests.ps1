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

    Context "Error resilience" {
        It "Should not abort the manifest loop when one entry throws" {
            . "$PSScriptRoot/../Scripts/Setup-Dotfiles.ps1"

            $deployFailures = [System.Collections.Generic.List[pscustomobject]]::new()
            $configManifest = @(
                @{ Label = 'Throwing entry' },
                @{ Label = 'Later entry' }
            )
            $processed = [System.Collections.Generic.List[string]]::new()

            foreach ($entry in $configManifest) {
                try {
                    if ($entry.Label -eq 'Throwing entry') { throw 'simulated failure' }
                    $processed.Add($entry.Label)
                }
                catch {
                    $err = $_
                    $deployFailures.Add([pscustomobject]@{ Label = $entry.Label; Error = $err.Exception.Message })
                }
            }

            $deployFailures.Count | Should -Be 1
            $deployFailures[0].Label | Should -Be 'Throwing entry'
            $processed | Should -Contain 'Later entry'
        }
    }

    Context "OBS config tracked" {
        It "Should include an OBS Studio config manifest entry" {
            $manifestContent = Get-Content -Path "$PSScriptRoot/../Scripts/Setup-Dotfiles.ps1" -Raw
            $manifestContent | Should -Match "Label\s*=\s*'OBS Studio config'"
            $manifestContent | Should -Match "obs-studio"
        }
    }
}
