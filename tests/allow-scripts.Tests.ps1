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
        function Get-ChildItem { param([Parameter(ValueFromRemainingArguments)]$DummyArgs) }
    }

    BeforeEach {
        Mock -CommandName Set-RegistryValue -MockWith { }
        Mock -CommandName Remove-RegistryValue -MockWith { }
        Mock -CommandName Write-Host -MockWith { }
        Mock -CommandName Unblock-File -MockWith { }
        Mock -CommandName Get-ChildItem -MockWith { }
    }

    Context "Enable-ScriptExecution" {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/allow-scripts.ps1"
        }

        It "Should call Set-RegistryValue for HKCR and both HKCU/HKLM execution policies" {
            Enable-ScriptExecution
            Assert-MockCalled -CommandName Set-RegistryValue -Times 3
        }

        It "Should call Unblock-File for each script in the directory" {
            Enable-ScriptExecution
            Assert-MockCalled -CommandName Unblock-File -Times 1
        }

        It "Should write enabling status messages" {
            Enable-ScriptExecution
            Assert-MockCalled -CommandName Write-Host -Times 6
        }

        It "Should not call Remove-RegistryValue when enabling" {
            Enable-ScriptExecution
            Assert-MockCalled -CommandName Remove-RegistryValue -Times 0
        }
    }

    Context "Disable-ScriptExecution" {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/allow-scripts.ps1"
        }

        It "Should call Remove-RegistryValue for HKCR ps1 associations" {
            Disable-ScriptExecution
            Assert-MockCalled -CommandName Remove-RegistryValue -Times 2
        }

        It "Should call Set-RegistryValue for HKCU/HKLM to Restricted" {
            Disable-ScriptExecution
            Assert-MockCalled -CommandName Set-RegistryValue -Times 2
        }

        It "Should not call Unblock-File when disabling" {
            Disable-ScriptExecution
            Assert-MockCalled -CommandName Unblock-File -Times 0
        }

        It "Should write disabling status messages" {
            Disable-ScriptExecution
            Assert-MockCalled -CommandName Write-Host -Times 5
        }
    }

    Context "Policy detection" {
        BeforeAll {
            . "$PSScriptRoot/../Scripts/allow-scripts.ps1"
        }

        It "Should enable scripts sets RemoteSigned in HKCU registry" {
            Enable-ScriptExecution
            Should -Invoke Set-RegistryValue -ParameterFilter {
                $Path -like '*HKCU*' -and $Name -eq 'ExecutionPolicy' -and $Data -eq 'RemoteSigned'
            }
        }

        It "Should disable scripts sets Restricted in HKCU registry" {
            Disable-ScriptExecution
            Should -Invoke Set-RegistryValue -ParameterFilter {
                $Path -like '*HKCU*' -and $Name -eq 'ExecutionPolicy' -and $Data -eq 'Restricted'
            }
        }
    }
}