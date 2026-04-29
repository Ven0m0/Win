#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0

    # We must define dummy functions to prevent CommandNotFoundException when mocking
    function Request-AdminElevation {}
    function Initialize-ConsoleUI {}
}

Describe "DLSS-force-latest.ps1" {
    Context "Script execution guard" {
        It "Should not execute main logic when dot-sourced" {
            # Mock functions to prevent any side effects in case of failure
            Mock Request-AdminElevation {}
            Mock Initialize-ConsoleUI {}

            # Dot-source the script
            . "$PSScriptRoot/DLSS-force-latest.ps1"

            # Check that the function was defined but Request-AdminElevation wasn't called
            Get-Command Start-DLSSForceLatest -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
            Assert-MockCalled Request-AdminElevation -Times 0 -Exactly
        }
    }

    Context "Function Definitions" {
        BeforeAll {
            # Mock the functions used inside the script so it doesn't fail if we dot source it
            Mock Request-AdminElevation {}
            Mock Initialize-ConsoleUI {}

            . "$PSScriptRoot/DLSS-force-latest.ps1"
        }

        It "Should define required functions" {
            Get-Command Start-DLSSForceLatest -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}
