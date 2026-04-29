#Requires -Version 5.1

BeforeAll {
    Import-Module Pester -MinimumVersion 5.0
}

Describe "allow-scripts.ps1" {
    BeforeAll {
        function Request-AdminElevation { }
        function Initialize-ConsoleUI { param([Parameter(ValueFromRemainingArguments)]$DummyArgs) }
        function Show-Menu { param([Parameter(ValueFromRemainingArguments)]$DummyArgs) }
        function Get-MenuChoice { param([Parameter(ValueFromRemainingArguments)]$DummyArgs) }
        function Wait-ForKeyPress { param([Parameter(ValueFromRemainingArguments)]$DummyArgs) }
    }

    BeforeEach {
        Mock -CommandName Set-RegistryValue -MockWith { }
        Mock -CommandName Remove-RegistryValue -MockWith { }
        Mock -CommandName Write-Host -MockWith { }
        Mock -CommandName Unblock-File -MockWith { }
    }

    Context "Script functions" {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/allow-scripts.ps1"
        }

        It "Should run Enable-ScriptExecution without errors and configure correctly" {
            { Enable-ScriptExecution } | Should -Not -Throw
            Assert-MockCalled -CommandName Set-RegistryValue -Times 3
            # We don't assert how many times Unblock-File is called since it depends on the directory's contents
        }

        It "Should run Disable-ScriptExecution without errors and configure correctly" {
            { Disable-ScriptExecution } | Should -Not -Throw
            Assert-MockCalled -CommandName Remove-RegistryValue -Times 2
            Assert-MockCalled -CommandName Set-RegistryValue -Times 2
        }
    }
}
