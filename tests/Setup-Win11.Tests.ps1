#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
    . "$PSScriptRoot/../Scripts/Setup-Win11.ps1"
}

Describe "Start-SetupWin11" {
    Context "When prerequisite is missing" {
        It "Should fail when winget is not found and shell-setup.ps1 is missing" {
            # Mock Get-Command to say winget doesn't exist
            Mock Get-Command { return $null } -ParameterFilter { $Name -eq 'winget' }
            Mock Test-Path { return $false } -ParameterFilter { $Path -match 'shell-setup.ps1' }
            Mock Write-Host {}
            Mock Start-Process {}

            # The script defines Write-Fail at the very bottom of the function. We need to mock it if it's called before defined.
            # But the function defines it at the bottom. PowerShell hoists function definitions slightly differently but inside a script block it might execute sequentially.
            # We can mock it.
            function Write-Fail { param($msg) }

            $result = Start-SetupWin11
            $result | Should -Be $false
        }
    }

    Context "When prerequisites are present" {
        It "Should succeed" {
            Mock Get-Command { return [pscustomobject]@{ Name = $Name; Source = "$Name.exe" } } `
                -ParameterFilter { $Name -in @('winget', 'git', 'pwsh', 'mise', 'wsl') }
            Mock Get-Command { return [pscustomobject]@{ Name = 'cmd'; Source = 'cmd.exe' } }

            Mock Test-Path { return $true }
            Mock Remove-Item {}
            Mock Write-Host {}
            Mock Start-Process {}
            Mock Push-Location {}
            Mock Pop-Location {}

            function wsl {}
            function git {}
            function winget {}
            function mise { $global:LASTEXITCODE = 0 }

            # -SkipDebloat/-SkipPackages are required here: Test-Path being mocked $true does NOT
            # intercept `& $debloatScript`/`& $installScript` (those invoke real files by path), so
            # without these switches this test would actually run the live debloat/package scripts.
            $result = Start-SetupWin11 -Unattended -SkipWSL -SkipDebloat -SkipPackages
            $result | Should -Be $true
        }
    }
}
