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
                -ParameterFilter { $Name -in @('winget', 'git', 'pwsh', 'python', 'dotbot', 'pip', 'wsl') }
            Mock Get-Command { return [pscustomobject]@{ Name = 'cmd'; Source = 'cmd.exe' } }

            Mock Test-Path { return $true }
            Mock Remove-Item {}
            Mock Write-Host {}
            Mock Start-Process {}
            Mock Start-Process {}

            function wsl {}
            function git {}
            function dotbot {}
            function pushd {}
            function popd {}
            function winget {}

            # The script does `pushd $repoDir`. Because we mocked `pushd` and `popd`, the real pushd is NOT running.
            # Wait, the script says `ItemNotFoundException`. It might not be using our mocked `pushd`.
            # Pester 5 Mocks are scoped. But we define `function pushd {}`. Let's use `Mock pushd {}`.
            Mock pushd {}
            Mock popd {}

            $result = Start-SetupWin11 -Unattended -SkipWSL
            $result | Should -Be $true
        }
    }
}
